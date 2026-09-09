"""Inventory GDScript string literals without treating comments as UI text."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TOKENS = re.compile(r'#[^\n]*|"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'')

def literals(source):
    for match in TOKENS.finditer(source):
        raw = match.group()
        if raw.startswith('#'):
            continue
        try:
            value = json.loads(raw) if raw.startswith('"') else raw[1:-1]
        except ValueError:
            continue
        yield match, value

def main():
    records = []
    for path in sorted((ROOT / 'scripts').rglob('*.gd')):
        source = path.read_text(encoding='utf-8-sig')
        strings = []
        for match, value in literals(source):
            if re.search('[\u3400-\u9fff]', value):
                strings.append({'line': source.count('\n', 0, match.start()) + 1, 'value': value})
        if strings:
            records.append({'file': path.relative_to(ROOT).as_posix(), 'strings': strings})
    output = ROOT / 'logs/027-localization-inventory.json'
    output.write_text(json.dumps(records, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps({'files': len(records), 'occurrences': sum(len(x['strings']) for x in records), 'unique': len({s['value'] for x in records for s in x['strings']}), 'output': str(output)}))

if __name__ == '__main__':
    main()
