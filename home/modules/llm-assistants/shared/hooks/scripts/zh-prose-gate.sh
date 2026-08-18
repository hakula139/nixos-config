#!/usr/bin/env bash

# ==============================================================================
# Chinese Prose Gate (PostToolUse)
# ==============================================================================
# Measures the Chinese prose the assistant just wrote against this assistant's
# own unpolished-output fingerprint, then hands the numbers to a headless
# `claude -p` judge. Emits additionalContext (non-halting). Fails open on any
# error, and stays inert when no classifier was fitted for this assistant.
# ==============================================================================

# `-e` is omitted: the checks below intentionally fall through to `exit 0`.
set -uo pipefail

# The judge subprocess would otherwise re-trigger this hook.
if [[ -n "${CLAUDE_ZH_PROSE_GATE_ACTIVE:-}" ]]; then
  exit 0
fi

FINGERPRINT="@fingerprint@"
PROMPT_FILE="@promptFile@"
MODEL_ID="@modelId@"
[[ -x "$FINGERPRINT" && -r "$PROMPT_FILE" ]] || exit 0

INPUT=$(cat)
TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty')

case "$TOOL_NAME" in
  Write) CONTENT=$(printf '%s' "$INPUT" | jq -r '.tool_input.content // empty') ;;
  Edit) CONTENT=$(printf '%s' "$INPUT" | jq -r '.tool_input.new_string // empty') ;;
  # Added lines only: context lines are text the assistant did not write.
  apply_patch) CONTENT=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' \
    | sed -n -E 's/^\+(.*)$/\1/p') ;;
  mcp__*) CONTENT=$(printf '%s' "$INPUT" \
    | jq -r '.tool_input.message // .tool_input.description // .tool_input.body // .tool_input.note // .tool_input.content // empty') ;;
  *) exit 0 ;;
esac

# The classifier reports its own short-text and low-Chinese rejections through a
# non-zero exit, since both leave the ratios unstable rather than merely noisy.
REPORT=$(printf '%s' "$CONTENT" | "$FINGERPRINT" "$MODEL_ID" 2>/dev/null) || exit 0
[[ -n "$REPORT" ]] || exit 0

# Held-out rates at this threshold: 89% recall against 15% false positives for
# claude-code, 92% against 9% for codex. The judge then rules on whatever gets
# through, so the cheap check only has to skip what is clearly clean.
SCORE=$(printf '%s' "$REPORT" | jq -r '.score // 0')
awk -v score="$SCORE" 'BEGIN { exit !(score > -0.4) }' || exit 0

# The prompt is English apart from the symptom names and examples: an all-Chinese
# system prompt doubles as the judge's model of normal Chinese, and scored 0.37
# colons-and-semicolons per clause in its own prescriptions against 0.13 here.
RAW=$(cd /tmp && CLAUDE_ZH_PROSE_GATE_ACTIVE=1 timeout "@judgeTimeout@" claude -p "指标：$REPORT

文本：
$CONTENT" \
  --bare \
  --system-prompt-file "$PROMPT_FILE" \
  --model sonnet \
  --output-format json \
  2>/dev/null)

# The verdict JSON is under .result, sometimes wrapped in a code fence or
# backticks. Extract the outermost {...} to strip any such wrapper.
VERDICT=$(printf '%s' "$RAW" | jq -r '.result // empty' 2>/dev/null \
  | tr -d '\n' | grep -oE '\{.*\}')
[[ "$(printf '%s' "$VERDICT" | jq -r '.ai' 2>/dev/null)" == "true" ]] || exit 0

TICS=$(printf '%s' "$VERDICT" | jq -r '.tics // [] | join("、")' 2>/dev/null)
FIX=$(printf '%s' "$VERDICT" | jq -r '.fix // empty' 2>/dev/null)

# The length constraint rides along because a judge asking for an expanded
# derivation otherwise gets one padded with restatement of the same point.
jq -n --arg tics "$TICS" --arg fix "$FIX" '{
  hookSpecificOutput: {
    hookEventName: "PostToolUse",
    additionalContext: ("中文 AI 味检测命中。病症：" + $tics + "。改法：" + $fix
      + " 请就地改掉，然后继续。字数不要显著增加，也不要新增论点。")
  }
}'
