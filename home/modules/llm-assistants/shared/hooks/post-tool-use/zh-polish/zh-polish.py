#!/usr/bin/env python3
"""Chinese Polish (PostToolUse).

Replaces the Chinese the assistant just wrote with a rewrite from the model that
scored highest on this reviewer's own annotations. Rewrites only the span the tool
call introduced, so prose already in the file is never touched.

The call goes straight to the configured endpoint rather than through `claude -p`,
because the CLI only routes Anthropic models and the whole Anthropic field scored
4.0 to 4.5 on this task against 9.0 for the model pinned below. Reaching it is the
entire point of the hook.

Fails open on every error, per this repo's hook contract: a broken polisher reads
as a hook that quietly stopped firing rather than one that corrupts a document.
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

CJK = re.compile(r'[一-鿿]')
FENCE = re.compile(r'```.*?```', re.S)
# Below this the span is a stray phrase or a code comment, and a model call buys
# nothing. Drafts in the study ran 500 to 700 CJK characters.
MIN_CJK = 120
# A rewrite is licensed to cut information, so it may legitimately shrink. These
# bounds only catch a truncated or runaway reply.
MIN_RATIO, MAX_RATIO = 0.55, 1.6
# Bound to a name because a formatter on this path strips the parentheses off an
# inline `except (A, B)`, which is a syntax error rather than a style change.
CALL_ERRORS = (OSError, ValueError, KeyError, IndexError)


def written_span(payload: dict) -> str:
    tool = payload.get('tool_name') or ''
    args = payload.get('tool_input')
    if not isinstance(args, dict):
        return ''
    if tool == 'Write':
        return args.get('content') or ''
    if tool == 'Edit':
        return args.get('new_string') or ''
    return ''


def prose_cjk(text: str) -> int:
    """CJK outside fenced code, since a fenced block is not prose to rewrite."""
    return len(CJK.findall(FENCE.sub('', text)))


def structure(text: str) -> tuple:
    """The parts a rewrite must leave alone, compared before writing back."""
    return (
        FENCE.findall(text),
        re.findall(r'`[^`\n]+`', text),
        re.findall(r'^#{1,6} .*$', text, re.M),
        re.findall(r'\]\(([^)]+)\)', text),
    )


def polish(draft: str) -> str:
    base = (os.environ.get('ANTHROPIC_BASE_URL') or '').removesuffix('/anthropic')
    token = os.environ.get('ANTHROPIC_AUTH_TOKEN') or ''
    if not base or not token:
        return ''
    # Everything above the horizontal rule is a note to whoever edits that file.
    instruction = Path(PROMPT_FILE).read_text().split('\n---\n', 1)[-1].strip()
    body = {
        'model': MODEL,
        'max_tokens': 16384,
        'stream': False,
        'messages': [
            {'role': 'system', 'content': Path(DOCTRINE_FILE).read_text()},
            {'role': 'user', 'content': f'{instruction}\n\n{draft}'},
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
        payload = json.load(resp)
    return (payload['choices'][0]['message']['content'] or '').strip()


def main() -> int:
    try:
        payload = json.loads(sys.stdin.read())
    except ValueError:
        return 0

    path_raw = (payload.get('tool_input') or {}).get('file_path') or ''
    if not path_raw.endswith('.md'):
        return 0

    span = written_span(payload)
    if prose_cjk(span) < MIN_CJK:
        return 0

    path = Path(path_raw)
    try:
        current = path.read_text()
    except OSError:
        return 0
    # An Edit whose new_string was reformatted on write, or a span appearing
    # twice, cannot be replaced unambiguously.
    if current.count(span) != 1:
        return 0

    try:
        rewritten = polish(span)
    except CALL_ERRORS:
        return 0

    ratio = prose_cjk(rewritten) / max(prose_cjk(span), 1)
    if not rewritten or not MIN_RATIO <= ratio <= MAX_RATIO:
        return 0
    if structure(rewritten) != structure(span):
        return 0

    try:
        path.write_text(current.replace(span, rewritten, 1))
    except OSError:
        return 0

    print(f'zh-polish: rewrote {prose_cjk(span)} CJK chars in {path.name} via {MODEL}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
