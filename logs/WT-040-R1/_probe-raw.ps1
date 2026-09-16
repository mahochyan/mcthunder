$c = 'E:\AIprogram\mcthunder-cont'
$want = 'year|intro|service|suspension|mount|dimension|width|length|reload|pitch|elevation|depression|penetrat|armament|variant|designation'
foreach ($id in 'ussr_t_80b','germ_leopard_2a4') {
    $p = Join-Path $c "assets\reference_data\candidates\$id.json"
    $j = [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
    Write-Output ("===== {0} =====" -f $id)
    Write-Output ("raw_fields type={0} count={1}" -f $j.raw_fields.GetType().Name, @($j.raw_fields.PSObject.Properties).Count)
    foreach ($f in @($j.raw_fields.PSObject.Properties)) {
        if ($f.Name -match $want) {
            $v = ($f.Value | ConvertTo-Json -Compress -Depth 3)
            if ($v.Length -gt 110) { $v = $v.Substring(0, 110) }
            Write-Output ("  raw.{0,-32} = {1}" -f $f.Name, $v)
        }
    }
    Write-Output ("combat_definition keys: " + (($j.combat_definition.PSObject.Properties | ForEach-Object { $_.Name }) -join ', '))
    foreach ($f in @($j.combat_definition.PSObject.Properties)) {
        if ($f.Name -match $want) {
            $v = ($f.Value | ConvertTo-Json -Compress -Depth 3)
            if ($v.Length -gt 110) { $v = $v.Substring(0, 110) }
            Write-Output ("  cd.{0,-33} = {1}" -f $f.Name, $v)
        }
    }
    Write-Output ("admission = " + ($j.admission | ConvertTo-Json -Compress -Depth 3))
    Write-Output ("weapon_references keys: " + (($j.weapon_references.PSObject.Properties | ForEach-Object { $_.Name }) -join ', '))
    Write-Output ("source = " + ($j.source | ConvertTo-Json -Compress -Depth 2).Substring(0, [Math]::Min(150, ($j.source | ConvertTo-Json -Compress -Depth 2).Length)))
}
