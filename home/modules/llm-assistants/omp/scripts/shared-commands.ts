import { readdirSync, readFileSync } from 'node:fs';
import { basename, join } from 'node:path';

const FRONTMATTER = /^---\n([\s\S]*?)\n---\n+/;

export default function sharedCommands() {
  return readdirSync(import.meta.dir)
    .filter((file) => file.endsWith('.md'))
    .map((file) => {
      const source = readFileSync(join(import.meta.dir, file), 'utf8');
      const frontmatter = source.match(FRONTMATTER)?.[1] ?? '';
      const template = source.replace(FRONTMATTER, '');

      return {
        name: basename(file, '.md'),
        description: frontmatter.match(/^description:\s*(.+)$/m)?.[1] ?? '',
        execute: (args: string[]) => template.replaceAll('$ARGUMENTS', args.join(' ')),
      };
    });
}
