# RUN_METADATA — 006-R1 有限收尾证据（tested_code_sha = 5d2c0bbb121b7add15408e30a18af785f1c3cebe）

采集日期：006-R1 finite_closeout（GPT 复审后收尾轮）
BASE_SHA = 37f6762162eb31237c2384b2d557bb604046033f（上轮交付 HEAD）
采集方式：cmd /c 批处理（等待真实进程结束取 %ERRORLEVEL%；全部运行正常退出，无超时）

## 环境

- 引擎：Godot 4.7.2.stable.official.ed1daf0bf（tools/godot 控制台版）
- 渲染器：gl_compatibility；物理频率固定 60 Hz（未使用 --fixed-fps）
- 证据采集时无未提交源码改动（提交 5d2c0bbb121b7add15408e30a18af785f1c3cebe）

## 先反例后修复（同提交，运行序列见交付说明）

- 修复前运行（生产门未加）：144 项中 7 项收尾反例精确变红——
  FAIL[132] cancel_all 通知中发射被拒 (reason=accepted)、
  FAIL[134] 取消返回后同一请求可接受（去重键被清理期占用）、
  FAIL[136] cancel_by_shooter 通知中发射被拒 (accepted)、
  FAIL[138] 仅剩其他射手 1 发 (active=2，单车取消回调内新弹遗留)、
  FAIL[139] 单车取消返回后可再发射、
  FAIL[142] 嵌套内层返回后仍拒绝 (accepted)、
  FAIL[144] 最外层取消返回后恢复接受。
  —— 与审核端独立控制流模型一致（cancel_all 内被接收→无声删除；cancel_by_shooter 内被接收→遗留）。
- 修复后运行（_cancel_depth 门）：144 项 0 失败。

## 无头检查（4 套，最终 sha = 5d2c0bb…）

命令（工作目录=工程根）：`Godot_v4.7.2-stable_win64_console.exe --headless --path E:\AIprogram\mcthunder -s res://tests/<suite>.gd`

| 套件 | 结果 | 退出码 | stderr 脚本错误 |
|---|---|---|---|
| run_projectile_checks | 144 项 0 失败，PROJECTILE_CHECKS_PASS | 0 | 0 |
| run_checks | 214 项 0 失败，CHECKS_PASS | 0 | 0 |
| run_query_checks | 140 项 0 失败，QUERY_CHECKS_PASS | 0 | 0 |
| run_layout_checks | 123 项 0 失败，LAYOUT_CHECKS_PASS | 0 | 0 |

各 `*_stdout.txt`/`*_stderr.txt` 为原始完整输出；stderr 逐文件扫描无 SCRIPT ERROR/Parse Error。

## 范围声明

- 仅修改：projectile_manager.gd（_cancel_depth 门 + 移除 blanket clear）、
  run_projectile_checks.gd（收尾反例 3 场景 + 0.9m 真值 + 恰好端点/上限外两案例）。
- 未重跑：变异验证；未重拍：12 张演示截图（旧证据保留 ac8bfb3… SHA 归属）。
- 未验证项：截图人工目视（并入 011 前人工验收）；真人体验（最迟 011 前）。
- 006 未更新为 accepted；不新增 006-R2；不开始 007；不合并 main。