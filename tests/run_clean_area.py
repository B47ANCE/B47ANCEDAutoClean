"""Clean Area tests over actual Auto Clean, Rooms, and installed Lua; no game launch."""
import argparse
import hashlib
import json
from pathlib import Path
import runpy
import sys

ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser()
p.add_argument('--game',type=Path,default=Path('E:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid'))
p.add_argument('--rooms',type=Path,default=ROOT.parent/'B47ANCEDRooms')
p.add_argument('--report',type=Path,default=ROOT/'dist/clean-area-validation.json')
args=p.parse_args()
sys.argv=[str(ROOT/'tests/run_auto_clean_single_player.py'),'--game',str(args.game),'--rooms',str(args.rooms)]
base=runpy.run_path(str(ROOT/'tests/run_auto_clean_single_player.py'))
lua=base['base']['lua']
lua.execute("package.path=.....'/src/B47ANCEDRooms/42/media/lua/client/?.lua;'..package.path",args.rooms.as_posix())
lua.execute("package.path=.....'/src/B47ANCEDAutoClean/42/media/lua/client/?.lua;'..package.path",ROOT.as_posix())
area=lua.execute((ROOT/'tests/test_clean_area.lua').read_text(encoding='utf-8'))
selector=lua.execute((ROOT/'tests/test_clean_area_selector.lua').read_text(encoding='utf-8'))
published=Path.home()/'Tools/SteamCMD/steamapps/workshop/content/108600/3820077442/mods/B47ANCEDRooms/42'
compat=0
if (published/'media/lua/client/B47ANCEDRooms/Editor.lua').is_file():
    for name in ['shared/B47ANCEDRooms/API.lua','shared/B47ANCEDRooms/Geometry.lua',
                 'shared/B47ANCEDRooms/Cleaning.lua','client/B47ANCEDRooms/Draft.lua']:
        assert (published/'media/lua'/name).read_bytes()==(args.rooms/'src/B47ANCEDRooms/42/media/lua'/name).read_bytes()
    lua.globals().ROOMS_EDITOR_COMPAT_PATH=(published/'media/lua/client/B47ANCEDRooms/Editor.lua').as_posix()
    compat=lua.execute((ROOT/'tests/test_clean_area_selector.lua').read_text(encoding='utf-8'))
    lua.globals().ROOMS_EDITOR_COMPAT_PATH=None
result={**base['result'],'cleanAreaScenarioGroups':area,
        'selectorScenarioGroups':selector,
        'publishedRoomsSelectorScenarioGroups':compat,
        'publishedRoomsSelectorSourceSha256':hashlib.sha256((published/'media/lua/client/B47ANCEDRooms/Editor.lua').read_bytes()).hexdigest() if compat else None,
        'areaEnvironment':'actual Auto Clean and Rooms sources; native Lua actions; simulated engine/network/pathfinding, NO PZ runtime',
        'sourceSha256':{p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in (ROOT/'src').rglob('*') if p.is_file()}}
args.report.parent.mkdir(parents=True,exist_ok=True)
args.report.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
print(f'PASS {area+selector} Clean Area/selector scenarios and {compat} published Rooms compatibility checks plus existing production regression OFFLINE')
