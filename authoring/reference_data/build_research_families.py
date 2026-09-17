"""Freeze model producers' explicit base selections; never infer families from ID prefixes."""
import json
import hashlib
import argparse
from pathlib import Path
from research_combat_bindings import apply_bindings
from build_research_runtime_profiles import build as build_runtime_profiles
from build_research_model_interfaces import build as build_model_interfaces
from sync_engineering_traverse import sync as sync_engineering_traverse

ROOT = Path(__file__).resolve().parents[2]
TARGET = ROOT / 'assets/research/soviet_german_tree.json'
PLANS = {
    'ussr': ROOT / 'authoring/ussr_batch/fleet_plan.json',
    'germany': Path('E:/AIprogram/aimodel/_制作记录/德国/fleet_plan.json'),
}

def build(refresh_plans=False):
    sync_engineering_traverse()
    catalog = json.loads(TARGET.read_text(encoding='utf-8-sig'))
    sources = catalog.get('cache_entries', catalog['vehicles'])
    by_id = {r['id']: r for r in sources}
    previous = {r['id']: r for r in catalog['vehicles']}
    bases, mapped, provenance, excluded = [], set(), [], []
    for nation, path in PLANS.items():
        snapshot = ROOT / 'assets/research/plans' / (nation + '.json')
        if refresh_plans:
            raw = path.read_bytes()
            plan = json.loads(raw)
            rows = plan['vehicles']
            source = dict(nation=nation, source_path=path.as_posix(), sha256=hashlib.sha256(raw).hexdigest(), base_count=plan['base_count'])
        else:
            frozen = json.loads(snapshot.read_text(encoding='utf-8'))
            rows, source = frozen['mappings'], frozen['provenance']
        selections = {r['id']: r for r in rows if r['selection'] == 'base'}
        assert len(selections) == source['base_count']
        assert len({r['family'] for r in selections.values()}) == len(selections)
        provenance.append(source)
        # Retain the explicit mapping in-project for repeatable/offline audits.
        snapshot.parent.mkdir(parents=True, exist_ok=True)
        snapshot.write_text(json.dumps(dict(provenance=provenance[-1], mappings=[{k:r[k] for k in ['id','family','base_id','selection']} for r in rows]), ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
        for r in rows:
            if r['selection'] == 'non_vehicle_reference':
                excluded.append(dict(id=r['id'], reason=r['selection']))
                mapped.add(r['id'])
                continue
            assert r['base_id'] in selections, r
            if r['id'] in by_id:
                assert by_id[r['id']]['nation'] == nation
                mapped.add(r['id'])
        for identity, selection in selections.items():
            row = dict(by_id[identity])
            row['model'] = previous.get(identity, row).get('model')
            row['order'] = previous.get(identity, {}).get('order', 1000)
            row['combat_package'] = None
            row.update(base_model=True, family=selection['family'], base_id=identity)
            row['variant_refs'] = [dict(id=r['id'], label=by_id[r['id']]['label'], source_sha256=by_id[r['id']]['source_sha256']) for r in rows if r['base_id']==identity and r['id']!=identity and r['id'] in by_id]
            row['admission_status'] = 'static_preview_only' if row.get('model') else 'awaiting_model'
            bases.append(row)
    catalog.update(schema_version=2, family_policy='one_representative_per_producer_family', plan_sources=provenance, vehicles=bases)
    catalog['cache_entries'] = [{k:v for k,v in row.items() if k not in ['model','base_model','order','combat_package']} for row in sources]
    catalog['unmapped_cache_ids'] = sorted(by_id.keys()-mapped)
    catalog['excluded_references'] = excluded
    catalog['counts'] = {n:sum(r['nation']==n for r in bases) for n in PLANS}
    catalog['models'] = {n:sum(r['nation']==n and r.get('model') is not None for r in bases) for n in PLANS}
    catalog = apply_bindings(catalog)
    TARGET.write_text(json.dumps(catalog, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    build_runtime_profiles()
    build_model_interfaces()
    print('BASES', catalog['counts'], 'MODELS', catalog['models'], 'UNMAPPED_CACHE', len(catalog['unmapped_cache_ids']))

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--refresh-plans', action='store_true', help='Read current external producer plans instead of frozen mappings.')
    build(parser.parse_args().refresh_plans)
