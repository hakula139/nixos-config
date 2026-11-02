// =================================================================================================
// OMP File Formatter Extension Tests
// =================================================================================================

import { expect, test } from 'bun:test';

import extension from './file-formatter.ts';

const formatter = '@fileFormatter@';

type Case = {
  name: string;
  toolName: string;
  input?: unknown;
  details?: unknown;
  isError?: boolean;
  report?: string;
  calls: string[][];
  context: string | null;
};

const cases: Case[] = [
  {
    name: 'a write formats its resolved path',
    toolName: 'write',
    input: { path: 'a.md' },
    details: { resolvedPath: '/home/u/src/app/a.md' },
    calls: [[formatter, '/home/u/src/app/a.md']],
    context: null,
  },
  {
    name: 'an edit carries its paths list',
    toolName: 'edit',
    input: { paths: ['a.md', 'b.md'] },
    calls: [[formatter, 'a.md', 'b.md']],
    context: null,
  },
  {
    name: 'an edit carries its single path',
    toolName: 'edit',
    input: { path: 'a.md' },
    calls: [[formatter, 'a.md']],
    context: null,
  },
  {
    name: 'a write to xd://resolve applied by ast_edit formats its files',
    toolName: 'write',
    input: { path: 'xd://resolve' },
    details: {
      xdev: {
        tool: 'resolve',
        inner: {
          action: 'apply',
          sourceToolName: 'ast_edit',
          sourceResultDetails: { files: ['x.ts'] },
        },
      },
    },
    report: 'runner report',
    calls: [[formatter, 'x.ts']],
    context: 'runner report',
  },
  {
    name: 'a discarded ast_edit preview is not formatted',
    toolName: 'write',
    input: { path: 'xd://resolve' },
    details: {
      xdev: {
        tool: 'resolve',
        inner: {
          action: 'discard',
          sourceToolName: 'ast_edit',
          sourceResultDetails: { files: ['x.ts'] },
        },
      },
    },
    calls: [],
    context: null,
  },
  {
    name: 'a resolve from another tool is not an ast_edit apply',
    toolName: 'write',
    input: { path: 'xd://resolve' },
    details: {
      xdev: {
        tool: 'resolve',
        inner: {
          action: 'apply',
          sourceToolName: 'other',
          sourceResultDetails: { files: ['x.ts'] },
        },
      },
    },
    calls: [],
    context: null,
  },
  {
    name: 'an errored result is ignored',
    toolName: 'write',
    input: { path: 'a.md' },
    details: { resolvedPath: '/home/u/src/app/a.md' },
    isError: true,
    calls: [],
    context: null,
  },
  {
    name: 'a read is ignored',
    toolName: 'read',
    input: { path: 'a.md' },
    details: { resolvedPath: '/home/u/src/app/a.md' },
    calls: [],
    context: null,
  },
];

test.each(cases)('$name', async (item) => {
  const calls: string[][] = [];
  let handler: (event: unknown) => Promise<unknown> = async () => undefined;
  const pi = {
    on(_event: string, registered: typeof handler) {
      handler = registered;
    },
    async exec(command: string, args: string[]) {
      calls.push([command, ...args]);
      return { stdout: item.report ?? '' };
    },
  };

  extension(pi as never);
  const result = await handler({
    toolName: item.toolName,
    input: item.input,
    details: item.details,
    isError: item.isError ?? false,
  });

  expect(calls).toEqual(item.calls);
  expect(result).toEqual(item.context == null ? undefined : { additionalContext: item.context });
});
