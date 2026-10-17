"""Offline SP adapter regression: installed Lua base/queue/actions; no game launch."""
import argparse
import hashlib
import json
from pathlib import Path
import runpy
import sys

ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--game',type=Path,required=True)
p.add_argument('--rooms',type=Path,required=True)
p.add_argument('--report',type=Path)
args=p.parse_args()
sys.argv=[str(ROOT/'tests/run_auto_clean_building.py'),'--source','--game',str(args.game),'--rooms',str(args.rooms)]
base=runpy.run_path(str(ROOT/'tests/run_auto_clean_building.py'))
case=ROOT/'tests/test_auto_clean_single_player.lua'
groups=base['lua'].execute(case.read_text(encoding='utf-8'))
result={**base['result'],'singlePlayerScenarioGroups':groups,
        'environment':'Lua 5.1; actual Rooms, installed native Lua base/queue/actions; simulated native engine/pathfinder/world/clock; NO PZ runtime',
        'singlePlayerFiles':{},'SP':'NOT TESTED in PZ','G7':'BLOCKED / NOT TESTED','stableG8':'BLOCKED'}
for name in ['media/lua/shared/TimedActions/ISBaseTimedAction.lua','media/lua/client/TimedActions/ISTimedActionQueue.lua']:
    result['singlePlayerFiles'][name]=hashlib.sha256((args.game/name).read_bytes()).hexdigest()
for file in [case,Path(__file__).resolve()]:
    result['singlePlayerFiles'][file.relative_to(ROOT).as_posix()]=hashlib.sha256(file.read_bytes()).hexdigest()
if args.report:
    args.report.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
total=groups+sum(base['result'][k] for k in ['guardScenarioGroups','transportScenarioGroups','buildingScenarioGroups','startupScenarioGroups'])
print(f'PASS {total} production guard/MP/building/startup/SP scenarios OFFLINE')
