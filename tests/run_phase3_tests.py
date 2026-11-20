"""Ticket-03 functional smoke tests for Godot headless v1.2.
Uses temporary scenario and JSONL files; never modifies gameplay output.
"""
from __future__ import annotations
import json, os, shutil, subprocess, sys, tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
PROJECT=ROOT/'daodenlong'
CONTRACT=ROOT/'game.contract.json'
GODOT=os.environ.get('GODOT') or shutil.which('godot') or shutil.which('godot4')

def demand(condition, message):
    if not condition: raise AssertionError(message)

def scenario(extra=None):
    base={'random_motes':False,'random_shades':False,'random_drifters':False,'motes':[], 'shades':[], 'drifters':[], 'charms':[]}
    base.update(extra or {})
    return base

def run(case, ticks=1, inputs=None, night=1, snapshot_every=1):
    with tempfile.TemporaryDirectory(prefix='phase3_') as folder:
        folder=Path(folder)
        sp=folder/'scenario.json';sp.write_text(json.dumps(case),encoding='utf8')
        ip=folder/'inputs.json';ip.write_text(json.dumps(inputs or {'frames':[]}),encoding='utf8')
        out=folder/'result.jsonl'
        args=[GODOT,'--quiet','--headless','--path',str(PROJECT),'--script','res://scripts/headless_runner.gd','--','--seed','42','--night',str(night),'--scenario',str(sp),'--inputs',str(ip),'--ticks',str(ticks),'--snapshot-every',str(snapshot_every),'--out',str(out)]
        p=subprocess.run(args,capture_output=True,text=True,timeout=60)
        demand(p.returncode==0,f'Godot failed ({p.returncode}): {p.stderr[-2500:]} {p.stdout[-1200:]}')
        lines=[json.loads(line) for line in out.read_text(encoding='utf8').splitlines() if line.strip()]
        return lines

def events(lines, name): return [line for line in lines if line.get('type')=='event' and line.get('name')==name]
def last(lines): return [line for line in lines if line.get('type')=='snapshot'][-1]

def main():
    demand(GODOT and Path(GODOT).exists(),'Godot not found. In PowerShell: $env:GODOT = (Get-Command godot).Source')
    contract=json.loads(CONTRACT.read_text(encoding='utf8'))
    t=contract['tuning']
    demand(contract['contract_version']=='1.2','contract_version must be 1.2')
    demand([t[f'night{i}_duration_s'] for i in (1,2,3)]==[240,270,300],'night durations incorrect')
    demand(all(t[k]==v for k,v in {'fuel_max':100,'fuel_per_mote':10,'relight_cost':5,'win_ratio':0.6,'capacity_max':20}.items()),'v1.2 tuning incomplete')
    print('PASS: contract v1.2, updated durations and tuning')
    # A fully fuelled lantern burns 1 unit/second and does not end the night early.
    a=run(scenario({'lanterns':[{'id':'L1','lit':True,'fuel':100}]}),60)
    demand(last(a)['lanterns'][0]['fuel']==99.0,'fuel decay: expected 99 after 60 ticks')
    demand(last(a)['state']=='playing','night should not end early')
    demand(last(a)['player']['capacity']==10,'initial capacity must be 10')
    b=run(scenario({'lanterns':[{'id':'L1','lit':True,'fuel':1/60}]}),1)
    demand(not last(b)['lanterns'][0]['lit'] and last(b)['lanterns'][0]['fuel']==0,'lantern should extinguish')
    demand(len(events(b,'lantern_out'))==1,'lantern_out missing')
    print('PASS: 1/60 fuel decay, lantern_out and no instant win')
    interact={'frames':[{'tick':0,'interact':True}]}
    refuel=run(scenario({'player':{'pos':[0,0,25],'carried':4},'lanterns':[{'id':'L1','lit':True,'fuel':65}]}),1,interact)
    demand(last(refuel)['lanterns'][0]['fuel']==100,'refuel did not cap at 100')
    demand(last(refuel)['score']==20 and last(refuel)['player']['carried']==0,'refuel score/cost wrong')
    demand(events(refuel,'refuel')[0]['amount']==4,'refuel event wrong')
    first=run(scenario({'player':{'pos':[0,0,25],'carried':10}}),1,interact)
    demand(last(first)['lanterns'][0]['lit'],'first light failed')
    demand(last(first)['score']==150 and last(first)['player']['capacity']==12,'first light score/capacity wrong')
    demand(events(first,'lantern_lit')[0]['relight'] is False,'first-light relight flag wrong')
    relight=run(scenario({'player':{'pos':[0,0,25],'carried':5},'lanterns':[{'id':'L1','lit':False,'ever_lit':True,'fuel':0}]}),1,interact)
    demand(last(relight)['lanterns'][0]['lit'] and last(relight)['lanterns'][0]['relit_count']==1,'relight failed')
    demand(last(relight)['score']==65 and last(relight)['player']['capacity']==12,'relight score/capacity wrong')
    demand(events(relight,'lantern_lit')[0]['relight'] is True,'relight flag wrong')
    print('PASS: refuel, first light, relight, scoring and growing capacity')
    draining=run(scenario({'player':{'pos':[25,0,0]},'lanterns':[{'id':'L1','lit':True,'fuel':20}],
                           'shades':[{'id':'S1','pos':[0,0,25],'state':'drain','target_lantern_id':'L1'}]}),60)
    demand(last(draining)['lanterns'][0]['fuel']==14.0,'drain must combine -1/s and -5/s')
    demand(len(events(draining,'fuel_drain'))==1,'fuel_drain event must occur every 60 ticks')
    print('PASS: shade drain at 5/s and fuel_drain telemetry')
    surviving=run(scenario({'time_left_s':1/60,'lanterns':[{'id':f'L{i}','lit':True,'fuel':100} for i in (1,2,3)]}),1)
    demand(last(surviving)['state']=='won' and events(surviving,'game_over')[0]['reason']=='dawn_survived','dawn win threshold incorrect')
    failing=run(scenario({'time_left_s':1/60,'lanterns':[{'id':f'L{i}','lit':True,'fuel':100} for i in (1,2)]}),1)
    demand(last(failing)['state']=='lost' and events(failing,'game_over')[0]['reason']=='dawn','dawn loss threshold incorrect')
    noflames=run(scenario({'time_left_s':1/60,'player':{'flames':0},'lanterns':[{'id':f'L{i}','lit':True} for i in (1,2,3)]}),1)
    demand(events(noflames,'game_over')[0]['reason']=='no_flames','no_flames must take precedence')
    print('PASS: dawn win ratio and no_flames precedence')
    paused=run(scenario({'lanterns':[{'id':'L1','lit':True}]}),4,{'frames':[{'tick':0,'pause':True}]})
    demand(last(paused)['sim_tick']==0 and last(paused)['lanterns'][0]['fuel']==100,'pause should freeze simulation and fuel')
    print('PASS: paused ticks do not consume lantern fuel')
    x=run(scenario({'lanterns':[{'id':'L1','lit':True}]}),120,snapshot_every=30)
    y=run(scenario({'lanterns':[{'id':'L1','lit':True}]}),120,snapshot_every=30)
    demand(x==y,'non-deterministic output')
    print('PASS: deterministic headless JSONL')
    print('PASS: Phase 3 Ticket-03 regression smoke tests')

if __name__=='__main__':
    try: main()
    except (AssertionError, subprocess.TimeoutExpired, OSError, ValueError) as e:
        print('FAIL:',e,file=sys.stderr)
        sys.exit(1)
