"""Reproduce 021 shell evidence packet. Only game-relevant historical fields are transcribed."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sources = {
    'tm1901': dict(url='https://archive.org/download/Tm9-1901/Tm9-1901.pdf', sha256='238cd4b2e34d75d3b2ca5a93772894787322b57dd01b1062ad3c8bb29524eef3', title='TM 9-1901 Artillery Ammunition, 29 June 1944', location='printed 101-103 / PDF 105-107'),
    'soic3': dict(url='https://www.ibiblio.org/hyperwar/NHC/NewPDFs/USArmy/US%20military%20Technical%20and%20Field%20manuals/Standard.Ordnance.Items.Catalog.Vol.3.1944.pdf',sha256='f928cec1bd9bcb1a22595a9f635bd1e2a4001e25b42ff4c09d857aaca829670d',title='Catalogue of Standard Ordnance Items Vol.3, 1944',location='PDF 71,88: gun-specific performance tables'),
    'm24tm': dict(url='https://www.military-references.com/wp-content/uploads/books/tanks/usa/m24_chaffee/M24_Chaffee_Light_Tank_Technical_Manual_TM9-729_1951.pdf',sha256='4e099cff1f8ee3d0f07cb07e3980955e88aece4894cbf0c2daed1c3e960d668f',title='TM 9-729 Light Tank M24, May 1951',location='printed 345 Figure 197 / PDF 353; printed 360 Table V / PDF 368'),
    'm36tm': dict(url='https://ia800805.us.archive.org/33/items/TM9-745/TM9-745.pdf',sha256='55eda0c283a9fbdc380ba8f932b9b059481d4734a896bcd3007811bc49453914',title='TM 9-745 M36B2, 1945 (gun ammunition compatibility only)',location='printed 500 / PDF 508: authorized M3 rounds'),
    'oco90': dict(url='https://ww2.lonesentry.com/manuals/90-mm-ammunition/index.html',sha256='1f7a9503a81535a821f74f72ee03141804da87f18460bd7c106d4aeb06ae08bb',title='OCO Armor-Piercing Ammunition for Gun, 90-mm, M3, January 1945, primary pamphlet transcription',location='M82 2800 fps section; names T26E3 and M36'),
    'oco90graph': dict(url='https://ww2.lonesentry.com/manuals/90-mm-ammunition/armor-penetration-vs-range-table.jpg',sha256='4a23fff3926765f83ae588380c77a399adc8440351d22aa9500ed9f8c672e1fe',title='OCO January 1945 M82 penetration versus range, printed graph',location='20/30 degree homogeneous plate graph (visual reading is approximate)'),
}
for key, src in sources.items():
    src['origin'] = 'historical_primary'
    src['read_state'] = 'text_read' if key == 'oco90' else 'image_and_text_read'

shells = {}
def shell(key, label, gun, caliber, effect, velocity, curve, refs, observations, note):
    shells[key] = dict(label=label, gun=gun, caliber_mm=caliber, effect_policy=effect,
        muzzle_velocity_mps=velocity, penetration_curve=curve, source_refs=refs,
        compatibility_status='verified', muzzle_velocity_status='verified', curve_status='estimated',
        effect_status='game_rule', historical_observations=observations, estimate_reason=note)

shell('m72_m3','M72 AP-T','75-mm M3',75,'kinetic',618.744,[[0,100],[457.2,89],[914.4,78.74],[1828.8,58],[2500,42]],['tm1901'],
      'M3: 2030 ft/s; 3.1 in homogeneous and 2.6 in face-hardened plate at 1000 yd, 0 degrees (printed 103).',
      '914.4m homogeneous anchor transcribed. Other ranges interpolate/extrapolate game estimates. No material-specific projectile failure model.')
shell('m61_m3','M61 APC-T / APHE','75-mm M3',75,'internal_burst',618.744,[[0,90],[457.2,81],[914.4,71.12],[1828.8,53],[2500,39]],['tm1901','soic3'],
      'TM printed 101 data applies to M61 through printed 102 para.89: M3 2030 ft/s, 2.8 in homogeneous at 1000 yd, 0 degrees.',
      '914.4m homogeneous anchor transcribed. Other ranges are game estimates. SOIC gives 2024 ft/s and angled table; retained as differing source, not silently combined. Inside burst is a toy game effect.')
shell('m72_m6','M72 AP-T (sight chart)','75-mm M6',75,'kinetic',618.744,[[0,100],[457.2,89],[914.4,78.74],[1828.8,58],[2500,42]],['m24tm','tm1901'],
      'TM9-729 printed 345 Fig.197A ADC75-H-2 explicitly includes M6 on M24 and an M72 column. Table V printed 360 does not list M72.',
      'Technical compatibility from the M6 sight chart; 1951 field issue is unknown. M3 M72 velocity/penetration used as estimated M6 simulation transfer, not claimed as M6 test results.')
shells['m72_m6']['muzzle_velocity_status']='estimated'
shells['m72_m6']['issue_status']='unknown'
shell('m61_m6','M61 APC-T / APHE','75-mm M6',75,'internal_burst',618.744,[[0,90],[457.2,81],[914.4,71.12],[1828.8,53],[2500,39]],['m24tm','tm1901'],
      'TM9-729 printed 360 Table V authorizes fuzed M61; printed 345 Fig.197B/C explicitly gives M61/M61A1 2030 ft/s for M6.',
      'Gun-specific compatibility and velocity verified. Penetration transfers the M3 M61 game curve as an estimate; no M6-specific terminal test curve found. Inside burst is a toy effect.')
shell('m77_m3','M77 AP-T','90-mm M3',90,'kinetic',822.96,[[0,175],[457.2,151.37],[914.4,129.75],[1828.8,99],[2500,80]],['soic3','m36tm'],
      'SOIC PDF88 M3 column: 2700 ft/s, homogeneous 5.6 in at 500 yd and 4.8 in at 1000 yd at 20 degrees.',
      'Angled thickness divided by cos(20 degrees) to calibrate the simple LOS game resolver; this is a game normalization, not a verified normal-impact test. Other ranges extrapolated.')
shell('m82_m3_2800','M82 APC-T 2800 / APHE','90-mm M3',90,'internal_burst',853.44,[[0,160],[457.2,150],[914.4,140],[1828.8,119],[2500,105]],['m36tm','oco90','oco90graph'],
      'January 1945 OCO pamphlet explicitly names M82 2800 ft/s for M3 on T26E3 and M36. Its own 20/30 degree homogeneous curve is the visual calibration source.',
      'Graph read approximately, then mapped into the simple LOS game rule. Deliberately not the older 2670 ft/s SOIC M82 curve. No AP multiplication. Inside burst is a toy effect.')

vehicles = {
 'us_m4a3_75w_vvss_1944':dict(gun='75-mm M3',shells=['m72_m3','m61_m3'],default='m72_m3'),
 'us_m24_m6_t85e1_1951':dict(gun='75-mm M6',shells=['m72_m6','m61_m6'],default='m61_m6'),
 'us_m26_m3_1945':dict(gun='90-mm M3',shells=['m77_m3','m82_m3_2800'],default='m77_m3'),
 'us_m36_m4a1_1945':dict(gun='90-mm M3',shells=['m77_m3','m82_m3_2800'],default='m77_m3'),
}
out=ROOT/'configs/shells/historical_loadouts.json'
out.parent.mkdir(parents=True,exist_ok=True)
out.write_text(json.dumps(dict(schema_version=1,sources=sources,shells=shells,vehicles=vehicles),ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(out)
