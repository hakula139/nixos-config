import argparse
import json
import logging
import sys
from pathlib import Path

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


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument('-u', '--users-path', type=Path, required=True)
    parser.add_argument('-t', '--template-path', type=Path, required=True)
    parser.add_argument('-s', '--sni-host', type=str, required=True)
    parser.add_argument('-o', '--output-dir', type=Path, required=True)
    return parser.parse_args()


def load_users(path: Path) -> dict:
    try:
        with open(path) as f:
            users = json.load(f)
    except FileNotFoundError:
        logging.error('Users file not found at %s', path)
        return {}
    except json.JSONDecodeError as e:
        logging.error('Invalid JSON in users file: %s', e)
        return {}

    if not isinstance(users, dict):
        logging.error('Users file must contain an object mapping names to users')
        return {}

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
        try:
            uuid: str = user['uuid']
            short_id: str = user['shortId']
        except KeyError as e:
            logging.warning('User %s is missing required field: %s', name, e.args[0])
            failure_count += 1
            continue

        try:
            config = template.render(
                uuid=uuid,
                short_id=short_id,
                sni_host=args.sni_host,
            )
        except Exception as e:
            logging.error('Failed to render template for %s: %s', name, e)
            failure_count += 1
            continue

        output_path: Path = args.output_dir / f'{uuid}.yaml'
        try:
            output_path.write_text(config)
            output_path.chmod(0o640)
        except OSError as e:
            logging.error('Failed to write config for %s: %s', name, e)
            failure_count += 1
            continue

        logging.info('Generated Clash subscription for %s', name)
        success_count += 1

    if failure_count:
        logging.error(
            'Completed with %d failure(s); Generated %d of %d users',
            failure_count,
            success_count,
            len(users),
        )
        return 1

    logging.info('Generated Clash subscriptions for %d users', success_count)
    return 0


if __name__ == '__main__':
    sys.exit(main())
