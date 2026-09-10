"""One-time literal migration; stable keys and source provenance remain reviewable."""
import argparse
import hashlib
import json
import re
from pathlib import Path
from localization_inventory import ROOT, literals

def migrate(apply=False):
    bank_path = ROOT / 'assets/localization/zh_CN.json'
    bank = json.loads(bank_path.read_text(encoding='utf-8')) if bank_path.exists() else {}
    provenance_path = ROOT / 'authoring/localization_sources.json'
    provenance = json.loads(provenance_path.read_text(encoding='utf-8')) if provenance_path.exists() else {}
    english_path = ROOT / 'authoring/localization_english.json'
    english = json.loads(english_path.read_text(encoding='utf-8')) if english_path.exists() else {}
    changes, skipped = {}, []
    for path in sorted((ROOT / 'scripts').rglob('*.gd')):
        if path.name == 'localization_service.gd':
            continue
        source = path.read_text(encoding='utf-8-sig')
        edits = []
        declarations = list(re.finditer(r'(?m)^(?P<indent>\t*)(?:static )?(?:const|var|func|signal|@export).*', source))
        converted = set()
        for match, value in literals(source):
            if value == 'TEST ONLY':
                # Canonical provenance marker used by admission and shot records.
                continue
            if not re.search('[\u3400-\u9fff]', value) and value not in english:
                continue
            line_start = source.rfind('\n', 0, match.start())+1
            line_prefix = source[line_start:match.start()]
            if (line_prefix.lstrip().startswith('func ') or line_prefix.lstrip().startswith('static func ')) and '->' not in line_prefix:
                skipped.append({'file': path.relative_to(ROOT).as_posix(), 'value': value, 'reason': 'function_default'})
                continue
            key = 'ui_' + hashlib.sha256(value.encode()).hexdigest()[:12]
            bank[key] = english.get(value, value)
            provenance[key] = value
            edits.append((match.start(), match.end(), f'LocalizationService.text("{key}")'))
            previous = [d for d in declarations if d.start() <= match.start()]
            if previous:
                declaration = previous[-1]
                if re.match(r'\t*const\b', declaration.group()) and declaration.start() not in converted:
                    indent = declaration.group('indent')
                    start = declaration.start()+len(indent)
                    edits.append((start, start+5, 'static var' if not indent else 'var'))
                    converted.add(declaration.start())
        if edits:
            for start, stop, text in sorted(edits, reverse=True):
                source = source[:start]+text+source[stop:]
            changes[path.relative_to(ROOT).as_posix()] = len(edits)
            if apply:
                path.write_text(source, encoding='utf-8')
    if apply:
        bank_path.parent.mkdir(parents=True, exist_ok=True)
        bank_path.write_text(json.dumps(bank, ensure_ascii=False, indent=2, sort_keys=True)+'\n', encoding='utf-8')
        provenance_path.write_text(json.dumps(provenance, ensure_ascii=False, indent=2, sort_keys=True)+'\n', encoding='utf-8')
    print(json.dumps({'apply': apply, 'files': changes, 'entries': len(bank), 'skipped': skipped}, ensure_ascii=False))

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--apply', action='store_true')
    migrate(parser.parse_args().apply)
