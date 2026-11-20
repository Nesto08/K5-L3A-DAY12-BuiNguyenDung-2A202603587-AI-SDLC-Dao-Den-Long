$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$project = Join-Path $repo 'daodenlong'
$proof = Join-Path $repo 'docs\proof'
New-Item -ItemType Directory -Force $proof | Out-Null

& godot --headless --path $project --editor --quit
if ($LASTEXITCODE -ne 0) { throw 'Godot import failed' }
& godot --headless --path $project --script 'res://tests/test_phase1.gd'
if ($LASTEXITCODE -ne 0) { throw 'Core tests failed' }

$scenario = (Resolve-Path (Join-Path $PSScriptRoot 'scenario_contract.json')).Path
$inputs = (Resolve-Path (Join-Path $PSScriptRoot 'inputs_walk.json')).Path
$out1 = Join-Path $proof 'headless_a.jsonl'
$out2 = Join-Path $proof 'headless_b.jsonl'
foreach ($out in @($out1,$out2)) {
    & godot --quiet --headless --path $project --script 'res://scripts/headless_runner.gd' -- --seed 12 --night 1 --scenario $scenario --inputs $inputs --ticks 120 --snapshot-every 30 --out $out
    if ($LASTEXITCODE -ne 0) { throw 'Headless failed' }
}
if ((Get-FileHash $out1).Hash -ne (Get-FileHash $out2).Hash) { throw 'Determinism failed' }
$records = @(Get-Content $out1 | ForEach-Object { $_ | ConvertFrom-Json })
if ($records[0].type -ne 'snapshot' -or $records[0].tick -ne 0) { throw 'Tick 0 snapshot missing' }
$last = $records[-1]
if ($last.type -ne 'end' -or $last.ticks -ne 120) { throw 'End record incorrect' }
if ($records[0].player.flames -ne 3 -or $records[0].motes_active -ne 1) { throw 'Snapshot contract incomplete' }

$depositScenario = (Resolve-Path (Join-Path $PSScriptRoot 'scenario_deposit.json')).Path
$depositInputs = (Resolve-Path (Join-Path $PSScriptRoot 'inputs_interact.json')).Path
$outDeposit = Join-Path $proof 'deposit.jsonl'
& godot --quiet --headless --path $project --script 'res://scripts/headless_runner.gd' -- --seed 1 --night 1 --scenario $depositScenario --inputs $depositInputs --ticks 4 --snapshot-every 1 --out $outDeposit
if ($LASTEXITCODE -ne 0) { throw 'Deposit scenario failed' }
$depositRecords = @(Get-Content $outDeposit | ForEach-Object { $_ | ConvertFrom-Json })
$deposits = @($depositRecords | Where-Object { $_.type -eq 'event' -and $_.name -eq 'deposit' })
if ($deposits.Count -ne 1 -or $deposits[0].data.amount -ne 3) { throw 'Edge triggering or deposit incorrect' }

Write-Host 'PASS: core, input, scenario, JSONL, deterministic outputs, edge actions' -ForegroundColor Green
