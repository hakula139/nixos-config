import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


HOOKS = Path(__file__).resolve().parents[1]


class HooksTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.nu = shutil.which('nu')
        self.parser = self.root / 'patch-input'
        self.parser.write_text(
            f'#!{self.nu}\n' + (HOOKS / 'lib/patch-input/patch-input.nu').read_text()
        )
        self.parser.chmod(0o755)
        self.model = self.root / 'model'
        self.model.write_text(
            f'#!{sys.executable}\n'
            'import json, sys\n'
            'request = json.load(sys.stdin)\n'
            'if request.get("json"):\n'
            '    passages = json.loads(request["user"].split("\\n")[-1])["passages"]\n'
            '    for p in passages:\n'
            '        p["text"] = p["text"].replace("very useful", "helpful")\n'
            '    print(json.dumps({"passages": passages}))\n'
            'else:\n'
            '    print("Quoted finding: " + request["user"] + "\\nok: false")\n'
        )
        self.model.chmod(0o755)
        self.config = {
            'patchInput': str(self.parser),
            'modelCall': str(self.model),
            'model': 'test',
            'maxRepairs': 0,
            'phrasing': '',
            'prompt': '',
            'repairPrompt': '',
            'mcpProseFields': {'mcp__GitHub__create_pull_request': ['body', 'title']},
        }

    def run_hook(self, script, payload, config=None):
        config_path = self.root / 'config.json'
        config_path.write_text(json.dumps(config or self.config))
        result = subprocess.run(
            [self.nu, str(HOOKS / script), str(config_path)],
            input=json.dumps({'cwd': str(self.root), **payload}),
            text=True,
            capture_output=True,
            check=True,
        )
        self.assertEqual(result.stderr, '')
        return json.loads(result.stdout) if result.stdout.strip() else None

    def polish(self, name, args):
        return self.run_hook(
            'prose-polish/prose-polish.nu', {'tool_name': name, 'tool_input': args}
        )

    def test_questions_and_mcp_preserve_other_fields(self):
        question = 'This is a very useful question about the preferred workflow?'
        args = {
            'questions': [{
                'header': 'Workflow',
                'question': question,
                'options': [{'label': 'Default', 'description': question}],
            }]
        }
        result = self.polish('AskUserQuestion', args)['hookSpecificOutput']
        updated = result['updatedInput']['questions'][0]
        self.assertEqual(updated['header'], 'Workflow')
        self.assertIn('helpful', updated['question'])
        self.assertIn('helpful', updated['options'][0]['description'])
        result = self.polish(
            'mcp__GitHub__create_pull_request', {'body': question, 'head': 'feat/topic'}
        )
        updated = result['hookSpecificOutput']['updatedInput']
        self.assertEqual(updated['head'], 'feat/topic')
        self.assertIn('helpful', updated['body'])

    def test_rewrite_cannot_change_protected_literals(self):
        self.model.write_text(
            f'#!{sys.executable}\nimport json,sys\nr=json.load(sys.stdin)\n'
            'p=json.loads(r["user"].split("\\n")[-1])["passages"]\n'
            'for x in p: x["text"]="Rewritten paragraph drops the protected '
            'literal."\nprint(json.dumps({"passages":p}))\n'
        )
        self.assertIsNone(
            self.polish(
                'Write',
                {
                    'file_path': str(self.root / 'file.md'),
                    'content': 'This very useful information protects the important '
                    '`API` literal.',
                },
            )
        )

    def test_comment_review_only_added_source(self):
        patch = (
            '*** Begin Patch\n*** Update File: a.py\n*** Move to: b.py\n@@\n'
            ' # existing rationale stays\n-# removed rationale\n'
            '+# This new comment repeats the assignment below.\n+x = 1\n'
            '*** Delete File: deleted.py\n*** End Patch'
        )
        result = self.run_hook(
            'comment-gate/comment-gate.nu',
            {'tool_name': 'apply_patch', 'tool_input': {'command': patch}},
        )
        context = result['hookSpecificOutput']['additionalContext']
        self.assertIn('b.py', context)
        self.assertIn('This new comment', context)
        self.assertNotIn('existing rationale', context)
        self.assertNotIn('removed rationale', context)
        self.assertNotIn('deleted.py', context)

    def test_formatter_uses_payload_cwd_and_move_destination(self):
        formatter = self.root / 'formatter'
        formatter.write_text(
            f'#!{sys.executable}\nimport sys\nfrom pathlib import Path\n'
            'p=Path(sys.argv[-1]); p.write_text(p.read_text()+"formatted\\n'
            '")\nprint("diagnostic")\n'
        )
        formatter.chmod(0o755)
        (self.root / 'new.nix').write_text('new\n')
        (self.root / 'moved.nix').write_text('moved\n')
        config = {'patchInput': str(self.parser), 'nixfmt': str(formatter)}
        path = self.root / 'format.json'
        path.write_text(json.dumps(config))
        patch = (
            '*** Begin Patch\n*** Add File: new.nix\n+new\n'
            '*** Update File: old.nix\n*** Move to: moved.nix\n@@\n-old\n+moved\n'
            '*** Delete File: gone.nix\n*** End Patch'
        )
        result = subprocess.run(
            [self.nu, str(HOOKS / 'auto-format/auto-format.nu'), str(path)],
            input=json.dumps(
                {
                    'cwd': str(self.root),
                    'tool_name': 'apply_patch',
                    'tool_input': {'command': patch},
                }
            ),
            text=True,
            capture_output=True,
            check=True,
        )
        self.assertEqual((self.root / 'new.nix').read_text(), 'new\nformatted\n')
        self.assertEqual((self.root / 'moved.nix').read_text(), 'moved\nformatted\n')
        self.assertEqual(result.stdout.count('diagnostic'), 2)

    def test_gateway_file_credentials_and_fallback(self):
        token = self.root / 'token'
        token.write_text('fixture-token\n')
        curl = self.root / 'curl'
        curl.write_text(
            f'#!{sys.executable}\nimport json,sys\n'
            'a=sys.argv; request=json.load(sys.stdin)\n'
            'assert a[a.index("--header")+1]=="Authorization: Bearer fixture-token"\n'
            'assert a[-1]=="https://gateway.example/v1/chat/completions"\n'
            'assert a[a.index("--cacert")+1]=="fixture-ca"\n'
            'assert request["model"]=="rewrite-model"\n'
            'print(json.dumps({"choices":[{"finish_reason":"stop",'
            '"message":{"content":"gateway result"}}]}))\n'
        )
        curl.chmod(0o755)
        fallback = self.root / 'codex'
        fallback.write_text('#!/bin/sh\ncat >/dev/null\nprintf "fallback result"\n')
        fallback.chmod(0o755)
        config = {
            'gateway': {
                'baseUrl': 'https://gateway.example',
                'tokenFile': str(token),
                'caFile': 'fixture-ca',
            },
            'gatewayModel': 'rewrite-model',
            'gatewayTimeout': 5,
            'curl': str(curl),
            'codex': str(fallback),
            'codexModel': 'fallback-model',
            'codexTimeout': 5,
            'timeout': shutil.which('timeout'),
        }
        path = self.root / 'gateway.json'
        path.write_text(json.dumps(config))
        request = {'system': 'system', 'user': 'request', 'maxTokens': 100}

        def call():
            return subprocess.run(
                [self.nu, str(HOOKS / 'lib/model-call/model-call.nu'), str(path)],
                input=json.dumps(request),
                text=True,
                capture_output=True,
                check=True,
            )

        result = call()
        self.assertEqual(result.stdout, 'gateway result')
        self.assertEqual(result.stderr, '')
        token.unlink()
        result = call()
        self.assertEqual(result.stdout, 'fallback result')
        self.assertEqual(result.stderr, '')


if __name__ == '__main__':
    unittest.main()
