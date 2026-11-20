$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $repo
python .\tests\run_phase2_tests.py
if ($LASTEXITCODE -ne 0) { throw "Phase 2 test failed with exit code $LASTEXITCODE" }
