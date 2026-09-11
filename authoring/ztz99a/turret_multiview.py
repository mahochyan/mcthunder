"""Turret reconstruction from the supplied orthographic multiview plate.
The front cheeks have a low vertical lip and a long rising upper wedge;
the bustle has a rising underside, rather than a scaled rectangular prism.
"""
import math
from mathutils import Vector, Matrix
import bpy

def build(b):
    H=b.HIGH;L=b.LEVEL
    box=b.box;cyl=b.cyl;mesh=b.mesh_obj;plate=b.plate;bolt=b.bolt;pi=math.pi
    group='turret'
    def bar(name,a,c,r=.009,mat='steel'):
        return cyl(name,a,c,r,group,mat,10 if H else 4,bevel=0)
    def quad_point(q,u,v):
        return Vector(q[0]).lerp(Vector(q[1]),u).lerp(Vector(q[3]).lerp(Vector(q[2]),u),v)
    # Circular bearing remains under the much wider front cheeks.
    cyl('Turret_bearing_lower',(0,-.20,1.535),(0,-.20,1.625),1.045,group,'steel',96 if H else 12,bevel=.005)
    cyl('Turret_bearing_upper',(0,-.20,1.625),(0,-.20,1.705),1.12,group,'dark',96 if H else 12,bevel=.005)
    core_bottom=[(-.36,.95),(.36,.95),(1.16,.56),(1.32,-.28),(1.24,-2.32),(-1.24,-2.32),(-1.32,-.28),(-1.16,.56)]
    core_top=[(-.36,.51),(.36,.51),(1.05,.35),(1.27,-.27),(1.24,-2.34),(-1.24,-2.34),(-1.27,-.27),(-1.05,.35)]
    verts=[(x,y,1.75+max(0,-y-.05)/2.30*.255) for x,y in core_bottom]+[(x,y,2.395) for x,y in core_top]
    k=len(core_bottom)
    mesh('Turret_structural_shell',verts,[tuple(reversed(range(k))),tuple(range(k,2*k))]+[(i,(i+1)%k,(i+1)%k+k,i+k) for i in range(k)],group,'paint',.012)
    # Left/right armor cheeks. The top is a 1.55 m ramp, NOT a flat lid.
    for s in (-1,1):
        points=[(.36,1.64,1.765),(1.25,1.60,1.765),(1.52,-.02,1.765),(.36,-.06,1.765),
                (.36,1.665,2.085),(1.205,1.625,2.085),(1.345,-.025,2.435),(.36,-.06,2.435)]
        verts=[(s*x,y,z) for x,y,z in points]
        faces=[(0,3,2,1),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7),(4,5,6,7)]
        mesh('Cheek_armor_wedge_L' if s<0 else 'Cheek_armor_wedge_R',verts,faces,group,'paint',.008)
        q=[verts[i] for i in (4,5,6,7)]
        # Roof ERA sits flush to that ramp, split lengthwise in multiview panel layout.
        if H or L>=2000:
            cols=3 if H else 2;rows=2 if H else 1
            for i in range(cols):
                for j in range(rows):
                    u0=i/cols+.004;u1=(i+1)/cols-.004;v0=j/rows+.004;v1=(j+1)/rows-.004
                    panel=[tuple(quad_point(q,u,v)+Vector((0,0,.012))) for u,v in [(u0,v0),(u1,v0),(u1,v1),(u0,v1)]]
                    plate('Upper_cheek_ERA_plate',panel,.018,group)
                    if H:
                        for u,v in [(u0+.06,v0+.07),(u1-.06,v1-.07)]:
                            pt=quad_point(q,u,v)+Vector((0,0,.028));bolt('Cheek_recessed_bolt',pt,(0,.22,.975),group,.011)
            if H:
                # Front vertical lip divisions and welded lower edge.
                for i in (1,2):
                    x=s*(.36+(.89/3)*i)
                    bar('Front_ERA_vertical_joint',(x,1.651,1.80),(x,1.651,2.078),.004,'dark')
                bar('Cheek_lower_weld',(s*.40,1.648,1.779),(s*1.21,1.61,1.779),.006,'steel')
        # Side bustle band: planar vertical outer face, floor rising toward rear.
        xx=s*1.49;ys=[-.055,-2.54]
        topz=2.432
        count=7 if H else 3 if L==4000 else 1
        for j in range(count):
            ya=ys[0]+(ys[1]-ys[0])*j/count-.006;yb=ys[0]+(ys[1]-ys[0])*(j+1)/count+.006
            z=lambda y:1.77+(-y-.055)/2.485*.215
            corners=[(xx,ya,z(ya)),(xx,yb,z(yb)),(xx,yb,topz),(xx,ya,topz)]
            plate('Bustle_side_ERA_storage',corners,.18,group)
            if H:
                for yy in (ya-.035,yb+.035):
                    for zz in (z(yy)+.045,2.397):bolt('Bustle_panel_countersunk',(xx+s*.011,yy,zz),(s,0,0),group,.010)
                bar('Bustle_mid_height_joint',(xx+s*.008,ya,2.215),(xx+s*.008,yb,2.215),.003,'dark')
        if H:
            bar('Bustle_top_edge',(xx,-.035,2.443),(xx,-2.56,2.443),.011,'rim')
            # Exact order from the left-side reference: star first, then 102 toward the rear.
            b.star(s,xx+s*.014,-.62,2.159,.183,group)
            bpy.ops.object.text_add(location=(xx+s*.017,-1.99 if s>0 else -1.08,1.995))
            obj=bpy.context.object;obj.data.body='102';obj.data.size=.348;obj.data.extrude=.0003
            xxv=Vector((0,s,0));yyv=Vector((0,0,1));obj.rotation_euler=Matrix((xxv,yyv,xxv.cross(yyv))).transposed().to_euler()
            b.select([obj]);bpy.ops.object.convert(target='MESH');b.finish(bpy.context.object,'Bustle_102_number',group,'white')
        # Smoke banks are grouped in a five-tube fan on an inclined exposed plate.
        q=[(s*1.525,.37,1.81),(s*1.525,-.015,1.80),(s*1.385,-.015,2.402),(s*1.385,.37,2.319)]
        if H or L>=2000:
            plate('Smoke_bank_backing',q,.035,group,'rim')
            for j,(y,z) in enumerate([(.27,1.93),(.09,1.98),(.24,2.10),(.04,2.16),(.16,2.285)] if H or L==4000 else [(.27,1.93),(.24,2.10),(.16,2.285)]):
                x=s*(1.535-(z-1.81)*.22)
                aa=Vector((x,y,z));direction=Vector((s*.11,.07,.16));bb=aa+direction
                cyl('Smoke_grenade_launcher',aa,bb,.050,group,'rim',32 if H else 6,bevel=.004)
                if H:
                    dd=direction.normalized()
                    cyl('Smoke_launcher_muzzle_collar',bb-dd*.018,bb+dd*.007,.056,group,'steel',32,bevel=.002)
                    cyl('Smoke_launcher_cap',bb+dd*.007,bb+dd*.012,.041,group,'dark',32,bevel=.001)
                    cyl('Smoke_launcher_center_cap',bb+dd*.012,bb+dd*.014,.028,group,'rim',24,bevel=0)
            if H:
                # Lifting eyes, bent into open loops on the lower side cheek.
                center=Vector((s*1.44,.54,1.92))
                for j in range(16):
                    a=j*2*pi/16;c=(j+1)*2*pi/16
                    bar('Cheek_lifting_eye',center+Vector((0,math.sin(a)*.035,math.cos(a)*.071)),center+Vector((0,math.sin(c)*.035,math.cos(c)*.071)),.012,'steel')
    # Roof perimeter rectangular center deck, segmented seams with actual edge relief.
    box('Roof_main_access_plate',(0,-1.15,2.408),(2.28,2.15,.024),group,'paint',.008)
    box('Bustle_rear_plate',(0,-2.41,2.191),(2.57,.18,.45),group,'paint',.012)
    if H:
        for x in (-1.118,1.118):
            for j in range(14):bolt('Roof_plate_perimeter_bolt',(x,-2.17+j*.148,2.426),(0,0,1),group,.010)
        for y in (-2.201,-.102):
            for j in range(14):bolt('Roof_plate_perimeter_bolt',(-1.08+j*.165,y,2.426),(0,0,1),group,.010)
        for x in (-.29,.29):bar('Roof_center_seam',(x,-2.18,2.425),(x,-.12,2.425),.003,'dark')
        # Hinge straps behind central roof hatches.
        for x in (-.70,.68):
            box('Hatch_hinge_base',(x,-.87,2.439),(.26,.13,.06),group,'paint',.005)
            cyl('Hatch_hinge_pin',(x-.15,-.87,2.473),(x+.15,-.87,2.473),.026,group,'steel',24,bevel=.002)
        for x,y in [(-.91,-1.58),(.87,-1.70),(-.15,-1.30),(.23,-.8)]:
            cyl('Roof_access_plug',(x,y,2.426),(x,y,2.442),.065,group,'rim',32,bevel=.003)
            bolt('Plug_center_lock',(x,y,2.447),(0,0,1),group,.013)
    # Two differentiated, perimeter-periscope cupolas, not plain solid discs.
    for x,y,r in [(-.64,-.40,.41),(.64,-.51,.36)]:
        cyl('Cupola_base',(x,y,2.419),(x,y,2.466),r,group,'steel',72 if H else 10 if L>=2000 else 6,bevel=.004)
        cyl('Cupola_raised_ring',(x,y,2.466),(x,y,2.532),r*.95,group,'paint',72 if H else 10 if L>=2000 else 6,bevel=.004)
        if H or L==4000:
            cyl('Cupola_dark_recess',(x,y,2.532),(x,y,2.539),r*.78,group,'dark',64 if H else 8,bevel=.002)
            cyl('Cupola_hatch_lid',(x,y,2.539),(x,y,2.566),r*.65,group,'paint',64 if H else 8,bevel=.004)
        if H:
            for j in range(8):
                a=j*2*pi/8;xx=x+math.sin(a)*r*.83;yy=y+math.cos(a)*r*.83
                box('Cupola_periscope_housing',(xx,yy,2.557),(.116,.088,.071),group,'rim',.005,rot=(0,0,-a))
                box('Cupola_periscope_prism',(xx,yy,2.597),(.077,.049,.011),group,'glass',.002,rot=(0,0,-a))
            for off in (-.060,.060):bar('Hatch_grab_foot',(x+off,y+.05,2.565),(x+off,y+.05,2.608),.010)
            bar('Hatch_grab_handle',(x-.060,y+.05,2.608),(x+.060,y+.05,2.608),.011)
    # Squat armored sight housings, positioned near the backs of the two sloping cheeks.
    for name,x,y,w in [('Primary_gunner_sight',.64,.405,.38),('Auxiliary_sight',-.64,.415,.34)]:
        box(name+'_pedestal',(x,y,2.383),(w+.055,.30,.052),group,'rim',.006)
        verts=[(x-w/2,y-.15,2.40),(x+w/2,y-.15,2.40),(x+w/2,y+.17,2.40),(x-w/2,y+.17,2.40),
               (x-w/2,y-.12,2.64),(x+w/2,y-.12,2.64),(x+w/2,y+.14,2.64),(x-w/2,y+.14,2.64)]
        mesh(name+'_armor',verts,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],group,'paint',.009)
        if H or L>=2000:
            box(name+'_black_bezel',(x,y+.156,2.525),(w*.83,.025,.176),group,'dark',.006)
            box(name+'_glass_window',(x,y+.172,2.525),(w*.69,.011,.125),group,'glass',.003)
        if H:
            for xx in (x-w*.36,x+w*.36):
                for zz in (2.46,2.60):bolt('Optic_frame_bolt',(xx,y+.177,zz),(0,1,0),group,.007)
            box(name+'_rain_lip',(x,y+.194,2.65),(w+.05,.096,.025),group,'steel',.003)
    # Coaxial front optical aperture, set into the inboard left cheek next to the fabric mantlet.
    if H or L>=2000:
        cyl('Coaxial_armored_sleeve',(-.465,1.61,1.98),(-.465,1.77,1.98),.091,group,'steel',40 if H else 8,bevel=.003)
        cyl('Coaxial_front_glass',(-.465,1.769,1.98),(-.465,1.779,1.98),.062,group,'glass',32 if H else 8,bevel=.001)
    # Rectangular rear storage and grilles are separate from the central crew roof.
    for s in (-1,1):
        box('Roof_flank_stowage',(s*1.14,-1.17,2.485),(.44,.89,.12),group,'paint',.009)
        box('Rear_stowage_box',(s*.99,-2.115,2.55),(.45,.40,.24),group,'paint',.009)
        if H:
            box('Roof_flank_grille_recess',(s*1.14,-1.17,2.549),(.365,.76,.019),group,'dark',.002)
            for j in range(21):box('Roof_flank_grille',(s*1.14,-1.53+j*.035,2.565),(.34,.012,.017),group,'steel',.001)
            for xx in (s*.99-.15,s*.99+.15):
                box('Stowage_box_latch',(xx,-1.907,2.55),(.035,.018,.074),group,'steel',.003)
    # Source plate has a low rectangular rear basket with longitudinal rails.
    if H or L>=2000:
        for z in (2.075,2.42,2.59):
            bar('Rear_basket_crossrail',(-1.20,-2.60,z),(1.20,-2.60,z),.016)
        for x in (-1.2,-.6,0,.6,1.2):
            bar('Rear_basket_upright',(x,-2.60,2.075),(x,-2.60,2.59),.014)
        if H:
            for x in (-1.20,1.20):
                for z in (2.075,2.59):bar('Rear_basket_standoff',(x,-2.26,z),(x,-2.6,z),.016)
            for j in range(17):bar('Rear_basket_floor_wire',(-1.16+j*.145,-2.3,2.08),(-1.16+j*.145,-2.6,2.08),.006)
    else:
        for z in (2.075,2.59):cyl('Basket_silhouette_rail',(-1.2,-2.6,z),(1.2,-2.6,z),.016,group,'steel',3,bevel=0)
        for x in (-1.2,1.2):cyl('Basket_silhouette_post',(x,-2.6,2.075),(x,-2.6,2.59),.016,group,'steel',3,bevel=0)
    # Low articulated machine-gun station, black receiver + green ammunition and sight housings.
    x=-.64;y=-.4
    cyl('RWS_rotation_ring',(x,y,2.565),(x,y,2.64),.245,group,'steel',64 if H else 8,bevel=.004)
    box('RWS_lower_saddle',(x,y,2.701),(.22,.23,.15),group,'paint',.008)
    for s in (-1,1):box('RWS_yoke',(x+s*.135,y+.015,2.803),(.044,.18,.26),group,'steel',.004)
    cyl('RWS_elevation_pin',(x-.183,y+.015,2.859),(x+.183,y+.015,2.859),.050,group,'steel',32 if H else 6,bevel=.002)
    box('RWS_receiver',(x,y+.13,2.916),(.165,.41,.145),group,'dark',.006)
    cyl('RWS_barrel_cooling_sleeve',(x,y+.33,2.92),(x,y+.50,2.92),.045,group,'steel',40 if H else 6,bevel=.003)
    cyl('RWS_gun_barrel',(x,y+.50,2.92),(x,y+1.25,2.92),.022,group,'steel',32 if H else 6,bevel=.002)
    cyl('RWS_muzzle_device',(x,y+1.24,2.92),(x,y+1.31,2.92),.028,group,'steel',32 if H else 6,bevel=.002)
    box('RWS_ammunition_box',(x-.24,y+.04,2.92),(.23,.30,.30),group,'paint',.006)
    box('RWS_optical_unit',(x+.16,y-.015,3.112),(.14,.18,.16),group,'paint',.009)
    if H or L==4000:
        box('RWS_optical_bezel',(x+.16,y+.083,3.112),(.106,.015,.126),group,'dark',.003)
        for z in (3.075,3.144):cyl('RWS_optical_lens',(x+.16,y+.09,z),(x+.16,y+.096,z),.032,group,'glass',24 if H else 6,bevel=0)
    if H:
        for yy in (y+.42,y+.95):
            bar('Machine_gun_sight_post',(x,yy,2.937),(x,yy,3.007),.007)
            bar('Machine_gun_sight_crossbar',(x-.024,yy,3.007),(x+.024,yy,3.007),.006)
        for j in range(7):
            box('Receiver_cooling_slot',(x-.086,y+.015+j*.042,2.937),(.008,.022,.039),group,'steel',.001)
        for xx in (x-.319,x-.171):
            for yy in (y-.07,y+.145):bolt('Ammo_box_fastener',(xx,yy,3.081),(0,0,1),group,.008)
        box('RWS_ammo_lid',(x-.24,y+.04,3.079),(.252,.32,.024),group,'rim',.004)
        bar('Ammo_box_handle',(x-.32,y+.04,3.123),(x-.16,y+.04,3.123),.009)
        for xx in (x-.32,x-.16):bar('Ammo_handle_foot',(xx,y+.04,3.09),(xx,y+.04,3.123),.009)
        for j in range(6):cyl('RWS_feed_belt',(x-.165+j*.026,y+.19,2.996),(x-.165+j*.026,y+.25,2.996),.013,group,'steel',10,bevel=0)
    # Reference uses one tall rear-right antenna and one beside the RWS.
    for x,y,height in [(-.94,-.75,4.13),(1.04,-1.95,4.24)]:
        cyl('Antenna_pedestal',(x,y,2.48),(x,y,2.64),.062,group,'paint',32 if H else 4,bevel=.003)
        cyl('Antenna_spring',(x,y,2.64),(x,y,2.81),.030,group,'steel',24 if H else 4,bevel=.002)
        cyl('Antenna_whip',(x,y,2.81),(x,y,height),.008,group,'steel',12 if H else 3,r2=.002,bevel=0)
        if H:
            for j in range(8):cyl('Antenna_spring_turn',(x,y,2.65+j*.019),(x,y,2.65+j*.019+.006),.037,group,'rim',24,bevel=0)
