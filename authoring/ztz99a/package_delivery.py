"""Create a clearly labelled comparison sheet and portable asset/source package."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import json, zipfile, hashlib

ROOT=Path(__file__).resolve().parent
PROJECT=ROOT.parent.parent
ASSET=PROJECT/'assets/vehicles/ztz99a'
font_path='C:/Windows/Fonts/arial.ttf'
font=ImageFont.truetype(font_path,26)
small=ImageFont.truetype(font_path,18)
sheet=Image.new('RGB',(1920,1480),'#17252b')
d=ImageDraw.Draw(sheet)
d.text((32,20),'ZTZ-99A | MULTIVIEW RECONSTRUCTION + BAKED LODs',fill='#e9e9df',font=font)
d.text((32,61),'Actual Blender renders | same camera and lighting | whole vehicle triangle counts',fill='#aabcc0',font=small)
high=json.loads((ROOT/'source_manifest.json').read_text())['high_triangles_evaluated']
rows=[('high_hero.png',f'HIGH SOURCE  /  {high:,} triangles')]
for budget in (4000,2000,1000):
    m=json.loads((ASSET/f'ztz99a_{budget}.manifest.json').read_text())
    rows.append((f'lod{budget}_hero.png',f'{budget:,} BUDGET  /  {m["actual_triangles"]:,} triangles  /  {m["texture_size"][0]} px'))
for i,(name,label) in enumerate(rows):
    x=(i%2)*960;y=100+(i//2)*690
    im=Image.open(ROOT/'renders'/name).convert('RGB').resize((960,660),Image.Resampling.LANCZOS)
    sheet.paste(im,(x,y+30));d.text((x+24,y+2),label,fill='#e9e9df',font=font)
sheet.save(ROOT/'renders/LOD_COMPARISON.png')

verify=json.loads((ROOT/'verification.json').read_text())
godot=json.loads((ROOT/'godot_verification.json').read_text())
assert verify['passed'] and godot['passed'],'Do not package failing assets'
files=[ROOT/'README.md',ROOT/'build_ztz99a.py',ROOT/'turret_multiview.py',ROOT/'verify_assets.py',ROOT/'package_delivery.py',ROOT/'source_manifest.json',ROOT/'verification.json',ROOT/'godot_verification.json',ROOT/'verification.log',ROOT/'godot_verification.log',ROOT/'high_build.log',ROOT/'ztz99a_high.blend',ROOT/'validation/project.godot',ROOT/'validation/check_assets.gd',ROOT/'BUILD_RECORD.json']
files+=list((ROOT/'reference').glob('*.png'))
files+=list((ROOT/'renders').glob('high_*.png'))
files+=[ROOT/'renders/LOD_COMPARISON.png']
for budget in (4000,2000,1000):
    files+=[ROOT/f'ztz99a_{budget}.blend',ROOT/f'lod{budget}_build.log',ROOT/'renders'/f'lod{budget}_hero.png',ROOT/'renders'/f'lod{budget}_side.png',ASSET/f'ztz99a_{budget}.glb',ASSET/f'ztz99a_{budget}.manifest.json']
    files+=list((ASSET/'textures').glob(f'ztz99a_{budget}_*.png'))
delivery=ROOT/'delivery';delivery.mkdir(exist_ok=True)
out=delivery/'ZTZ99A_HIGH_AND_BAKED_LODS.zip'
with zipfile.ZipFile(out,'w',zipfile.ZIP_DEFLATED,compresslevel=5) as archive:
    for p in files:archive.write(p,p.relative_to(PROJECT).as_posix())
print(json.dumps({'archive':str(out),'bytes':out.stat().st_size,'files':len(files),'sha256':hashlib.sha256(out.read_bytes()).hexdigest()}))
