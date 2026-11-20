#!/usr/bin/env python3
"""Non-performance Phase 4 checks. Bench/soak run separately."""
import json
import os
import pathlib
import shutil
import subprocess
import sys
import tempfile

root = pathlib.Path(__file__).resolve().parents[1]
contract = json.loads((root / 'game.contract.json').read_text(encoding='utf8'))
assert contract['contract_version'] == '1.3'
assert contract['bench_cmd'] and contract['soak_cmd']
print('PASS: Contract 1.3 with bench_cmd and soak_cmd')

godot = os.environ.get('GODOT') or shutil.which('godot') or shutil.which('godot4')
if not godot:
    sys.exit('FAIL: Godot not found (set GODOT)')
with tempfile.TemporaryDirectory() as folder:
    out = pathlib.Path(folder)/'leaderboard.json'
    cmd = [godot, '--quiet', '--headless', '--path', str(root/'daodenlong'), '--script',
           'res://scripts/export_leaderboard.gd', '--', '--export-leaderboard', str(out)]
    result = subprocess.run(cmd, capture_output=True, text=True, encoding='utf8', errors='replace', timeout=60)
    if result.returncode != 0:
        sys.exit(f'FAIL: leaderboard export exit {result.returncode}\n{result.stdout}\n{result.stderr}')
    assert isinstance(json.loads(out.read_text(encoding='utf8'))['entries'],list)
    print('PASS: Leaderboard JSON export')
print('PASS: Phase 4 structural smoke tests (not benchmark/soak)')
