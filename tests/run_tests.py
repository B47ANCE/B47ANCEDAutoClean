"""Offline extraction validation. No packaging, deployment, game launch or upload."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'scripts'))
from check_source import validate
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--game',type=Path,default=Path('E:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid'))
args=p.parse_args()
version_gate=subprocess.run([sys.executable,str(ROOT/'scripts/check_versions.py'),'--root',str(ROOT)])
validate()
qm=ROOT.parent/'B47ANCEDQuartermaster'
assert not list((qm/'src/B47ANCEDQuartermaster/42/media/lua').rglob('AutoClean/*.lua'))
provider=qm/'src/B47ANCEDQuartermaster/42/media/lua/shared/B47ANCEDQuartermaster/SupplyAPI.lua'
before=hashlib.sha256(provider.read_bytes()).hexdigest()
out=ROOT/'dist/validation.json';out.parent.mkdir(exist_ok=True)
subprocess.run([sys.executable,str(ROOT/'tests/run_clean_area.py'),'--game',str(args.game),
                '--rooms',str(ROOT.parent/'B47ANCEDRooms'),'--report',str(out)],check=True)
assert before==hashlib.sha256(provider.read_bytes()).hexdigest()
report=json.loads(out.read_text(encoding='utf-8'))
report['quartermasterSupplyApiSha256']=before
report['quartermasterVersionObserved']=(qm/'VERSION').read_text().strip()
report['quartermasterHeadObserved']=subprocess.check_output(['git','-C',str(qm),'rev-parse','HEAD']).decode().strip()
report['offlineScenarioGroups']=sum(report[k] for k in ['guardScenarioGroups','transportScenarioGroups','buildingScenarioGroups','startupScenarioGroups','singlePlayerScenarioGroups','cleanAreaScenarioGroups','selectorScenarioGroups'])
report['offlineScenarioGroups']+=report.get('publishedRoomsSelectorScenarioGroups',0)
report['offlineScenarioGroups']+=report['trashScenarioGroups']
report['versionGate']='PASS' if version_gate.returncode==0 else 'BLOCKED (see version checker output)'
report['deployment']='NOT PERFORMED';report['workshopPublication']='NOT PERFORMED'
out.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(f"PASS {report['offlineScenarioGroups']} focused scenarios OFFLINE; exact provider fingerprint; runtime NOT TESTED")
if version_gate.returncode:
    raise SystemExit('BLOCKED version/artifact gate; offline scenario results above do not waive it')
