import argparse
import json
import logging
import sys
from enum import IntEnum
from pathlib import Path
from typing import Any, TypedDict, cast

from jinja2 import (
    Environment,
    FileSystemLoader,
    Template,
    TemplateNotFound,
    TemplateSyntaxError,
)


logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S',
    handlers=[logging.StreamHandler()],
)


class UserLevel(IntEnum):
    USER = 0
    ADMIN = 1


class UserConfig(TypedDict):
    uuid: str
    shortId: str
    level: UserLevel


class ServerConfig(TypedDict):
    id: str
    name: str
    min_level: UserLevel


REGION_FLAGS: dict[str, str] = {
    'us': '🇺🇸',
    'sg': '🇸🇬',
}


def build_server_config(server_id: str, min_level: UserLevel) -> ServerConfig:
    region = server_id.rsplit('-', 1)[0]
    flag = REGION_FLAGS.get(region, '🏳️')

    return {
        'id': server_id,
        'name': f'{flag} {server_id.upper()}',
        'min_level': min_level,
    }


SERVERS: list[ServerConfig] = [
    build_server_config('us-1', UserLevel.USER),
    build_server_config('us-2', UserLevel.USER),
    build_server_config('us-3', UserLevel.USER),
    build_server_config('us-4', UserLevel.ADMIN),
    build_server_config('sg-1', UserLevel.USER),
]


def servers_for_level(level: UserLevel) -> list[ServerConfig]:
    return [s for s in SERVERS if level >= s['min_level']]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument('-u', '--users-path', type=Path, required=True)
    parser.add_argument('-t', '--template-path', type=Path, required=True)
    parser.add_argument('-s', '--sni-host', type=str, required=True)
    parser.add_argument('-o', '--output-dir', type=Path, required=True)
    return parser.parse_args()


def parse_user_level(name: str, raw: Any) -> UserLevel | None:
    if raw is None:
        return UserLevel.USER
    if not isinstance(raw, str):
        logging.warning('User %s has non-string level; skipping', name)
        return None
    try:
        return UserLevel[raw.upper()]
    except KeyError:
        logging.warning('User %s has unknown level %r; skipping', name, raw)
        return None


def build_user_config(name: str, data: Any) -> UserConfig | None:
    if not isinstance(data, dict):
        logging.warning('User %s has invalid format', name)
        return None

    user_dict = cast(dict[str, Any], data)
    uuid = user_dict.get('uuid')
    short_id = user_dict.get('shortId')

    if not isinstance(uuid, str) or not isinstance(short_id, str):
        logging.warning('User %s is missing required fields: uuid, shortId', name)
        return None

    level = parse_user_level(name, user_dict.get('level'))
    if level is None:
        return None

    return {
        'uuid': uuid,
        'shortId': short_id,
        'level': level,
    }


def load_users(path: Path) -> dict[str, UserConfig]:
    try:
        with open(path) as f:
            data = json.load(f)
    except FileNotFoundError:
        logging.error('Users file not found at %s', path)
        return {}
    except json.JSONDecodeError as e:
        logging.error('Invalid JSON in users file: %s', e)
        return {}

    if not isinstance(data, dict):
        logging.error('Users file must contain an object mapping names to users')
        return {}

    users: dict[str, UserConfig] = {}
    for name, user_data in cast(dict[str, Any], data).items():
        user_config = build_user_config(name, user_data)
        if user_config is not None:
            users[name] = user_config

    return users


def load_template(path: Path) -> Template | None:
    env = Environment(loader=FileSystemLoader(path.parent))
    try:
        return env.get_template(path.name)
    except TemplateNotFound:
        logging.error('Template %s not found', path.name)
    except TemplateSyntaxError as e:
        logging.error('Template syntax error in %s: %s', path, e)
    return None


def main() -> int:
    args = parse_args()

    users = load_users(args.users_path)
    if not users:
        return 1

    template = load_template(args.template_path)
    if template is None:
        return 1

    success_count = 0
    failure_count = 0

    for name, user in users.items():
        user_servers = servers_for_level(user['level'])
        try:
            config = template.render(
                servers=user_servers,
                uuid=user['uuid'],
                short_id=user['shortId'],
                sni_host=args.sni_host,
            )
        except Exception as e:
            logging.error('Failed to render template for %s: %s', name, str(e))
            failure_count += 1
            continue

        output_path: Path = args.output_dir / f'{user["uuid"]}.yaml'
        try:
            output_path.write_text(config)
            output_path.chmod(0o640)
        except OSError as e:
            logging.error('Failed to write config for %s: %s', name, str(e))
            failure_count += 1
            continue

        logging.info(
            'Generated Clash subscription for %s (level=%s, %d servers)',
            name,
            user['level'].name.lower(),
            len(user_servers),
        )
        success_count += 1

    if failure_count:
        logging.error(
            'Completed with %d failure(s); Generated %d / %d users',
            failure_count,
            success_count,
            len(users),
        )
        return 1

    logging.info('Generated Clash subscriptions for %d users', success_count)
    return 0


if __name__ == '__main__':
    sys.exit(main())
