"""Check translation keys and substitution contracts; no game state is simulated."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
strings = json.loads((ROOT / 'assets/localization/zh_CN.json').read_text(encoding='utf-8-sig'))
errors = []
references = set()
for path in (ROOT / 'scripts').rglob('*.gd'):
    source = path.read_text(encoding='utf-8-sig')
    for key in re.findall(r'LocalizationService\.text\("([^"]+)"\)', source):
        references.add(key)
        if key not in strings:
            errors.append(f'{path.relative_to(ROOT)}: missing {key}')
actions_source = (ROOT / 'scripts/ui/input_binding_service.gd').read_text(encoding='utf-8-sig')
actions = set(re.findall(r'"([a-z_0-9]+)": \[LocalizationService', actions_source))
for key, value in strings.items():
    if not isinstance(value, str) or not value.strip():
        errors.append(f'{key}: empty/non-text value')
        continue
    for action in re.findall(r'\{key:([^}]+)\}', value):
        if action not in actions:
            errors.append(f'{key}: unknown action {action}')
print(json.dumps({'strings': len(strings), 'referenced_keys': len(references), 'errors': errors}, ensure_ascii=False, indent=2))
raise SystemExit(bool(errors))
