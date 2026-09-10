import sys
import tomllib
from pathlib import Path
from typing import Any

import tomlkit


def render_value(value: Any) -> str:
    """Serialize a standalone TOML value for a Codex config override."""
    # An inline table renders nested dictionaries and arrays as values.
    holder = tomlkit.inline_table()
    holder['v'] = value
    assignment = holder.as_string().strip()[1:-1]
    return assignment.partition('=')[2].strip()


def main() -> int:
    if len(sys.argv) != 2:
        print('usage: profile-overrides.py <active-profile>', file=sys.stderr)
        return 2

    profile = Path(sys.argv[1])
    try:
        with profile.open('rb') as source:
            settings = tomllib.load(source)
    except (OSError, ValueError) as error:
        print(f'profile-overrides: {profile}: {error}', file=sys.stderr)
        return 1

    for key, value in settings.items():
        override = f'{tomlkit.key(key).as_string()}={render_value(value)}'
        sys.stdout.write(f'-c\0{override}\0')
    return 0


if __name__ == '__main__':
    sys.exit(main())
