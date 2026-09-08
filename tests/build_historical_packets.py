"""Reproducible transcription of read sources; never upgrades estimated geometry to verified data.
Raw reference scans stay outside the game. Run with --sources E:/AIprogram/research-sources/020.
"""
import argparse, hashlib, json
from pathlib import Path

p = argparse.ArgumentParser()
p.add_argument('--sources', type=Path, required=True)
args = p.parse_args()
root = Path(__file__).resolve().parents[1]
target = root / 'configs/vehicles/historical'
target.mkdir(parents=True, exist_ok=True)
source_specs = {
 'm4table':('AFV_M4_Sherman.html','https://afvdatabase.com/usa/m4sherman.html','historical_secondary','text_read'),
 'm24table':('AFV_M24.html','https://afvdatabase.com/usa/m24chaffee.html','historical_secondary','text_read'),
 'm26table':('AFV_M26.html','https://afvdatabase.com/usa/m26pershing.html','historical_secondary','text_read'),
 'm36table':('AFV_M36.html','https://afvdatabase.com/usa/90mmgmcm36.html','historical_secondary','text_read'),
 'oco1945':('OCO_Mobile_Artillery_1945_transcript.html','https://www.lonesentry.com/manuals/mobile-artillery/index.html','historical_primary','text_read'),
 'm24tm':('TM9-729_1951.pdf','https://www.military-references.com/wp-content/uploads/books/tanks/usa/m24_chaffee/M24_Chaffee_Light_Tank_Technical_Manual_TM9-729_1951.pdf','historical_primary','image_and_text_read'),
 'm26tm':('TM9-735_1948.pdf','https://www.military-references.com/wp-content/uploads/books/tanks/usa/m26/M26_and_M45_Tank_medium_TM_9-735_1948.pdf','historical_primary','image_and_text_read'),
 'm36ammo':('TM9-745_1945.pdf','https://ia800805.us.archive.org/33/items/TM9-745/TM9-745.pdf','historical_primary','image_and_text_read'),
 'soic1944':('SOIC_Vol1_1944.pdf','https://www.ibiblio.org/hyperwar/NHC/NewPDFs/USArmy/US%20military%20Technical%20and%20Field%20manuals/Standard.Ordnance.Items.Catalog.Vol.1.1944.pdf','historical_primary','image_and_text_read'),
}
sources = {}
for key,(file,url,origin,state) in source_specs.items():
 sources[key] = dict(file=file,url=url,origin=origin,read_state=state,sha256=hashlib.sha256((args.sources/file).read_bytes()).hexdigest())

roles = ['commander','gunner','loader','driver','assistant_driver_bow_gunner']
zones = ['hull_front_upper','hull_front_lower','hull_sides_front','hull_sides_rear','hull_sides_lower','hull_rear_upper','hull_rear_lower','hull_roof_front','hull_roof_rear','hull_floor_front','hull_floor_rear','turret_front','turret_sides','turret_rear','turret_roof','gun_shield']
specs = [
 dict(id='us_m4a3_75w_vvss_1944',name='M4A3(75)W / 1944 / VVSS',variant='M4A3(75)W',year=1944,suspension='VVSS',gun='75-mm M3',mount='M34A1',shell='M72 AP-T',caliber=75,table='m4table',loc='M4A3(75)W: General, Dimensions, Armament, Armor, Suspension, Performance',width=2.667,length=6.2738,speed=11.62304,reverse=3.0,accel=2.2,reload=6.5,rounds=104,pitch=25,
 armor=[63.5,[50.8,107.95],38.1,38.1,38.1,38.1,38.1,19.05,19.05,25.4,12.7,76.2,50.8,50.8,25.4,88.9],
 g=dict(hull_rings=[[0.44,0.91,-2.57,2.8],[0.92,0.97,-2.91,3.1],[1.91,0.97,-1.85,2.9]],turret_origin=[0,1.91,-0.42],gun_origin=[0,0.37,-0.9],turret_outline=[[-0.7,-0.94],[0.7,-0.94],[1.02,-0.38],[1.03,0.80],[0.65,1.23],[-0.65,1.23],[-1.03,0.80],[-1.02,-0.38]],turret_bottom=0.02,turret_top=0.72,turret_taper=0.87,ring_half=0.72,open_top=False,mantlet_half_width=0.60,mantlet_half_height=0.29,barrel_length=1.65,wheel_count=6,track_width=0.42,wheel_radius=0.36),engine='Ford GAA',trans_rear=False,left_gunner=False),
 dict(id='us_m24_m6_t85e1_1951',name='M24 / M6 / T85E1 / 1951',variant='M24',year=1951,suspension='Torsion bar / T85E1',gun='75-mm M6',mount='M64',shell='M61 APC-T',caliber=75,table='m24table',loc='M24: General, Armament and Armor; dimensions/identity below use TM9-729 (1951)',width=2.9464,length=5.0292,speed=15.19936,reverse=5.0,accel=3.3,reload=6.0,rounds=48,pitch=15,
 armor=[25.4,25.4,25.4,19.05,25.4,19.05,19.05,12.7,12.7,12.7,9.525,38.1,25.4,25.4,12.7,38.1],
 g=dict(hull_rings=[[0.45,0.99,-1.98,2.22],[0.85,1.08,-2.43,2.48],[1.55,0.97,-1.22,2.30]],turret_origin=[0,1.55,-0.26],gun_origin=[0,0.33,-0.9],turret_outline=[[-0.61,-0.91],[0.61,-0.91],[0.94,-0.32],[0.94,0.65],[0.59,1.05],[-0.59,1.05],[-0.94,0.65],[-0.94,-0.32]],turret_bottom=0.02,turret_top=0.70,turret_taper=0.78,ring_half=0.64,open_top=False,mantlet_half_width=0.52,mantlet_half_height=0.30,barrel_length=1.7,wheel_count=5,track_width=0.38,wheel_radius=0.40),engine='Two Cadillac 44T24 engines (aggregate damage volume)',trans_rear=False,left_gunner=True),
 dict(id='us_m26_m3_1945',name='M26 (T26E3) / M3 / 1945',variant='M26 (T26E3)',year=1945,suspension='Torsion bar',gun='90-mm M3',mount='M67',shell='M77 AP-T',caliber=90,table='m26table',loc='M26: General, Dimensions, Armament, Armor and Suspension; excludes T26E4',width=3.51282,length=6.32714,speed=8.9408,reverse=4.0,accel=1.55,reload=8.5,rounds=70,pitch=20,
 armor=[101.6,76.2,76.2,50.8,76.2,50.8,19.05,22.225,22.225,25.4,12.7,101.6,76.2,76.2,25.4,114.3],
 g=dict(hull_rings=[[0.44,1.20,-2.72,2.63],[0.93,1.26,-3.13,3.02],[1.68,1.26,-2.36,2.87]],turret_origin=[0,1.68,-0.42],gun_origin=[0,0.44,-1.12],turret_outline=[[-0.82,-1.14],[0.82,-1.14],[1.15,-0.45],[1.15,0.90],[0.7,1.33],[-0.7,1.33],[-1.15,0.90],[-1.15,-0.45]],turret_bottom=0.02,turret_top=0.79,turret_taper=0.9,ring_half=0.72,open_top=False,mantlet_half_width=0.72,mantlet_half_height=0.33,barrel_length=2.75,wheel_count=6,track_width=0.58,wheel_radius=0.40),engine='Ford GAF',trans_rear=True,left_gunner=False),
 dict(id='us_m36_m4a1_1945',name='M36 / M4A1 mount / 1945',variant='M36',year=1945,suspension='VVSS',gun='90-mm M3',mount='M4A1',shell='M77 AP-T',caliber=90,table='m36table',loc='M36: General, Armor and Suspension; excludes M36B1/M36B2 and optional roof kit',width=3.048,length=6.1468,speed=11.62304,reverse=3.0,accel=2.45,reload=8.0,rounds=47,pitch=20,
 armor=[38.1,[63.5,101.6],19.05,19.05,25.4,19.05,25.4,19.05,9.525,12.7,12.7,76.2,31.75,[44.45,127],None,76.2],
 g=dict(hull_rings=[[0.44,0.95,-2.52,2.62],[0.88,1.12,-2.93,3.10],[1.80,0.93,-1.64,2.79]],turret_origin=[0,1.80,-0.18],gun_origin=[0,0.42,-1.0],turret_outline=[[-0.76,-1.02],[0.76,-1.02],[1.12,-0.35],[1.12,1.15],[0.70,1.74],[-0.70,1.74],[-1.12,1.15],[-1.12,-0.35]],turret_bottom=0.02,turret_top=0.86,turret_taper=0.93,ring_half=0.72,open_top=True,mantlet_half_width=0.66,mantlet_half_height=0.36,barrel_length=2.82,wheel_count=6,track_width=0.42,wheel_radius=0.36),engine='Ford GAA',trans_rear=False,left_gunner=False),
]

for d in specs:
 facts={}; used=set()
 def fact(key,value,source,location=None,status='verified',note=''):
  used.add(source)
  facts[key]=dict(value=value,status=status,origin=sources[source]['origin'] if source in sources else 'game_rule',source_refs=[source],location=location or d['loc'])
  if note: facts[key]['note']=note
 def game(key,value,note): fact(key,value,'implementation','docs/IMPLEMENTATION_020.md','estimated',note)
 tab=d['table']
 for key,val in [('variant',d['variant']),('year',d['year']),('suspension',d['suspension'])]: fact('identity.'+key,val,tab)
 for key,val in [('gun',d['gun']),('mount',d['mount']),('caliber_mm',d['caliber'])]: fact('weapon.'+key,val,tab)
 fact('crew.roles',roles,tab); fact('crew.placement','See documented named positions; centers and volumes reconstructed separately.',tab)
 fact('dimensions.width_m',d['width'],tab); fact('dimensions.reference_length_m',d['length'],tab)
 fact('weapon.capacity',d['rounds'],tab)
 fact('mobility.forward_speed_mps',d['speed'],tab,note='Maximum sustained/level-road speed under source conditions, not a universal terrain speed.')
 if d['id'].startswith('us_m24'):
  for key,val in [('identity.variant',d['variant']),('identity.year',1951),('identity.suspension',d['suspension']),('crew.roles',roles),('dimensions.width_m',d['width']),('dimensions.reference_length_m',d['length']),('mobility.forward_speed_mps',d['speed'])]:
   fact(key,val,'m24tm','TM9-729 (1951), pp.1-6: edition changes, four/five-man crew option, data table; PDF pp.9-14',note='Five-man option selected; assistant driver remains in hull. Width 9ft8in and length 16ft6in from this edition, not AFV table.')
  fact('weapon.ammunition',d['shell'],'m24tm','TM9-729 (1951), p.360 ammunition table (PDF p.368)',note='Fuzed M61 APC-T; 020 simulates kinetic path only. Internal burst is not yet implemented and is visibly labelled.')
 elif d['caliber']==90:
  fact('weapon.ammunition',d['shell'],'m36ammo','TM9-745 (1945), p.500 (PDF p.508), AP-T M77: guns 90-mm M1/M2/M3/T8',note='Applicability is specifically the same 90-mm M3 gun; vehicle hull and suspension data are not transferred from M36B2.')
  if d['variant']=='M36':
   for key,val in [('identity.variant','M36'),('identity.year',1945),('identity.suspension','VVSS'),('weapon.gun',d['gun']),('weapon.mount','M4A1'),('weapon.caliber_mm',90),('crew.roles',roles),('dimensions.width_m',d['width']),('dimensions.reference_length_m',d['length']),('weapon.capacity',47),('mobility.forward_speed_mps',d['speed'])]:
    fact(key,val,'oco1945','Mobile Artillery (May 1945), pp.9-11 M36 description/characteristics',note='Contemporary transcription; scan not obtained. Width and length follow this edition. M36B2 extra shield is excluded.')
  else:
   fact('identity.year',1945,'oco1945','Mobile Artillery (May 1945), pp.5-7 M26 (T26E3)')
   fact('mobility.forward_speed_mps',d['speed'],'oco1945','Mobile Artillery (May 1945), p.7',note='20 mph chosen from 1945 table; 1948 transmission gearing permits higher speeds and is not used as this sustained limit.')
 else: fact('weapon.ammunition',d['shell'],'soic1944','Standard Ordnance Items Catalog Vol.1 (1944), 75-mm gun tank ammunition table: AP M72',note='Gun/ammunition compatibility only; unrelated hull variants are not used as M4A3(75)W armor evidence.')
 armor={}
 for zone,val in zip(zones,d['armor']):
  key='armor.'+zone
  source=tab; location=None
  if d['variant']=='M36' and zone not in ['turret_rear','turret_roof']:
   source='oco1945'; location='Mobile Artillery (May 1945), p.11, Actual armor column (not Basis)'
  fact(key,val,source,location,status='unknown' if val is None else 'verified',note='No roof across open fighting compartment; optional armor kit is not fitted.' if val is None else '')
  armor[zone]={'fact':key,'material':'cast' if zone.startswith('turret') or zone=='gun_shield' else 'rolled'}
  if isinstance(val,list):
   armor[zone].update(local_mm=val[0],estimate_reason='Documented thickness range, but local distribution has not been measured. Lowest documented thickness is a conservative local reconstruction, not a verified uniform plate.')
 # lower sides are split fore/aft as well (M26 and M24 taper to different rear compartment thickness).
 armor['hull_sides_lower_rear']=dict(armor['hull_sides_rear'] if d['variant'] in ['M24','M26 (T26E3)'] else armor['hull_sides_lower'])
 if d['variant']=='M36':
  game('geometry.front_collar_thickness',31.75,'M36 table front refers to gun shield. Faceted side-to-shield collar uses side thickness as an explicitly estimated reconstruction; no claim of verified local front casting thickness.')
  armor['turret_front']={'fact':'geometry.front_collar_thickness','material':'cast'}
 g=d['g']
 if d['variant']=='M26 (T26E3)':
  g['barrel_length']=3.91
  g['muzzle_brake']=True
  fact('appearance.muzzle_brake',True,'soic1944','Standard Ordnance Items Catalog, M26, printed p.25 (PDF p.34), 15 May 1945: caption and gun description',note='Visible muzzle brake confirmed in primary photograph. Detailed brake dimensions are artistic estimates.')
 # Original cast-turret corner reconstruction; front opening edge is retained.
 if d['variant'] in ['M4A3(75)W','M26 (T26E3)']:
  outline=g['turret_outline']; curved=outline[:2]
  for i in range(2,len(outline)):
   for neighbor in [outline[i-1],outline[(i+1)%len(outline)]]:
    curved.append([outline[i][j]*0.66+neighbor[j]*0.34 for j in range(2)])
  g['turret_outline']=curved
  g['turret_taper']=0.81 if d['variant']=='M4A3(75)W' else 0.86
 if d['variant']=='M36': g['barrel_length']=3.24
 if d['variant']=='M4A3(75)W':
  fact('armor.rotor_shield',50.8,tab,'M4A3(75)W: Armor, rotor shield 2.0 inches')
  armor['rotor_shield']={'fact':'armor.rotor_shield','material':'cast'}
  g['separate_rotor_shield']=True
 height=g['hull_rings'][2][0]; rear=g['hull_rings'][1][3]
 modules=[]
 def module(id,kind,part,pos,size,external=False): modules.append(dict(id=id,kind=kind,part=part,position=pos,size=size,external=external))
 engine_z=1.40 if d['trans_rear'] else 1.9 if d['variant']!='M24' else 1.47
 engine_size=[1.25,0.64,0.95] if d['variant']!='M24' else [1.30,0.54,0.85]
 module('engine','engine','hull',[0,height-0.48,engine_z],engine_size)
 module('transmission','transmission','hull',[0,0.81,rear-0.38 if d['trans_rear'] else -2.00 if d['variant']!='M24' else -1.79],[1.25,0.40,0.5])
 module('fuel','fuel','hull',[-0.77,height-0.40,engine_z],[0.22,0.45,0.70])
 module('ammo_floor_left','ammo','hull',[-0.54,0.64,0.35],[0.43,0.25,0.75])
 module('ammo_floor_right','ammo','hull',[0.54,0.64,0.35],[0.43,0.25,0.75])
 ready={'M36':11,'M26 (T26E3)':10,'M4A3(75)W':4}.get(d['variant'],0)
 if ready:
  module('ammo_ready','ammo','turret',[0,0.30,1.33] if d['variant']=='M36' else [0,0.08,0.7],[0.80,0.32,0.38] if d['variant']=='M36' else [0.50,0.12,0.35])
 for m in modules:
  if m['kind']=='ammo': m['ammo_capacity']=ready if m['id']=='ammo_ready' else (d['rounds']-ready)//2
 modules.sort(key=lambda m: 0 if m['id']=='ammo_ready' else 1)
 fact('weapon.stowage_counts',{'floor_total':d['rounds']-ready,'ready':ready},tab,note='Floor locations aggregated into two estimated boxes. Ready-rack count follows vehicle table; first loaded round is deducted from first rack, not created in addition.')
 module('breech','breech','barrel',[0,0,0.32],[0.39,0.30,0.54])
 module('turret_drive','turret_drive','hull',[0,height-0.16,g['turret_origin'][2]],[0.38,0.12,0.4])
 for side in [-1,1]: module('track_left' if side<0 else 'track_right','track','hull',[side*(d['width']/2-g['track_width']/2),0.51,0.1],[g['track_width'],1.02,d['length']-0.45],True)
 crew=[]
 side=-1 if d['left_gunner'] else 1
 for id,role,part,pos in [('driver','driver','hull',[-0.5,height-0.40,-1.17]),('assistant_driver','assistant_driver_bow_gunner','hull',[0.5,height-0.40,-1.17]),('gunner','gunner','turret',[side*0.53,0.32,-0.43]),('commander','commander','turret',[side*0.55,0.39,0.51]),('loader','loader','turret',[-side*0.54,0.34,0.38])]:
  crew.append(dict(id=id,role=role,part=part,position=pos,size=[0.27,0.40,0.34]))
 game('geometry.exterior',g,'Original faceted reconstruction from silhouettes and dimensions. Local curvature, small fittings, track behavior and aperture dimensions are estimated.')
 game('geometry.modules',modules,'Aggregate component boxes approximate occupied volumes; M24 twin engines share one power-unit damage volume. Fuel/ammunition subdivision is approximate; secondary damage uses common game rules.')
 game('geometry.crew',crew,'Role side/location follows cited table; body centers, seated volumes and pose are estimates.')
 runtime=dict(forward_max_speed=d['speed'],reverse_max_speed=d['reverse'],acceleration=d['accel'],hull_turn_speed=36 if d['caliber']==90 else 44,reload_time=d['reload'],rounds=d['rounds'],pitch_min=-10,pitch_max=d['pitch'],muzzle_velocity=850 if d['caliber']==90 else 619,penetration_curve=[[0,150 if d['caliber']==90 else 85],[500,125 if d['caliber']==90 else 69],[1500,95 if d['caliber']==90 else 48]],turret_yaw_speed=24,turret_pitch_speed=10)
 game('runtime.simulation',runtime,'Reload, acceleration, reverse limit, steering, traverse, muzzle speed and penetration curve are current game rules, not verified historical measurements. Forward speed and capacity are separately sourced; slope-dependent performance and suspension dynamics are simplified.')
 fact('identity.power_unit',d['engine'],tab,status='estimated' if d['variant']=='M24' else 'verified')
 packet=dict(schema_version=1,id=d['id'],display_name=d['name'],facts=facts,sources={},assembly=dict(variant=d['variant'],year=d['year'],suspension=d['suspension'],gun=d['gun'],mount=d['mount'],caliber_mm=d['caliber'],shell=d['shell']),compatible_shells=[d['shell']],geometry=g,runtime=runtime,armor=armor,modules=modules,crew=crew,license='Original procedural geometry and code, created for this repository. No third-party model or texture is redistributed.',limitations=['Armor geometry and interior volumes are estimates; inspect field evidence.','Kinetic projectile and damage approximation; no historical penetration validation.']+(['M61 has a historical fuze; only kinetic effect is implemented until 021.'] if d['variant']=='M24' else []))
 for key in used:
  packet['sources'][key]=dict(sources[key],applies_to_identity_ids=[d['id']]) if key in sources else dict(origin='game_rule',url='res://docs/IMPLEMENTATION_020.md',read_state='text_read',applies_to_identity_ids=[d['id']])
 (target/(d['id']+'.json')).write_text(json.dumps(packet,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
 print(d['id'],len(facts),'field records')
