from pathlib import Path
import json,hashlib,subprocess
ROOT=Path(__file__).resolve().parent
PROJECT=ROOT.parent.parent
ASSET=PROJECT/'assets/vehicles/ztz99a'
commands=[
    {'argv':['E:/blender/blender.exe','--background','--threads','8','--python-exit-code','1','--python','authoring/ztz99a/build_ztz99a.py','--','high'],'exit_code':0,'log':'high_build.log'},
]
for b in (4000,2000,1000):
    commands.append({'argv':['E:/blender/blender.exe','--background','--threads','4','--python-exit-code','1','--python','authoring/ztz99a/build_ztz99a.py','--','lod',str(b)],'exit_code':0,'log':f'lod{b}_build.log'})
commands.extend([
    {'argv':['E:/blender/blender.exe','--background','--threads','4','--python-exit-code','1','--python','authoring/ztz99a/verify_assets.py'],'exit_code':0,'log':'verification.log'},
    {'argv':['E:/AIprogram/mcthunder-development/tools/godot/Godot_v4.7.2-stable_win64_console.exe','--headless','--path','authoring/ztz99a/validation','-s','res://check_assets.gd'],'exit_code':0,'log':'godot_verification.log'},
])
bl=json.loads((ROOT/'verification.json').read_text())
gd=json.loads((ROOT/'godot_verification.json').read_text())
record={
    'date':'2026-09-10','task':'99A reference reconstruction + high-to-low bake; turret rebuilt against multiview after user feedback',
    'primary_reference':'reference/multiview.png','working_directory':str(PROJECT),
    'git_head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=PROJECT,text=True).strip(),
    'git_branch':subprocess.check_output(['git','branch','--show-current'],cwd=PROJECT,text=True).strip(),
    'changes':'New isolated asset authoring and runtime files; existing game not integrated or replaced',
    'commands':commands,
    'verification':{'asset_passed':bl['passed'],'asset_checks':len(bl['checks']),'godot_passed':gd['passed'],'godot_checks':len(gd['checks'])},
    'human_acceptance':'PENDING; earlier feedback rejected initial turret, subsequent multi-view turret revision has not been explicitly accepted by user',
    'reference_limitations':'Art has contradictory wheel count. Six road wheels per side chosen. Unseen geometry and dimensions estimated; not a War Thunder asset extraction.',
    'lods':[{k:json.loads((ASSET/f'ztz99a_{b}.manifest.json').read_text())[k] for k in ('id','budget_triangles','actual_triangles','texture_size')} for b in (4000,2000,1000)],
    'next_action':'Review the revised high turret and LOD comparison; any further shape changes invalidate corresponding LOD bakes. Game integration requires a separate scoped task.',
    'delivered_source_sha256':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in [ROOT/'build_ztz99a.py',ROOT/'turret_multiview.py',ROOT/'ztz99a_high.blend']},
    'reference_sha256':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in (ROOT/'reference').glob('*.png')}
}
(ROOT/'BUILD_RECORD.json').write_text(json.dumps(record,ensure_ascii=False,indent=2),encoding='utf8')
print(json.dumps(record['verification']))
