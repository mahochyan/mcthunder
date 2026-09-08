"""Generate the reviewable 020 data/evidence index from the actual playable packages."""
import json
from pathlib import Path

root=Path(__file__).resolve().parents[1]
packets=[json.loads(p.read_text(encoding='utf-8')) for p in sorted((root/'configs/vehicles/historical').glob('*.json'))]
out=['# 020 历史车型与证据索引','',
     '本表从实际可玩内容包生成。verified表示引用支持该字段，既可能是一手也可能是明确标出的二手；它不表示整车几何、装填、穿深或整场表现均为历史实测。几何和内部体积为原创估算重建。完整字段值、适用配置、页码与文件SHA256均在各JSON包及游戏内资料档案中。','',
     '| 配置 | 炮 / 炮架 | 弹种 | 乘员 | 携弹 | 道路速度 km/h | 宽度 m | 参考车长 m |',
     '|---|---|---|---:|---:|---:|---:|---:|']
for p in packets:
    a=p['assembly']; f=p['facts']
    out.append(f"| {p['display_name']} | {a['gun']} / {a['mount']} | {a['shell']} | {len(p['crew'])} | {p['runtime']['rounds']} | {p['runtime']['forward_max_speed']*3.6:.2f} | {f['dimensions.width_m']['value']:.4f} | {f['dimensions.reference_length_m']['value']:.4f} |")
out+=['','M4/M36采用VVSS，M24/M26采用扭杆结构。M24选五人选项，手册允许的四人战斗编制用同一配置管线验证。M36为1945年汽油发动机、M4A1炮架、敞顶版本，仍是全回转炮塔。受限射界是独立工程反例，不给这些历史车虚构固定炮。','',
      'M36下前装甲：所选1945军械局表为2.5—4英寸，二手AFV表为2—4.25英寸；本包按选定版本使用63.5—101.6 mm，不平均或静默合并。范围的局部分布未知，当前局部63.5 mm明确estimated。M4下前部同理采用范围内的50.8 mm局部估算。M36炮塔后部配重厚度分布未测绘，当前44.45 mm局部面是估算，不能把范围上界铺满。','',
      'M24的M61带历史引信；020仅接入动能路径，游戏车库明确提示尚未实现内部爆发，021实现相应规则。M26/M36的M77兼容性来自M3炮的明确弹药表，使用TM9-745炮弹证据不等于采用M36B2车体装甲。M26制退器外形参考军械目录PDF第34页（印刷第25页，15 May 1945）。下载文件名含1944，但其中存在1945修订页；使用的是具体页的日期。','']
for p in packets:
    out += ['## '+p['display_name'],'',f"实际包：[JSON](../../configs/vehicles/historical/{p['id']}.json)；可编辑模型：[Blender](../../authoring/vehicles/{p['id']}.blend)。",'',
            '| 字段 | 当前值 | 状态 / 来源性质 | 页码或位置 |','|---|---|---|---|']
    for key,f in p['facts'].items():
        value=json.dumps(f['value'],ensure_ascii=False,separators=(',',':'))
        if len(value)>150: value='详见实际JSON中的完整结构；非省略内容的默认值'
        cells=[key,value,f['status']+' / '+f['origin'],f.get('location','')]
        out.append('| '+' | '.join(str(c).replace('|','/').replace('\n',' ') for c in cells)+' |')
    out += ['','来源登记：','']
    for key,s in p['sources'].items():
        if s['origin']=='game_rule': continue
        out += [f"- [{key}]({s['url']})：{s['origin']} / {s['read_state']}；SHA256 `{s['sha256']}`。"]
    out += ['']
out += ['## 使用与限制','',
        '车库正常下拉选车后可以检视外观/装甲/内构、打开证据档案、驾驶并射击；选中车型进入4对4时，双方镜像编成实际四种车，阵亡后保留所选车型。专项工程课目及1对1工程夹具仍用于旧规则回归。','',
        '装甲表、模块体积、炮盾和轴心经同一装配管线核验。Blender导出检查逐片匹配装甲三角形和顶点，允许Godot导入压缩的0.1毫米偏差。动态外饰、格栅、轮盘等不增加装甲或损伤盒；履带由真实速度驱动的共享装饰动画表示。','',
        '未知字段不补数字冒充数据；无效来源/改型/炮架/弹种/人数、非整数弹药、超出文献范围的局部厚度等会拒绝装配。高保真弧面、精确乘员姿态、历史穿深验证与实测悬挂行为尚未完成。人工作战验收NOT_RUN。','']
target=root/'docs/vehicles/HISTORICAL_020.md'
target.write_text('\n'.join(out),encoding='utf-8')
print(target)
