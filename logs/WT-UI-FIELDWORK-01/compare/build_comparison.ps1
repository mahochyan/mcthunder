# WT-UI-FIELDWORK-01: compose the design-vs-actual comparison sheet from the supplied concept image and the real
# window captures this work produced. Nothing here is drawn by hand: every panel is a real file on disk.
Add-Type -AssemblyName System.Drawing
$root = 'E:\AIprogram\mcthunder-cont'
$log = Join-Path $root 'logs\WT-UI-FIELDWORK-01'
$outDir = Join-Path $log 'compare'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$concept = 'C:\Users\lapyin\.dsh\attachments\v1\objects\7c\7c927c407399304c1ad69495e7bb6fad8d3491cb25a9f169f91b80c4d1b1857a'
$panels = @(
  @{ p = "$log\wt-ui-012-four\04_deployment_1280x720_100.png";  t = '实际 · S01 作战车库（1280x720 @100%）' },
  @{ p = "$log\wt-ui-012-nav\nav_01_loadout_page.png";          t = '实际 · S03 车辆配装（弹药/编成/检查三类）' },
  @{ p = "$log\wt-ui-012-nav\nav_06_research_compact.png";      t = '实际 · S02 科技树（五路线同排 · 无假前置线）' },
  @{ p = "$log\wt-ui-012-hud\hud_10_normal_compact.png";        t = '实际 · S04 战斗 HUD（四区 · 中心留白）' },
  @{ p = "$log\wt-ui-012-nav\nav_11_challenge_card.png";        t = '实际 · S08 挑战卡（规则/最佳/有限配弹）' },
  @{ p = "$log\wt-ui-012-nav\nav_12_training_cards.png";        t = '实际 · S08 训练课目卡（7/7 · 诚实完成度）' },
  @{ p = "$log\wt-ui-012-nav\nav_13_research_empty.png";        t = '实际 · S09 空态（搜索无匹配的显式空态）' },
  @{ p = "$log\wt-ui-012-nav\nav_09_zero_rack.png";             t = '实际 · S09 错误态（零弹架被服务拒绝）' }
)

$W = 1800
# Tall enough that the concept caption below the title block cannot collide with the subtitle line.
$titleH = 150
$conceptW = 1740
$conceptSrc = [System.Drawing.Image]::FromFile($concept)
$conceptH = [int]($conceptW * $conceptSrc.Height / $conceptSrc.Width)
$cellW = 860
$cellH = [int]($cellW * 720 / 1280)
$gridH = $cellH * 4 + 132
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
$g.DrawString('已实现并验证：S01 车库 · S02 科技树 · S03 配装 · S04 HUD/炮镜 · S05 战损与提示 · S06 阵亡/观战/再出击 · S07 结算 · S08 训练/挑战/设置/弹窗 · S09 无假进度与空态（错误态已实拍）。', $fSmall, $bMuted, 30, ($ty + 68))
$g.DrawString('回归全绿：nav 96 · HUD 43 · 令牌 78 · 身份 44 · 图标 13 · 鼠标焦点 9 · 车库四分辨率 51（1280x720 / 1920x1080 × 100% / 125%）。性能 HOLD_BY_USER；真人不代签；内部包 release_ready=false。', $fSmall, $bMuted, 30, ($ty + 92))

$target = Join-Path $outDir 'DESIGN_vs_ACTUAL.png'
$bmp.Save($target, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose(); $conceptSrc.Dispose()
"SAVED=$target"
"BYTES=" + (Get-Item $target).Length
