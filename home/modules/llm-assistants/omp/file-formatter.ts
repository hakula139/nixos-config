// =================================================================================================
// OMP File Formatter Extension
// =================================================================================================

import type { ExtensionAPI } from '@oh-my-pi/pi-coding-agent';

const formatter = '@fileFormatter@';

function editedPaths(toolName: string, input: any, details: any): string[] {
  if (toolName === 'edit') {
    return input.paths ?? (input.path ? [input.path] : []);
  }
  if (toolName !== 'write') {
    return [];
  }

  // ast_edit stages a preview, and a write to xd://resolve applies it.
  const inner = details?.xdev?.inner;
  if (inner?.action === 'apply' && inner.sourceToolName === 'ast_edit') {
    return inner.sourceResultDetails?.files ?? [];
  }

  return details?.resolvedPath ? [details.resolvedPath] : [];
}

export default function (pi: ExtensionAPI) {
  pi.on('tool_result', async (event) => {
    if (event.isError) {
      return;
    }

    const paths = editedPaths(event.toolName, event.input, event.details);
    if (paths.length === 0) {
      return;
    }

    const run = await pi.exec(formatter, paths);
    const report = run.stdout.trim();
    if (report.length === 0) {
      return;
    }

    return { additionalContext: report };
  });
}
