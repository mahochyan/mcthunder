"""Binding placeholders in player-facing templates, stored in the text bank."""
import json
import re
from localization_inventory import ROOT

path = ROOT / 'assets/localization/zh_CN.json'
bank = json.loads(path.read_text(encoding='utf-8'))
for key, value in list(bank.items()):
    if '{key:' in value:
        continue
    # Named controls in instructions, never vehicle names or evidence metadata.
    substitutions = {'W/S':'{key:move_forward}/{key:move_back}', 'A/D':'{key:turn_left}/{key:turn_right}',
      '开火键':'{key:fire}', '炮镜键':'{key:aim}', '重开键':'{key:reset}', '接管键':'{key:switch_control}',
      '透视键':'{key:xray}', '维修键':'{key:repair}', '灭火键':'{key:extinguish}', '替补键':'{key:replace_crew}',
      '取消键':'{key:cancel_recovery}', '回放键':'{key:replay_toggle}', '单步键':'{key:replay_step}',
      '导出键':'{key:replay_export}', '切换射道键':'{key:toggle_target}',
      '历史切换键':'{key:replay_previous}/{key:replay_next}'}
    for original, replacement in substitutions.items():
        value = value.replace(original,replacement)
    if any(word in value for word in ['驾驶','瞄准','开炮','开火','射击','炮镜']):
        value = value.replace('右键','{key:aim}').replace('左键','{key:fire}')
    for letter, action in [('T','repair'),('F','extinguish'),('C','replace_crew'),('G','cancel_recovery'),
                           ('R','reset'),('V','replay_toggle'),('N','replay_step'),('J','replay_export'),('P','path_toggle'),('X','xray')]:
        value = re.sub(r'(?<![A-Za-z0-9_:])'+letter+r'(?=\s|[维修灭火替补取消重试回放导出路径内构关接为])','{key:'+action+'}',value)
    value = value.replace('按T','按{key:repair}')
    value = value.replace('Enter','{key:lesson_result}') if ('课目' in value or '结果' in value) else value
    if 'Tab' in value:
        action = 'scoreboard' if '战况' in value else 'switch_control'
        value = value.replace('Tab','{key:'+action+'}')
    value = value.replace('Q / E','{key:spectate_previous} / {key:spectate_next}')
    value = value.replace(', / . 历史','{key:replay_previous} / {key:replay_next} 历史')
    bank[key] = value

bank.update({
 'ui_d5f1aabb1300':'8秒准备后选择再出击；堵塞时等待安全出生点。\n{key:spectate_previous}/{key:spectate_next}观察友军，{key:scoreboard}查看战况。',
 'ui_1bd1bce2426c':'{key:scenario_1}—{key:scenario_5} 新开路线 · {key:switch_control} 观察/驾驶\n{key:move_forward}/{key:move_back} {key:turn_left}/{key:turn_right} 驾驶\n{key:path_toggle} 路径 · {key:xray} 内构 · {key:reset} 重试 · Esc菜单',
 'ui_d9a919d932da':'{key:move_forward}/{key:move_back}驾驶 · {key:turn_left}/{key:turn_right}转向 · {key:fire}射击\n{key:scenario_1}—{key:scenario_4}选择路线 · {key:switch_control}接管目标\n{key:xray}内构 · {key:reset}重试 · Esc菜单',
 'ui_b13d94d68686':'{key:shell_1}/{key:shell_2}选择下一弹种\n{key:shell_target_thin}薄靶 / {key:shell_target_thick}厚靶 · {key:xray}内构\n{key:fire}开火 · {key:aim}炮镜 · {key:reset}重开 · Esc菜单',
 'ui_b397ed349143':'{key:move_forward}/{key:move_back}驾驶 · {key:turn_left}/{key:turn_right}转向 · {key:fire}开火\n{key:switch_control}接管 · {key:repair}维修 · {key:extinguish}灭火 · {key:replace_crew}替补\n{key:scenario_1}—{key:scenario_5}案例 · {key:xray}内构 · {key:reset}重开 · Esc菜单',
 'ui_6523b46e9b15':'{key:move_forward}/{key:move_back}驾驶 · {key:turn_left}/{key:turn_right}转向 · {key:fire}开火\n{key:switch_control}接管 · {key:xray}内构\n{key:reset}重开 · Esc菜单',
 'ui_909e8e579f2b':'装甲实验室 · {key:scenario_1}—{key:scenario_6}选择目标 · Esc菜单'
})
path.write_text(json.dumps(bank,ensure_ascii=False,indent=2,sort_keys=True)+'\n',encoding='utf-8')
print('Binding templates:',sum('{key:' in value for value in bank.values()))
