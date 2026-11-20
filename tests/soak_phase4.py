#!/usr/bin/env python3
"""Measure real Godot process RSS at two synchronized reset points."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--seed', type=int, default=7)
    parser.add_argument('--nights', type=int, default=10)
    parser.add_argument('--out', default='soak.json')
    args = parser.parse_args()
    if args.nights < 1:
        parser.error('--nights must be positive')
    godot = os.environ.get('GODOT') or shutil.which('godot') or shutil.which('godot4')
    if not godot:
        parser.error('Godot missing; set GODOT to the executable')
    try:
        import psutil
    except ImportError:
        parser.error('psutil is needed: python -m pip install psutil')

    out = Path(args.out).resolve()
    with tempfile.TemporaryDirectory(prefix='day12-soak-') as tmp:
        sync = Path(tmp)
        command = [
            godot, '--quiet', '--headless', '--path', str(ROOT / 'daodenlong'),
            '--script', 'res://scripts/soak_runner.gd', '--',
            '--seed', str(args.seed), '--nights', str(args.nights),
            '--out', str(out), '--sync-prefix', str(sync / 'checkpoint')
        ]
        proc = subprocess.Popen(command, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, text=True,
                                encoding='utf-8', errors='replace')
        measured = psutil.Process(proc.pid)
        readings = {}
        begin = time.monotonic()
        checkpoints = ('first', 'last')
        try:
            # The child must stay alive until the parent acknowledges each sample.
            for checkpoint in checkpoints:
                ready = Path(str(sync / 'checkpoint') + '.' + checkpoint + '.ready')
                ack = Path(str(sync / 'checkpoint') + '.' + checkpoint + '.ack')
                while not ready.exists():
                    if proc.poll() is not None:
                        output, _ = proc.communicate()
                        sys.exit(f'FAIL: Godot exited {proc.returncode} before {checkpoint} reset.\n{output}')
                    if time.monotonic() - begin > 900:
                        sys.exit('FAIL: soak exceeded 900 seconds before reset checkpoints')
                    time.sleep(0.02)
                readings[checkpoint] = measured.memory_info().rss
                ack.write_text('ack\n', encoding='ascii')
            output, _ = proc.communicate(timeout=30)
        except (psutil.Error, subprocess.TimeoutExpired) as exc:
            sys.exit(f'FAIL: could not measure live Godot RSS: {exc}')
        finally:
            if proc.poll() is None:
                proc.kill()
                proc.communicate()
        if output:
            print(output, end='' if output.endswith('\n') else '\n')
        if proc.returncode != 0 or not out.is_file():
            sys.exit(f'FAIL: soak runner exited {proc.returncode} or did not write output')
        result = json.loads(out.read_text(encoding='utf-8'))
        start_mb = round(readings['first'] / 2**20, 2)
        end_mb = round(readings['last'] / 2**20, 2)
        result['mem_start_mb'] = start_mb
        result['mem_end_mb'] = end_mb
        # Do not conceal errors reported by the runner.
        out.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        passes = result.get('crashes') == 0 and readings['last'] <= 1.2 * readings['first']
        print(f'{"PASS" if passes else "FAIL"}: soak crashes={result.get("crashes")}, '
              f'RSS start={start_mb}MB end={end_mb}MB '
              f'ratio={readings["last"] / readings["first"]:.3f}')
        if not passes:
            sys.exit(1)


if __name__ == '__main__':
    main()
