import bpy
for o in bpy.data.objects:
    if o.type != 'MESH':
        continue
    ys = [v.co.z for v in o.data.vertices]  # blender z = game y (coord(x,y,z)=(x,-z,y) -> blender z=game y)
    mn, mx = min(ys), max(ys)
    if mn < -0.10:
        bad = [(round(v.co.x, 2), round(v.co.y, 2), round(v.co.z, 2)) for v in o.data.vertices if v.co.z < -0.10]
        print('T34_PROBE', o.name, 'minGameY', round(mn, 3), 'bad_count', len(bad), 'sample', bad[:6])
print('T34_PROBE_DONE')
