"""Phase 2 smoke/regression checks. Requires Godot 4 available on PATH.
Does not edit or fake any test output.
"""
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GODOT = os.environ.get('GODOT', 'godot')
HEADLESS = [GODOT, '--quiet', '--headless', '--path', str(ROOT/'daodenlong'), '--script', 'res://scripts/headless_runner.gd', '--']


def run(night=1, ticks=60, scenario=None, inputs=None, seed=41):
    with tempfile.TemporaryDirectory() as temp:
        temp = Path(temp)
        out = temp/'output.jsonl'
        args = HEADLESS + ['--night',str(night),'--seed',str(seed),'--ticks',str(ticks),'--snapshot-every','10','--out',str(out)]
        for key, obj in [('scenario',scenario),('inputs',inputs)]:
            if obj is not None:
                source = temp/(key+'.json')
                source.write_text(json.dumps(obj),encoding='utf-8')
                args += ['--'+key,str(source)]
        result = subprocess.run(args,cwd=ROOT,capture_output=True,text=True,timeout=35)
        if result.returncode != 0:
            raise AssertionError(f'Godot return code {result.returncode}\n{result.stdout}\n{result.stderr}')
        assert out.exists(), 'Output file missing'
        return [json.loads(line) for line in out.read_text(encoding='utf-8').splitlines() if line.strip()]


def test_main():
    contract = json.loads((ROOT/'game.contract.json').read_text(encoding='utf-8'))
    assert contract['contract_version'] == '1.1'
    for night, n_lamps, duration in [(1,5,300),(2,6,330),(3,7,360)]:
        trace = run(night=night,ticks=60,scenario={'random_motes':False,'random_shades':False,'random_drifters':False})
        start = trace[0]
        assert start['type'] == 'snapshot' and start['tick'] == 0 and start['sim_tick'] == 0
        assert start['night'] == night and len(start['lanterns']) == n_lamps
        assert abs(start['time_left_s']-duration)<0.01
        assert len(start['drifters']) == 0 and start['motes_active'] == 0
        assert trace[-1]['type']=='end' and trace[-1]['ticks']==60
    print('PASS: three nights and contract v1.1')

    scenario = {'random_motes':False,'random_shades':False,'random_drifters':False,
                'player':{'pos':[0,0,25],'carried':10},'lanterns':[{'id':'L1','deposited':0,'lit':False}]}
    inputs = {'frames':[{'tick':0,'interact':True}]}
    trace = run(ticks=2,scenario=scenario,inputs=inputs)
    events = [row for row in trace if row['type']=='event']
    assert any(e['name']=='deposit' and e['tick']==1 for e in events)
    assert any(e['name']=='lantern_lit' for e in events)
    assert trace[-1]['score']==200, trace[-1]
    print('PASS: deposit 10, light lantern, 10*10+100 score')

    scenario = {'random_motes':False,'random_shades':False,'random_drifters':False,
                'player':{'pos':[0,0,0],'carried':3},'shades':[{'id':'S1','pos':[2,0,0]}]}
    inputs = {'frames':[{'tick':0,'pulse':True}]}
    trace = run(ticks=3,scenario=scenario,inputs=inputs)
    events = [row for row in trace if row['type']=='event']
    assert any(e['name']=='pulse' for e in events)
    assert trace[-1]['score']==5
    print('PASS: pulse and stun score')

    paused = run(ticks=25,scenario={'random_motes':False,'random_shades':False,'random_drifters':False},
                 inputs={'frames':[{'tick':0,'pause':True}]})
    snaps=[x for x in paused if x['type']=='snapshot']
    assert snaps[-1]['tick']==20 and snaps[-1]['sim_tick']==0 and snaps[-1]['state']=='paused'
    print('PASS: paused ticks increment, sim_tick and time freeze')

    for night in [1,2,3]:
        a=run(night=night,ticks=100,seed=999)
        b=run(night=night,ticks=100,seed=999)
        assert a==b, f'Non-deterministic night {night}'
    print('PASS: deterministic for all nights')
    print('PASS: Phase 2 smoke/regression tests')

if __name__=='__main__':
    try:
        test_main()
    except FileNotFoundError as exc:
        print('ERROR: Godot not found. Set GODOT to path of executable.', file=sys.stderr)
        raise SystemExit(2) from exc
