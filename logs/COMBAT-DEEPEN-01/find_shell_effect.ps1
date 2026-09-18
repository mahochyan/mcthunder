$c='E:\AIprogram\mcthunder-cont'
$g='E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$L="$c\logs\COMBAT-DEEPEN-01"
$fix="$c\assets\vehicles\test_cd007_he_fixture"
New-Item -ItemType Directory -Force -Path $fix | Out-Null
[IO.File]::WriteAllText("$fix\.gdignore","",(New-Object Text.UTF8Encoding($false)))

"=== find the shell-level effect whitelist ==="
Select-String -Path "$c\scripts\defs\shell_definition.gd" -Pattern 'effect_policy|unsupported|kinetic' -Encoding UTF8 | ForEach-Object { "  L" + $_.LineNumber + ": " + $_.Line.Trim().Substring(0,[Math]::Min(150,$_.Line.Trim().Length)) }
Select-String -Path "$c\scripts\content\shell_catalog.gd","$c\scripts\content\vehicle_shell_catalog.gd" -Pattern 'effect_policy.*not in|unsupported effect' -Encoding UTF8 -ErrorAction SilentlyContinue | ForEach-Object { "  " + (Split-Path $_.Path -Leaf) + " L" + $_.LineNumber + ": " + $_.Line.Trim().Substring(0,[Math]::Min(140,$_.Line.Trim().Length)) }
