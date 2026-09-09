import sys
from pathlib import Path
from typing import Any

import tomlkit
from tomlkit.exceptions import TOMLKitError


def render_value(value: Any) -> str:
    """Render one TOML value the way `codex -c <key>=<value>` parses it.

    tomlkit renders values only in context, so a throwaway inline table supplies
    one. Its key is a fixed identifier, which makes the first `=` the separator
    and never part of the value.
    """
    holder = tomlkit.inline_table()
    holder['v'] = value
    body = holder.as_string().strip().removeprefix('{').removesuffix('}')
    return body.split('=', 1)[1].strip()


def main() -> int:
    if len(sys.argv) != 2:
        print('usage: profile-overrides.py <active-profile>', file=sys.stderr)
        return 2

    profile = Path(sys.argv[1])
    try:
        # unwrap() reduces the document to plain Python values. Handing tomlkit's
        # own containers back to the serializer renders an array of tables as
        # table syntax, which is not a value `-c` can parse.
        table = tomlkit.parse(profile.resolve().read_text()).unwrap()
    except (OSError, TOMLKitError) as error:
        print(f'profile-overrides: {profile}: {error}', file=sys.stderr)
        return 1

    for key, value in table.items():
        entry = f'{tomlkit.key(key).as_string()}={render_value(value)}'
        # NUL-delimited, so a value holding whitespace survives the caller's read.
        sys.stdout.write(f'-c\0{entry}\0')
    return 0


if __name__ == '__main__':
    sys.exit(main())
