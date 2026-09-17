# WT-UI-FIELDWORK-01: compose the design-vs-actual comparison sheet from the supplied concept image and the real
# window captures this work produced. Nothing here is drawn by hand: every panel is a real file on disk.
Add-Type -AssemblyName System.Drawing
$root = 'E:\AIprogram\mcthunder-cont'
$log = Join-Path $root 'logs\WT-UI-FIELDWORK-01'
$outDir = Join-Path $log 'compare'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$concept = 'C:\Users\lapyin\.dsh\attachments\v1\objects\7c\7c927c407399304c1ad69495e7bb6fad8d3491cb25a9f169f91b80c4d1b1857a'
$panels = @(
  @{ p = "$log\wt-ui-004-first-batch\04_deployment_1280x720_100.png"; t = '实际 · 作战车库 S01（1280x720 @100%）' },
  @{ p = "$log\wt-ui-006\nav_01_loadout_page.png";                    t = '实际 · 车辆配装 S03（弹药/编成组置顶）' },
  @{ p = "$log\wt-ui-005\nav_06_research_compact.png";                t = '实际 · 科技树 S02（五路线同排 · 无假前置线）' },
  @{ p = "$log\wt-ui-006-modern\ussr_t_80b_river.png";                t = '实际 · 战斗 HUD S04（尚未美化 · WT-UI-007/008 待做）' }
)

$W = 1800
$titleH = 108
$conceptW = 1740
$conceptSrc = [System.Drawing.Image]::FromFile($concept)
$conceptH = [int]($conceptW * $conceptSrc.Height / $conceptSrc.Width)
$cellW = 860
$cellH = [int]($cellW * 720 / 1280)
$gridH = $cellH * 2 + 72
$footH = 300
$H = $titleH + $conceptH + 36 + $gridH + $footH

$bmp = New-Object System.Drawing.Bitmap($W, $H)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.Clear([System.Drawing.Color]::FromArgb(16, 23, 27))

$ink   = [System.Drawing.Color]::FromArgb(236, 237, 230)
$muted = [System.Drawing.Color]::FromArgb(168, 182, 186)
$gold  = [System.Drawing.Color]::FromArgb(224, 180, 106)
$line  = [System.Drawing.Color]::FromArgb(53, 70, 78)
$panel = [System.Drawing.Color]::FromArgb(24, 35, 41)
$fTitle = New-Object System.Drawing.Font('Microsoft YaHei', 30, [System.Drawing.FontStyle]::Bold)
$fSub   = New-Object System.Drawing.Font('Microsoft YaHei', 16)
$fCap   = New-Object System.Drawing.Font('Microsoft YaHei', 15)
$fSmall = New-Object System.Drawing.Font('Microsoft YaHei', 13)
$fMono  = New-Object System.Drawing.Font('Consolas', 13)
$bTitle = New-Object System.Drawing.SolidBrush($ink)
$bMuted = New-Object System.Drawing.SolidBrush($muted)
$bGold  = New-Object System.Drawing.SolidBrush($gold)
$pLine  = New-Object System.Drawing.Pen($line, 1)

function Draw-Scaled([System.Drawing.Image]$img, [int]$x, [int]$y, [int]$w, [int]$h) {
  $g.DrawImage($img, (New-Object System.Drawing.Rectangle($x, $y, $w, $h)))
  $g.DrawRectangle($pLine, $x, $y, $w, $h)
}

# Title
$g.DrawString('MCTHUNDER · MCT-UI-FIELDWORK-01 设计单 vs 实际实现 对比图', $fTitle, $bTitle, 30, 26)
$sha = (& git -C $root rev-parse HEAD).Substring(0, 10)
$g.DrawString("真实窗口抓帧 · 源码 $sha · 色值以设计单规范表与原件 07_UI_TOKENS.json 为准（概念图色条仅作气氛参考）", $fSub, $bMuted, 32, 70)

# Concept sheet
$cy = $titleH
$g.DrawString('设计单概念图（原图 1536x1024）', $fCap, $bGold, 30, $cy - 24)
Draw-Scaled $conceptSrc 30 ($cy + 4) $conceptW $conceptH
$cy = $cy + $conceptH + 40

# Real captures, 2x2
$g.DrawString('实际实现（Godot 4.7.2 真实渲染抓帧）', $fCap, $bGold, 30, $cy - 26)
for ($i = 0; $i -lt $panels.Count; $i++) {
  $col = $i % 2
  $row = [math]::Floor($i / 2)
  $x = 30 + $col * ($cellW + 20)
  $y = $cy + $row * ($cellH + 36)
  $img = [System.Drawing.Image]::FromFile($panels[$i].p)
  Draw-Scaled $img $x $y $cellW $cellH
  $g.DrawString($panels[$i].t, $fCap, $bTitle, ($x + 2), ($y + $cellH + 6))
  $img.Dispose()
}
$fy = $cy + $gridH

# Footer: real tokens + mockup-only elements that are NOT requirements
$g.DrawLine($pLine, 30, $fy - 6, ($W - 30), ($fy - 6))
$g.DrawString('实际令牌（configs/ui/ui_tokens.json ≡ 原件 07_UI_TOKENS.json）', $fCap, $bGold, 30, $fy + 6)
$tokens = Get-Content (Join-Path $root 'configs\ui\ui_tokens.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$tx = 30; $ty = $fy + 36
foreach ($prop in $tokens.colors.PSObject.Properties) {
  $hex = [string]$prop.Value
  $c = [System.Drawing.ColorTranslator]::FromHtml($hex)
  $b = New-Object System.Drawing.SolidBrush($c)
  $g.FillRectangle($b, $tx, $ty, 26, 26)
  $g.DrawRectangle($pLine, $tx, $ty, 26, 26)
  $g.DrawString(("{0} {1}" -f $prop.Name, $hex), $fMono, $bMuted, ($tx + 32), ($ty + 4))
  $b.Dispose()
  $tx += 300
  if ($tx -gt ($W - 330)) { $tx = 30; $ty += 40 }
}
$g.DrawString('概念图中以下元素在真实系统中不存在，按设计单禁区一律不显示：金币 1,250,000 · 等级 Lv.28 · 战力分 92/88/82/65 · 16v16 泊位 · 跨国混编。', $fSmall, $bMuted, 30, ($ty + 44))
$g.DrawString('已实现：S01 车库（身份来自数据 · 固定主操作 · 当前编成 · 可横向滚动收集行）· S02 科技树（五路线同排 · 切国保留搜索与滚动 · 两层状态 · 无假前置线）· S03 配装（弹药/编成/检查三类 · 真实弹族与估算标记 · 总量·库存·首发同处）。', $fSmall, $bMuted, 30, ($ty + 68))
$g.DrawString('待做：S04-S09（HUD/炮镜/战损/阵亡/结算/训练与设置/加载空态）。性能保持 HOLD_BY_USER；真人体验不代签。', $fSmall, $bMuted, 30, ($ty + 92))

$target = Join-Path $outDir 'DESIGN_vs_ACTUAL.png'
$bmp.Save($target, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose(); $conceptSrc.Dispose()
"SAVED=$target"
"BYTES=" + (Get-Item $target).Length
