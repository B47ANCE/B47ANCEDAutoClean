"""Offline building integration using actual Rooms source and installed native Lua."""
import argparse
import hashlib
import json
from pathlib import Path
import runpy
import re
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--game',type=Path,required=True)
p.add_argument('--rooms',type=Path,required=True)
p.add_argument('--report',type=Path)
p.add_argument('--source',action='store_true',help='Exercise activated production modules and startup')
args=p.parse_args()
rooms=args.rooms.resolve()
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
sources=lambda:{p.relative_to(rooms).as_posix():sha(p) for p in sorted((rooms/'src').rglob('*')) if p.is_file()}
rooms_before=sources()
rooms_version=(rooms/'VERSION').read_text().strip()
owned=sorted((ROOT/'research/auto-clean').glob('*.lua'))+[ROOT/'tests/test_auto_clean_building.lua',ROOT/'tests/test_auto_clean_building_click.lua',Path(__file__).resolve()]
owned_before={p.relative_to(ROOT).as_posix():sha(p) for p in owned}
sys.argv=[str(ROOT/'tests/run_auto_clean_transport.py'),'--game',str(args.game)]
if args.source:
    sys.argv.append('--source')
base=runpy.run_path(str(ROOT/'tests/run_auto_clean_transport.py'))
lua=base['lua']
if args.source:
    # Existing gameplay fixtures isolate UI. The dedicated HUD suite loads the
    # production client module and actual vanilla ISProgressBar separately.
    lua.execute("package.preload['B47ANCEDAutoClean/Progress']=function() return {new=function() return {update=function() end,clear=function() end,close=function() end} end} end")
lua.execute("package.path=.....'/src/B47ANCEDRooms/42/media/lua/shared/?.lua;'..package.path",rooms.as_posix())
lua.execute("ItemBodyLocation=setmetatable({},{__index=function(_,k) return k end})")
native={}
for name in ['ISWearClothing','ISTransferAction','ISEquipWeaponAction','ISUnequipAction']:
    source=args.game/'media/lua/shared/TimedActions'/f'{name}.lua'
    native[str(source.relative_to(args.game)).replace('\\','/')]=sha(source)
    lua.execute('dofile(...)',source.as_posix())
    lua.execute('package.loaded[...]=true','TimedActions/'+name)
code=ROOT/'tests/test_auto_clean_building.lua'
groups=lua.execute(code.read_text(encoding='utf-8'))
walk=args.game/'media/lua/client/TimedActions/WalkToTimedAction.lua'
native['media/lua/client/TimedActions/WalkToTimedAction.lua']=sha(walk)
lua.execute('dofile(...)',walk.as_posix())
lua.execute("package.loaded['TimedActions/WalkToTimedAction']=true")
click=ROOT/'tests/test_auto_clean_building_click.lua'
groups+=lua.execute(click.read_text(encoding='utf-8'))
startup_groups=0
if args.source:
    startup_groups=lua.execute((ROOT/'tests/test_auto_clean_startup.lua').read_text(encoding='utf-8'))
    source_lua=ROOT/'src/B47ANCEDAutoClean/42/media/lua'
    production_modules=source_lua/'shared/B47ANCEDAutoClean'
    for module in production_modules.glob('*.lua'):
        source=module.read_text(encoding='utf-8')
        assert 'research/auto-clean/' not in source,module
        assert not re.search(r':(?:addFluid|adjustAmount|removeBlood|removeGrime|AddItem|Remove|forceComplete|setCurrentTime|setTime)\s*\(',source),module
        assert not re.search(r'\b(?:luajava|loadstring)\b',source),module
        lua.execute('assert(loadstring(...))',source)
        for required in re.findall(r"require\s*(?:\(\s*)?['\"]([^'\"]+)",source):
            relative=required+'.lua'
            roots=[source_lua/'shared',source_lua/'client',source_lua/'server',
                   rooms/'src/B47ANCEDRooms/42/media/lua/shared',
                   source_lua/'client',rooms/'src/B47ANCEDRooms/42/media/lua/client',
                   args.game/'media/lua/shared',args.game/'media/lua/client',ROOT.parent/'B47ANCEDQuartermaster/src/B47ANCEDQuartermaster/42/media/lua/shared']
            assert any(relative in {p.relative_to(root).as_posix() for p in root.rglob('*.lua')} for root in roots if root.is_dir()),(module,required)
        if module.stem!='Startup':
            assert lua.eval('function(a,b) return package.loaded[b]~=nil and (package.loaded[a]==nil or package.loaded[a]==package.loaded[b]) end')(
                'research/auto-clean/'+module.stem,'B47ANCEDAutoClean/'+module.stem),module
    declared=json.loads((ROOT/'scripts/production-files.json').read_text(encoding='utf-8'))
    assert len(declared)==len({p.casefold() for p in declared}),'Case-colliding source inventory'
assert rooms_before==sources(),'Rooms source drift during test'
assert rooms_version==(rooms/'VERSION').read_text().strip(),'Rooms version drift during test'
assert base['production']=={p.relative_to(ROOT).as_posix():sha(p) for p in sorted((ROOT/'src').rglob('*')) if p.is_file()},'Quartermaster source drift during building test'
assert owned_before=={p.relative_to(ROOT).as_posix():sha(p) for p in owned},'Research/test drift during execution'
translations=rooms/'src/B47ANCEDRooms/42/media/lua/shared/Translate'
english=json.loads((translations/'EN/UI.json').read_text(encoding='utf-8'))
production_dir=ROOT/'src/B47ANCEDAutoClean/42/media/lua/shared/B47ANCEDAutoClean'
wire=((production_dir if args.source else ROOT/'research/auto-clean')/'BuildingWire.lua').read_text(encoding='utf-8')
for key in re.findall(r"getText\('([^']+)'",wire):
    if key.startswith('UI_B47Rooms_') and not key.endswith('_'):
        assert key in english,key
for key in ['CleaningMissingSupplies','CleaningInsufficientCapacity','CleaningWaterUnavailable','CleaningUnsupportedEquipment','CleaningChanged']:
    assert 'UI_B47Rooms_'+key in english,key
sandbox=json.loads((translations/'EN/Sandbox.json').read_text(encoding='utf-8'))
option_names=['CleanBuildingEnabled','CleaningBorrowSupplies','CleaningReturnSupplies','CleaningBleachML','CleaningBuildingTileLimit','CleaningTransferSeconds']
for path in translations.glob('*/Sandbox.json'):
    actual=json.loads(path.read_text(encoding='utf-8'))
    for option in option_names:
        for suffix in ['', '_tooltip']:
            key='Sandbox_B47ANCEDRooms_'+option+suffix
            assert actual[key]==sandbox[key],(path,key)
files={p.relative_to(ROOT).as_posix():sha(p) for p in sorted((ROOT/'research/auto-clean').glob('*.lua'))}
files.update({p.relative_to(ROOT).as_posix():sha(p) for p in [code,click,Path(__file__).resolve()]})
if args.source:
    path=ROOT/'tests/test_auto_clean_startup.lua';files[path.relative_to(ROOT).as_posix()]=sha(path)
result={**base['report'],'environment':'Lua 5.1; actual Rooms source and native Lua; simulated engine/network/storage/walking and Quartermaster configuration reader',
        'buildingScenarioGroups':groups,'roomsVersionObserved':rooms_version,
 'roomsHeadObserved':subprocess.check_output(['git','-C',str(rooms),'rev-parse','HEAD']).decode().strip() if (rooms/'.git').exists() else None,
        'roomsSources':rooms_before,'buildingNativeSources':native,'buildingFiles':files,
        'simulatedBuildingReceipt':base['base']['plain'](lua.globals().AUTO_CLEAN_BUILDING_RESULT),
        'activation':'Production shared startup and modules; never invoked in PZ' if args.source else 'Offline research installers only; never invoked in PZ',
        'startupScenarioGroups':startup_groups,
        'moduleSource':'production' if args.source else 'research',
        'productionSources':base['production'] if args.source else None,
        'G7':'BLOCKED / NOT TESTED','stableG8':'BLOCKED'}
if args.report:
    args.report.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
print(f'PASS: {groups} building + 23 transport + 31 guard scenarios OFFLINE; Rooms source/native Lua; no native runtime proof')
if args.source:
    print(f'PASS: {startup_groups} production startup scenarios OFFLINE')
