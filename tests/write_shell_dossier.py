"""Rebuild the human-readable index from the admitted 021 data, with no external fetch."""
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
packet = json.loads((root / 'configs/shells/historical_loadouts.json').read_text(encoding='utf-8'))
lines = ['# 021 当前历史弹种资料', '',
         '运行目录为 configs/shells/historical_loadouts.json；它覆盖020车型包的弹道初值。020原始字段作为当时版本的档案保留，不代表021当前弹道。', '',
         '适配有原始手册/目录依据；穿深曲线均为 estimated，内部爆发均为 game_rule。初速的 verified 只表示引用记录支持该值，不代表当前游戏完成实测标定。APHE不是工程级引信或爆药仿真。', '',
         '每车默认主弹约70%、另一弹约30%（向下取整另一弹，总数保持车型载弹量）。M24默认M61，其他默认实心AP。M72适配M6来自TM9-729图197A；1951实际配发情况仍unknown。', '',
         'M77/M82的90 mm游戏曲线远距离有交叉，不能概括成APHE在所有距离穿深更低。训练AP120/APHE96的0.8倍率是单独的TEST ONLY比较夹具，未用于历史弹种。', '']
for key, row in packet['shells'].items():
    lines += [f'## {key} · {row["label"]}', '',
              f'火炮：{row["gun"]}；口径：{row["caliber_mm"]} mm；作用：{row["effect_policy"]}。',
              f'初速：{row["muzzle_velocity_mps"]} m/s（{row["muzzle_velocity_status"]}）。', '',
              '| 距离 m | 游戏法向穿深 mm（estimated） |', '|---|---|']
    lines += [f'| {x} | {y} |' for x, y in row['penetration_curve']]
    lines += ['', '原文观察：' + row['historical_observations'], '', '估算及冲突处理：' + row['estimate_reason'], '',
              '来源：' + ', '.join(row['source_refs']), '']
lines += ['## 来源索引', '']
for key, row in packet['sources'].items():
    lines += [f'### {key}', '', f'[{row["title"]}]({row["url"]})', '',
              row['location'], '', f'{row["origin"]} · {row["read_state"]}', '', f'SHA256 `{row["sha256"]}`', '']
output = root / 'docs/vehicles/HISTORICAL_SHELLS_021.md'
output.write_text('\n'.join(lines), encoding='utf-8')
print(output)
