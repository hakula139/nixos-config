#!/usr/bin/env python3
"""Chinese Polish (PreToolUse).

Hands the Chinese in a tool's input to a better Chinese writer and substitutes the
rewrite back before the tool runs. The event is what makes the coverage work: by
PostToolUse a Confluence page, a commit body or a question has already gone out,
and a rewriter can only help while the text is still in hand.

Python because a PreToolUse error can deny the tool call, so failing open has to be
airtight, and one try block around a recursive walk of arbitrary JSON is easier to
keep that way than nushell's split between an error and a null.

Fails open on every error, per this repo's hook contract.
"""

import json
import os
import re
import ssl
import sys
import urllib.request
from pathlib import Path


PROMPT_FILE = '@promptFile@'
DOCTRINE_FILE = '@doctrineFile@'
MODEL = '@model@'
POLISH_TIMEOUT = int('@polishTimeout@')

CJK = re.compile(r'[\u4e00-\u9fff]')
FENCE = re.compile(r'```.*?```', re.S)
CALL_ERRORS = (OSError, ValueError, KeyError, IndexError, TypeError)

# A whole-file Write is only worth a call once the file is substantially Chinese,
# where an Edit carries just the span that changed, so one sentence is enough. A
# model typically rewrites a sentence at a time, which the file floor would skip.
MIN_CJK_FILE = 120
MIN_CJK_SPAN = 8
MIN_RATIO, MAX_RATIO = 0.55, 1.6

# Only Markdown is eligible: rewriting a source file to polish one Chinese comment
# risks the code around it.
FILE_FIELDS = {'Write': ('content', MIN_CJK_FILE), 'Edit': ('new_string', MIN_CJK_SPAN)}
MCP_FIELDS = ('content', 'body', 'message', 'description', 'note', 'new_content')


def structure(text: str) -> tuple:
    """The parts a rewrite must leave alone, compared before the input is updated."""
    return (
        FENCE.findall(text),
        re.findall(r'`[^`\n]+`', text),
        re.findall(r'^#{1,6} .*$', text, re.M),
        re.findall(r'\]\(([^)]+)\)', text),
    )


def prose_cjk(text: str) -> int:
    return len(CJK.findall(FENCE.sub('', text)))


def collect(node, floor: int, path=()):
    """Every string under `node` carrying at least `floor` Chinese characters."""
    if isinstance(node, str):
        return [(path, node)] if prose_cjk(node) >= floor else []
    if isinstance(node, dict):
        return [p for k, v in node.items() for p in collect(v, floor, (*path, k))]
    if isinstance(node, list):
        return [p for i, v in enumerate(node) for p in collect(v, floor, (*path, i))]
    return []


def put(node, path, value):
    for key in path[:-1]:
        node = node[key]
    node[path[-1]] = value


def targets(payload: dict) -> list:
    """The (path, text) pairs this tool exposes, or an empty list to stay out."""
    tool = payload.get('tool_name') or ''
    args = payload.get('tool_input')
    if not isinstance(args, dict):
        return []

    if tool in FILE_FIELDS:
        if not (args.get('file_path') or '').endswith('.md'):
            return []
        key, floor = FILE_FIELDS[tool]
        text = args.get(key)
        if isinstance(text, str) and prose_cjk(text) >= floor:
            return [((key,), text)]
        return []

    # An interactive question is short by nature and nested several levels deep.
    if tool == 'AskUserQuestion':
        return collect(args.get('questions'), MIN_CJK_SPAN, ('questions',))

    if tool.startswith('mcp__'):
        return [
            ((k,), args[k])
            for k in MCP_FIELDS
            if isinstance(args.get(k), str) and prose_cjk(args[k]) >= MIN_CJK_SPAN
        ]
    return []


def polish(items: list[str]) -> list[str]:
    base = (os.environ.get('ANTHROPIC_BASE_URL') or '').removesuffix('/anthropic')
    token = os.environ.get('ANTHROPIC_AUTH_TOKEN') or ''
    if not base or not token:
        return []
    # Everything above the horizontal rule is a note to whoever edits that file.
    instruction = Path(PROMPT_FILE).read_text().split('\n---\n', 1)[-1].strip()
    numbered = '\n\n'.join(f'<<<{i}>>>\n{t}' for i, t in enumerate(items))
    body = {
        'model': MODEL,
        'max_tokens': 16384,
        'stream': False,
        'messages': [
            {'role': 'system', 'content': Path(DOCTRINE_FILE).read_text()},
            {
                'role': 'user',
                'content': (
                    f'{instruction}\n\n'
                    f'There are {len(items)} passages below, each introduced by a '
                    '<<<n>>> line. Rewrite them one by one, keeping the same '
                    'numbering and order, and keep the <<<n>>> line in front of '
                    'each. Do not merge, split, add, or drop a passage.\n\n'
                    f'{numbered}'
                ),
            },
        ],
    }
    ca = os.environ.get('NODE_EXTRA_CA_CERTS')
    ctx = ssl.create_default_context(cafile=ca) if ca else ssl.create_default_context()
    req = urllib.request.Request(
        f'{base}/v1/chat/completions',
        data=json.dumps(body).encode(),
        headers={
            'Authorization': f'Bearer {token}',
            'content-type': 'application/json',
        },
    )
    with urllib.request.urlopen(req, context=ctx, timeout=POLISH_TIMEOUT) as resp:
        reply = json.load(resp)['choices'][0]['message']['content'] or ''

    parts = dict(re.findall(r'<<<(\d+)>>>\n(.*?)(?=\n*<<<\d+>>>|\Z)', reply, re.S))
    out = [parts.get(str(i), '').strip() for i in range(len(items))]
    # A dropped or merged segment means the numbering was not honoured, and a
    # partial application would silently lose text.
    return out if all(out) else []


def acceptable(before: str, after: str) -> bool:
    ratio = prose_cjk(after) / max(prose_cjk(before), 1)
    return (
        bool(after)
        and MIN_RATIO <= ratio <= MAX_RATIO
        and structure(after) == structure(before)
    )


def main() -> int:
    try:
        payload = json.loads(sys.stdin.read())
    except ValueError:
        return 0

    found = targets(payload)
    if not found:
        return 0

    try:
        rewritten = polish([text for _, text in found])
    except CALL_ERRORS:
        return 0
    if len(rewritten) != len(found):
        return 0

    args = payload['tool_input']
    changed = set()
    for (path, before), after in zip(found, rewritten):
        if acceptable(before, after):
            put(args, path, after)
            changed.add(path[0])
    if not changed:
        return 0

    # Only the keys touched go back: updatedInput merges into the real input, so a
    # key omitted here keeps whatever the caller passed.
    print(
        json.dumps(
            {
                'hookSpecificOutput': {
                    'hookEventName': 'PreToolUse',
                    'updatedInput': {k: args[k] for k in changed},
                }
            }
        )
    )
    return 0


if __name__ == '__main__':
    # A PreToolUse hook that exits non-zero can deny the tool call, so every
    # exception has to be swallowed here, however malformed the payload was.
    try:
        sys.exit(main())
    except Exception:
        sys.exit(0)
