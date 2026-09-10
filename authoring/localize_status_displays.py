"""Migrate presentation-only status literals; never rewrite simulation records."""
import json
from localization_inventory import ROOT, literals

FILES = ['scripts/hud.gd','scripts/training/damage_range.gd','scripts/training/recovery_range.gd',
         'scripts/training/armor_range.gd','scripts/training/armor_training_targets.gd',
         'scripts/replay/replay_controller.gd','scripts/inspection/vehicle_inspector.gd',
         'scripts/inspection/query_debug_panel.gd']
SELECT = {'READY','OUT','YES','NO','ON','OFF','AMMO','PAUSED','PROJECTILES','DISABLED','OPERATIONAL',
          'ALIVE','DESTROYED','UNKNOWN','Appearance','Armor','Interior','Barrel axis (muzzle)',
          'Camera aim ray','A center -> B center','Custom from/to','RICOCHET'}
for relative in FILES:
    path = ROOT / relative
    source = path.read_text(encoding='utf-8-sig')
    edits = []
    for match, value in literals(source):
        if value not in SELECT:
            continue
        prefix = source[max(0,match.start()-40):match.start()]
        if prefix.endswith('LocalizationService.status('):
            continue
        edits.append((match.start(),match.end(),'LocalizationService.status('+json.dumps(value)+')'))
    if not edits:
        continue
    for start, stop, value in reversed(edits):
        source = source[:start]+value+source[stop:]
    for name in ['MODES','PROBES','CASES']:
        source = source.replace('const '+name, 'static var '+name)
    path.write_text(source,encoding='utf-8')
    print(relative, len(edits))
