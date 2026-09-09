"""Independent Blender source fingerprint and armor correspondence verification.

-- <report.json> [baseline.json]
Fingerprints compare meaningful mesh/UV/pivot data, not .blend timestamps.
"""
import bpy
import sys
import json
import hashlib
from pathlib import Path
from mathutils import Vector

AUTHOR=Path(__file__).resolve().parent
ROOT=AUTHOR.parents[1]


def digest(value):
    return hashlib.sha256(json.dumps(value,sort_keys=True,separators=(',',':')).encode()).hexdigest()


def rounded(values): return [round(float(v),6) for v in values]


def run():
    args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
    destination=Path(args[0]) if args else ROOT/'MODEL_REPRO_REPORT.json'
    report={'blender':bpy.app.version_string,'models':{},'texture_sha256':hashlib.sha256((ROOT/'assets/vehicles/textures/vehicle_concept_atlas_v1.png').read_bytes()).hexdigest()}
    for seed_file in sorted((AUTHOR/'seeds').glob('*.json')):
        id=seed_file.stem; seed=json.loads(seed_file.read_text(encoding='utf-8'))
        bpy.ops.wm.open_mainfile(filepath=str(AUTHOR/(id+'.blend')))
        geometry=[]; count=0; matched=0
        for obj in sorted(bpy.data.objects,key=lambda o:o.name):
            row={'name':obj.name,'parent':obj.parent.name if obj.parent else '', 'matrix':rounded(v for r in obj.matrix_local for v in r)}
            if obj.type=='MESH':
                row['vertices']=[rounded(v.co) for v in obj.data.vertices]
                row['faces']=[list(p.vertices) for p in obj.data.polygons]
                count+=sum(len(p.vertices)-2 for p in obj.data.polygons)
                if obj.data.uv_layers.active is None: raise RuntimeError(id+': missing UV '+obj.name)
                row['uv']=[rounded(v.uv) for v in obj.data.uv_layers.active.data]
            geometry.append(row)
        for patch in seed['armor']:
            obj=bpy.data.objects.get('Armor_'+patch['id'])
            if obj is None: raise RuntimeError(id+': missing armor '+patch['id'])
            actual=[]
            for face in obj.data.polygons:
                vertices=[]
                for index in face.vertices:
                    p=obj.matrix_local@obj.data.vertices[index].co
                    vertices.append(tuple(rounded((p.x,p.z,-p.y))))
                actual.append(tuple(sorted(vertices)))
            expected=[]
            for start in range(0,len(patch['triangles']),3):
                expected.append(tuple(sorted(tuple(rounded(patch['vertices'][index])) for index in patch['triangles'][start:start+3])))
            if sorted(actual)!=sorted(expected): raise RuntimeError(id+': armor geometry mismatch '+patch['id'])
            matched+=1
        if count>1100: raise RuntimeError(id+': triangle budget exceeded '+str(count))
        report['models'][id]={'triangles':count,'armor_patches_verified':matched,'geometry_uv_pivots_sha256':digest(geometry),
                             'seed_sha256':hashlib.sha256(seed_file.read_bytes()).hexdigest()}
        print('REPRO_MODEL_PASS',id,count,matched,flush=True)
    if len(args)>1:
        baseline=json.loads(Path(args[1]).read_text(encoding='utf-8'))
        if report!=baseline: raise RuntimeError('Rebuild differs from baseline geometry, UVs, pivots, seed, texture or Blender version')
        print('REPRO_BASELINE_MATCH_PASS',flush=True)
    destination.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')


if __name__=='__main__': run()
