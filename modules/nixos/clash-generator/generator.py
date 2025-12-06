import json
import sys
from pathlib import Path

from jinja2 import Environment, FileSystemLoader


users_path = Path(sys.argv[1])
template_path = Path(sys.argv[2])
output_dir = Path(sys.argv[3])

with open(users_path) as f:
    users = json.load(f)

env = Environment(loader=FileSystemLoader(template_path.parent))
template = env.get_template(template_path.name)

output_dir.mkdir(parents=True, exist_ok=True)
output_dir.chmod(0o755)

for _, user in users.items():
    uuid = user["uuid"]
    short_id = user["shortId"]
    config = template.render(uuid=uuid, short_id=short_id)
    output_path = output_dir / f"{uuid}.yaml"
    output_path.write_text(config)
    output_path.chmod(0o644)

print(f"Generated Clash subscriptions for {len(users)} users")
