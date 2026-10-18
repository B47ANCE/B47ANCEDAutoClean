"""Clean Area tests over actual Auto Clean, Rooms, and installed Lua; no game launch."""
import argparse
import hashlib
import json
from pathlib import Path
import runpy
import re
import shutil
import subprocess
import sys
import tempfile

ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser()
p.add_argument('--game',type=Path,default=Path('E:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid'))
p.add_argument('--rooms',type=Path,default=ROOT.parent/'B47ANCEDRooms')
p.add_argument('--report',type=Path,default=ROOT/'dist/clean-area-validation.json')
p.add_argument('--skip-published-compat',action='store_true',help='Internal: prevent recursion in isolated published-provider validation')
args=p.parse_args()
sys.argv=[str(ROOT/'tests/run_auto_clean_single_player.py'),'--game',str(args.game),'--rooms',str(args.rooms)]
base=runpy.run_path(str(ROOT/'tests/run_auto_clean_single_player.py'))
lua=base['base']['lua']
from audit_trash_api import audit,audit_actions
from audit_progress_ui import audit as audit_progress
trash_evidence=audit(args.game)
vanilla_trash_evidence=audit_actions(args.game)
progress_evidence=audit_progress(args.game)
for name in ['TimedActions/ISPickUpGroundCoverItem','TimedActions/ISClearAshes','Util/BuildingHelper']:
    lua.execute('dofile(...)',(args.game/'media/lua/shared'/f'{name}.lua').as_posix())
    lua.execute('package.loaded[...]=true',name)
lua.execute("package.path=.....'/src/B47ANCEDRooms/42/media/lua/client/?.lua;'..package.path",args.rooms.as_posix())
lua.execute("package.path=.....'/src/B47ANCEDAutoClean/42/media/lua/client/?.lua;'..package.path",ROOT.as_posix())
area=lua.execute((ROOT/'tests/test_clean_area.lua').read_text(encoding='utf-8'))
trash=lua.execute((ROOT/'tests/test_trash.lua').read_text(encoding='utf-8'))
lua.globals().PROGRESS_TRANSLATIONS=lua.table_from(json.loads((ROOT/'src/B47ANCEDAutoClean/42/media/lua/shared/Translate/EN/UI.json').read_text(encoding='utf-8')))
progress=lua.execute((ROOT/'tests/test_progress.lua').read_text(encoding='utf-8'))
selector=lua.execute((ROOT/'tests/test_clean_area_selector.lua').read_text(encoding='utf-8'))
published=Path.home()/'Tools/SteamCMD/steamapps/workshop/content/108600/3820077442/mods/B47ANCEDRooms/42'
compat=0
published_version=None
if not args.skip_published_compat and (published/'media/lua/client/B47ANCEDRooms/Editor.lua').is_file():
    # A published provider can differ from its development checkout. Execute its
    # complete actual API/editor in a fresh Lua process, never mix old editor and
    # new API modules or treat differing source hashes as runtime incompatibility.
    before={p.relative_to(published).as_posix():hashlib.sha256(p.read_bytes()).hexdigest()
            for p in published.rglob('*') if p.is_file()}
    published_version=re.search(r'^modversion=(.+)$',(published/'mod.info').read_text(encoding='utf-8'),re.M).group(1)
    with tempfile.TemporaryDirectory(prefix='autoclean-published-rooms-') as temporary:
        provider=Path(temporary)/'B47ANCEDRooms'
        shutil.copytree(published,provider/'src/B47ANCEDRooms/42')
        (provider/'VERSION').write_text(published_version+'\n',encoding='utf-8')
        report=ROOT/'dist/published-rooms-compatibility.json'
        subprocess.run([sys.executable,str(Path(__file__).resolve()),'--game',str(args.game),
                        '--rooms',str(provider),'--report',str(report),'--skip-published-compat'],check=True)
        observed=json.loads(report.read_text(encoding='utf-8'))
        compat=observed['selectorScenarioGroups']
    assert before=={p.relative_to(published).as_posix():hashlib.sha256(p.read_bytes()).hexdigest()
                    for p in published.rglob('*') if p.is_file()},'Published provider source drift during test'
result={**base['result'],'cleanAreaScenarioGroups':area,'trashScenarioGroups':trash,
        'progressScenarioGroups':progress,
        'progressUiEvidence':progress_evidence,
        'trashApiEvidence':trash_evidence,
        'vanillaTrashActionEvidence':vanilla_trash_evidence,
        'selectorScenarioGroups':selector,
        'publishedRoomsSelectorScenarioGroups':compat,
        'publishedRoomsVersionObserved':published_version,
        'publishedRoomsSelectorSourceSha256':hashlib.sha256((published/'media/lua/client/B47ANCEDRooms/Editor.lua').read_bytes()).hexdigest() if compat else None,
        'areaEnvironment':'actual Auto Clean and Rooms sources; native Lua actions; simulated engine/network/pathfinding, NO PZ runtime',
        'sourceSha256':{p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in (ROOT/'src').rglob('*') if p.is_file()}}
args.report.parent.mkdir(parents=True,exist_ok=True)
args.report.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
print(f'PASS {area+selector} Clean Area/selector scenarios and {compat} published Rooms compatibility checks plus existing production regression OFFLINE')
