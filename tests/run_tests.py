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
subprocess.run([sys.executable,str(ROOT/'scripts/check_versions.py'),'--root',str(ROOT)],check=True)
validate()
qm=ROOT.parent/'B47ANCEDQuartermaster'
assert not list((qm/'src/B47ANCEDQuartermaster/42/media/lua').rglob('AutoClean/*.lua'))
provider=qm/'src/B47ANCEDQuartermaster/42/media/lua/shared/B47ANCEDQuartermaster/SupplyAPI.lua'
before=hashlib.sha256(provider.read_bytes()).hexdigest()
out=ROOT/'dist/validation.json';out.parent.mkdir(exist_ok=True)
subprocess.run([sys.executable,str(ROOT/'tests/run_auto_clean_single_player.py'),'--game',str(args.game),
                '--rooms',str(ROOT.parent/'B47ANCEDRooms'),'--report',str(out)],check=True)
assert before==hashlib.sha256(provider.read_bytes()).hexdigest()
report=json.loads(out.read_text(encoding='utf-8'))
report['quartermasterSupplyApiSha256']=before
report['quartermasterVersionObserved']=(qm/'VERSION').read_text().strip()
report['quartermasterHeadObserved']=subprocess.check_output(['git','-C',str(qm),'rev-parse','HEAD']).decode().strip()
report['offlineScenarioGroups']=sum(report[k] for k in ['guardScenarioGroups','transportScenarioGroups','buildingScenarioGroups','startupScenarioGroups','singlePlayerScenarioGroups'])
report['deployment']='NOT PERFORMED';report['workshopPublication']='NOT PERFORMED'
out.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(f"PASS {report['offlineScenarioGroups']} focused scenarios OFFLINE; exact provider fingerprint; runtime NOT TESTED")
