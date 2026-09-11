"""Independent GLB and baked image inspection. Run with Blender Python."""
import bpy, json, struct, math, hashlib
from pathlib import Path
import numpy as np

ROOT=Path(__file__).resolve().parent
ASSET=ROOT.parent.parent/'assets/vehicles/ztz99a'
CHECKS=[]

def check(name,condition,detail=''):
    CHECKS.append({'name':name,'pass':bool(condition),'detail':detail})
    print(('[PASS] ' if condition else '[FAIL] ')+name+' '+str(detail),flush=True)

def read_glb(path):
    raw=path.read_bytes();magic,ver,length=struct.unpack_from('<4sII',raw)
    assert magic==b'glTF' and ver==2 and length==len(raw)
    off=12;doc=None;binary=None
    while off<len(raw):
        n,t=struct.unpack_from('<II',raw,off);off+=8;c=raw[off:off+n];off+=n
        if t==0x4E4F534A:doc=json.loads(c)
        if t==0x004E4942:binary=c
    return doc,binary

def accessor(doc,binary,i):
    a=doc['accessors'][i];v=doc['bufferViews'][a['bufferView']]
    types={5126:np.float32,5125:np.uint32,5123:np.uint16,5121:np.uint8}
    widths={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}
    dtype=types[a['componentType']];width=widths[a['type']];offset=v.get('byteOffset',0)+a.get('byteOffset',0)
    size=np.dtype(dtype).itemsize;stride=v.get('byteStride',size*width)
    return np.ndarray((a['count'],width),dtype=dtype,buffer=binary,offset=offset,strides=(stride,size)).copy()

for budget in (4000,2000,1000):
    path=ASSET/f'ztz99a_{budget}.glb'
    check(f'{budget} GLB exists',path.is_file())
    if not path.is_file():continue
    doc,bin=read_glb(path)
    count=0;degenerate=0;uv_valid=True;normal_valid=True;tangent_valid=True;tex_valid=True
    uv_coverage=np.zeros((512,512),dtype=np.uint16)
    for mesh in doc['meshes']:
        for p in mesh['primitives']:
            ids=accessor(doc,bin,p['indices']).reshape(-1,3);count+=len(ids)
            pos=accessor(doc,bin,p['attributes']['POSITION'])
            area=np.linalg.norm(np.cross(pos[ids[:,1]]-pos[ids[:,0]],pos[ids[:,2]]-pos[ids[:,0]]),axis=1)
            degenerate+=int(np.count_nonzero(area<1e-10))
            uv=accessor(doc,bin,p['attributes']['TEXCOORD_0'])
            uv_valid &= bool(np.isfinite(uv).all() and uv.min()>=-.00001 and uv.max()<=1.00001)
            for tri in uv[ids]:
                tri=tri*512
                lo=np.maximum(np.floor(tri.min(axis=0)).astype(int),0);hi=np.minimum(np.ceil(tri.max(axis=0)).astype(int),511)
                if np.any(hi<lo):continue
                xx,yy=np.meshgrid(np.arange(lo[0],hi[0]+1)+.5,np.arange(lo[1],hi[1]+1)+.5)
                a,b,c=tri
                denom=(b[1]-c[1])*(a[0]-c[0])+(c[0]-b[0])*(a[1]-c[1])
                if abs(denom)<1e-8:continue
                u=((b[1]-c[1])*(xx-c[0])+(c[0]-b[0])*(yy-c[1]))/denom
                v=((c[1]-a[1])*(xx-c[0])+(a[0]-c[0])*(yy-c[1]))/denom
                mask=(u>1e-4)&(v>1e-4)&(u+v<.9999)
                uv_coverage[lo[1]:hi[1]+1,lo[0]:hi[0]+1]+=mask
            normals=accessor(doc,bin,p['attributes']['NORMAL'])
            normal_valid &= bool(np.isfinite(normals).all() and np.max(np.abs(np.linalg.norm(normals,axis=1)-1))<.005)
            tangent_valid &= 'TANGENT' in p['attributes']
    manifest=json.loads((ASSET/f'ztz99a_{budget}.manifest.json').read_text())
    check(f'{budget} full export triangles',count==manifest['actual_triangles'] and count<=budget,{'actual':count,'budget':budget})
    check(f'{budget} nondegenerate triangles',degenerate==0,degenerate)
    check(f'{budget} finite unit normals',normal_valid)
    check(f'{budget} atlas UV bounds',uv_valid)
    check(f'{budget} atlas interior overlap sample',np.count_nonzero(uv_coverage>1)==0,{'overlap_pixels':int(np.count_nonzero(uv_coverage>1)),'sample_resolution':512,'occupied_fraction':float(np.mean(uv_coverage>0))})
    check(f'{budget} baked tangent export',tangent_valid)
    nodes={n.get('name'):i for i,n in enumerate(doc['nodes'])}
    for parent,child in [('hull','turret'),('turret','barrel'),('barrel','gun_recoil'),('gun_recoil','muzzle')]:
        check(f'{budget} hierarchy {parent}/{child}',parent in nodes and child in nodes and nodes[child] in doc['nodes'][nodes[parent]].get('children',[]))
    check(f'{budget} no high/camera/studio in GLB',all(not n.get('name','').startswith(('HIGH_','Studio_')) for n in doc['nodes']) and not doc.get('cameras'))
    check(f'{budget} all textures embedded',all('bufferView' in i and not i.get('uri') for i in doc['images']))
    mat=doc['materials'][0]
    check(f'{budget} PBR color normal ORM connected','normalTexture' in mat and 'occlusionTexture' in mat and 'metallicRoughnessTexture' in mat.get('pbrMetallicRoughness',{}))
    hashes={path.name:hashlib.sha256(path.read_bytes()).hexdigest()}
    for ch in ('basecolor','normal','orm'):
        file=ASSET/'textures'/f'ztz99a_{budget}_{ch}.png'
        img=bpy.data.images.load(str(file),check_existing=False)
        if ch!='basecolor':img.colorspace_settings.name='Non-Color'
        vals=np.empty(len(img.pixels),dtype=np.float32);img.pixels.foreach_get(vals);vals=vals.reshape(-1,4)[:,:3]
        check(f'{budget} {ch} actual dimensions',list(img.size)==manifest['texture_size'],list(img.size))
        check(f'{budget} {ch} nonempty finite bake',np.isfinite(vals).all() and np.std(vals,axis=0).max()>.025,{'min':vals.min(axis=0).tolist(),'max':vals.max(axis=0).tolist(),'std':vals.std(axis=0).tolist()})
        hashes[file.name]=hashlib.sha256(file.read_bytes()).hexdigest()
        bpy.data.images.remove(img)
    manifest['sha256']=hashes
    (ASSET/f'ztz99a_{budget}.manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf8')

report={'passed':all(x['pass'] for x in CHECKS),'checks':CHECKS,'blender':bpy.app.version_string}
(ROOT/'verification.json').write_text(json.dumps(report,indent=2),encoding='utf8')
if not report['passed']:raise RuntimeError('Asset verification failed')
print('ZTZ99A_ASSET_CHECKS_PASS',flush=True)
