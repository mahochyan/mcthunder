$c = 'E:\AIprogram\mcthunder-cont'
$enc = New-Object System.Text.UTF8Encoding($false)

function Show($m) { Write-Output $m }

# --- 1) name the control in the shared visibility assertion (diagnostic only, no semantic change) --------
$p1 = Join-Path $c 'scripts\diagnostics\window_input_driver.gd'
$t1 = [System.IO.File]::ReadAllText($p1, [System.Text.Encoding]::UTF8)
$nl1 = if ($t1.Contains("`r`n")) { "`r`n" } else { "`n" }
$old1 = '	check(is_instance_valid(button) and button.is_visible_in_tree(),"normal UI control is visible before click")'
$new1 = @'
	# WT-040-R1: name the offending control, because the packaged run reports four failures of this assertion in
	# the final garage-to-map section and which control it is decides whether the fault is a test timing issue or
	# a real UI defect. The assertion itself is unchanged.
	var control_label := "<null: the caller could not find the control>"
	if is_instance_valid(button):
		control_label = str(button.get_path()) + " visible=" + str(button.is_visible_in_tree()) + " disabled=" + str(button.disabled if "disabled" in button else false)
	check(is_instance_valid(button) and button.is_visible_in_tree(),"normal UI control is visible before click: "+control_label)
'@
$n1 = ([regex]::Matches($t1, [regex]::Escape($old1))).Count
Show ("click anchor x" + $n1)
if ($n1 -eq 1) { $t1 = $t1.Replace($old1, $new1.TrimEnd("`r","`n").Replace("`n", $nl1)); [System.IO.File]::WriteAllText($p1, $t1, $enc); Show "click patch applied" } else { Show "CLICK ANCHOR MISSING"; exit 1 }

# --- 2) report what the garage start-button lookup returns, before it is clicked -------------------------
$p2 = Join-Path $c 'scripts\diagnostics\player_flow_verifier.gd'
$t2 = [System.IO.File]::ReadAllText($p2, [System.Text.Encoding]::UTF8)
$nl2 = if ($t2.Contains("`r`n")) { "`r`n" } else { "`n" }
$old2 = '		await click(find_button(app.garage,LocalizationService.text("ui_56b6b54bb00a"))); await idle()'
$new2 = @'
		# WT-040-R1: report the lookup itself, so a null or hidden start button is named instead of only failing
		# the generic visibility assertion.
		var start_button := find_button(app.garage,LocalizationService.text("ui_56b6b54bb00a"))
		print("[garage] map_index=",map_index," start_button_valid=",is_instance_valid(start_button),
			" visible=",is_instance_valid(start_button) and start_button.is_visible_in_tree(),
			" settings_visible=",app.garage.preparation.details.visible,
			" map_choice_index=",app.garage.preparation.map_choice.selected)
		await click(start_button); await idle()
'@
$n2 = ([regex]::Matches($t2, [regex]::Escape($old2.Replace("`n", $nl2)))).Count
Show ("start-button anchor x" + $n2)
if ($n2 -eq 1) { $t2 = $t2.Replace($old2.Replace("`n", $nl2), $new2.TrimEnd("`r","`n").Replace("`n", $nl2)); [System.IO.File]::WriteAllText($p2, $t2, $enc); Show "verifier patch applied" } else { Show "START ANCHOR MISSING"; exit 1 }

# --- parse check before anything is run or built --------------------------------------------------------
$g = 'E:\AIprogram\mcthunder\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
Show ("engine exists=" + (Test-Path $g))
foreach ($pair in @(@($p1,'window_input_driver.gd'), @($p2,'player_flow_verifier.gd'))) {
    & $g --headless --path $c --check-only --script ("res://" + ($pair[0].Replace($c + '\','').Replace('\','/'))) *> (Join-Path $c ('logs\WT-040-R1\chk-' + $pair[1] + '.log')) 2>&1 | Out-Null
    $perr = @(Get-Content (Join-Path $c ('logs\WT-040-R1\chk-' + $pair[1] + '.log')) | Select-String 'Parse Error|Compile Error').Count
    Show ("  " + $pair[1] + " parse errors=" + $perr)
    if ($perr -gt 0) { Get-Content (Join-Path $c ('logs\WT-040-R1\chk-' + $pair[1] + '.log')) | Select-String 'Parse Error' | Select-Object -First 3 | ForEach-Object { Show ("      " + $_.Line.Trim()) }; exit 1 }
}

# --- commit the diagnostic and start a candidate build from it ------------------------------------------
git -C $c add scripts/diagnostics/window_input_driver.gd scripts/diagnostics/player_flow_verifier.gd logs/WT-040-R1
git -C $c -c user.name=mcthunder-agent -c user.email=agent@mcthunder.local commit -m "Name the control that fails the packaged visibility assertion, because which control it is decides the next step. The packaged flow now reaches the final garage-to-map section and fails four times on a generic is_visible_in_tree assertion plus once on the map entry check, and the shared click helper already scrolls controls into view when the expanded garage puts them below the fold, so the cause is not the fold. The assertion is unchanged in meaning: it now reports the control's node path, its visibility and whether it is disabled, and a null lookup says so explicitly. The garage start button is also looked up once and reported before it is clicked, so a missing or hidden button is named rather than only failing the generic check. The source tree cannot reach this section at all, because it aborts after the expected non-Release failure, so the diagnostic has to be read from a package - hence this commit is followed by a rebuild" 2>&1 | Select-Object -First 2
Show ("commits=" + (git -C $c rev-list --count a1bac406..HEAD))
git -C $c push origin work/continuation-20260913 2>&1 | Select-Object -Last 1 | ForEach-Object { Show ("push: " + $_.ToString()) }
git -C $c diff --quiet HEAD; Show ("clean-check exit=" + $LASTEXITCODE + " (0 ok)")

Show "=== starting candidate build with the named diagnostic ==="
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $c 'tests\build_release.ps1') -Candidate
Show ("build exit=" + $LASTEXITCODE)
