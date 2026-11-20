#!/usr/bin/env python3
"""Run the actual rendered Godot benchmark; no fabricated FPS values."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--seed', type=int, default=42)
    parser.add_argument('--duration', type=float, default=30)
    parser.add_argument('--out', default='bench.json')
    args = parser.parse_args()
    godot = os.environ.get('GODOT') or shutil.which('godot') or shutil.which('godot4')
    if not godot:
        parser.error('Godot not found. Set $env:GODOT = (Get-Command godot).Source')
    try:
        import psutil
    except ImportError:
        parser.error('psutil is needed to capture process RSS; run: python -m pip install psutil')
    out = Path(args.out).resolve()
    command = [godot, '--path', str(ROOT / 'daodenlong'), '--script', 'res://scripts/benchmark_runner.gd',
               '--', '--seed', str(args.seed), '--duration', str(args.duration), '--out', str(out)]
    print('Benchmark: 1280x720, 200 real rendered shades, 100 motes, seed', args.seed, flush=True)
    started = time.monotonic()
    proc = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, encoding='utf-8', errors='replace')
    measured = psutil.Process(proc.pid)
    max_rss = 0
    import threading
    lines = []
    def consume():
        for line in proc.stdout:
            print(line, end='', flush=True)
            lines.append(line)
    thread = threading.Thread(target=consume, daemon=True)
    thread.start()
    try:
        while proc.poll() is None:
            try:
                max_rss = max(max_rss, measured.memory_info().rss)
            except psutil.Error:
                pass
            time.sleep(0.05)
    finally:
        thread.join(timeout=3)
    if proc.returncode != 0 or not out.is_file():
        sys.exit(f'FAIL: benchmark exited {proc.returncode}; verify Godot window and renderer')
    data = json.loads(out.read_text(encoding='utf-8'))
    data['peak_mem_mb'] = round(max_rss / (1024 ** 2), 2) if max_rss else None
    out.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'Wrote {out} | avg_fps={data["avg_fps"]:.1f} | p1_low_fps={data["p1_low_fps"]:.1f} | elapsed={time.monotonic()-started:.1f}s')
    # Do not fake a PASS: FPS thresholds are for the coach's reference machine.


if __name__ == '__main__':
    main()
