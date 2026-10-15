"""Isolated Auto Clean regression; reads installed Lua/bytecode, never starts PZ/Java."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import re
import struct
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / '.test-deps'))
from lupa.lua51 import LuaRuntime
from jawa.cf import ClassFile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--game', type=Path, required=True)
parser.add_argument('--report', type=Path)
parser.add_argument('--source', action='store_true', help='Exercise activated production modules instead of research')
args = parser.parse_args()
game = args.game.resolve()
research = ROOT / 'research/auto-clean'
native_paths = [
    'media/lua/shared/Fluids/ISFluidContainer.lua',
    'media/lua/shared/Fluids/ISFluidUtil.lua',
    'media/lua/shared/Fluids/ISFluidTransferAction.lua',
    'media/lua/shared/TimedActions/ISTakeWaterAction.lua',
    'media/lua/shared/TimedActions/ISCleanBlood.lua',
    'media/lua/shared/Defines.lua',
]

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

owned = sorted(research.glob('*.lua')) + [ROOT / 'tests/test_auto_clean_guard.lua', Path(__file__).resolve()]
before = {str(p.relative_to(ROOT)): sha(p) for p in owned}
game_before = {p: sha(game / p) for p in native_paths}
audited = json.loads((ROOT / 'tests/fixtures/auto_clean_native_hashes.json').read_text(encoding='utf-8'))
assert game_before == {p: audited['gameFiles'][p] for p in native_paths}, 'native source differs from prior audit; re-audit first'
jar_sha = sha(game / 'projectzomboid.jar')
assert jar_sha == audited['jarSha256'], 'native JAR differs from prior audit; re-audit first'
lua = LuaRuntime(unpack_returned_tuples=True)
lua.globals().GAME_ROOT = game.as_posix()
lua.globals().F32 = lambda n: struct.unpack('<f', struct.pack('<f', n))[0]
defines = (game / native_paths[-1]).read_text(encoding='utf-8-sig')
clean_amount = float(re.search(r'CleanBloodBleachAmount\s*=\s*([\d.]+)', defines)[1])
lua.globals().ZomboidGlobals = lua.table_from({'CleanBloodBleachAmount': clean_amount})
lua.execute("package.path=.....'/?.lua;'..package.path", ROOT.as_posix())
quartermaster=ROOT.parent/'B47ANCEDQuartermaster'
assert (quartermaster/'src/B47ANCEDQuartermaster/42/media/lua/shared/B47ANCEDQuartermaster/SupplyAPI.lua').is_file(),'Quartermaster SupplyAPI checkout required'
lua.execute("package.path=.....'/?.lua;'..package.path",(quartermaster/'src/B47ANCEDQuartermaster/42/media/lua/shared').as_posix())
if args.source:
    production_lua = ROOT / 'src/B47ANCEDAutoClean/42/media/lua/shared'
    lua.execute("package.path=.....'/?.lua;'..package.path", production_lua.as_posix())
    for module in research.glob('*.lua'):
        lua.execute("local alias,target=...;package.preload[alias]=function() return require(target) end",
                    'research/auto-clean/' + module.stem, 'B47ANCEDAutoClean/' + module.stem)
lua.execute("package.preload['ISBaseObject']=function() return ISBaseObject end; package.preload['TimedActions/ISBaseTimedAction']=function() return ISBaseTimedAction end")
for path in owned:
    if path.suffix == '.lua':
        lua.execute('assert(loadstring(...))', path.read_text(encoding='utf-8'))
groups = lua.execute((ROOT / 'tests/test_auto_clean_guard.lua').read_text(encoding='utf-8'))
def plain(value):
    if not hasattr(value, 'items'):
        return value
    values = dict(value.items())
    if values and all(isinstance(k, int) for k in values) and sorted(values) == list(range(1, len(values) + 1)):
        return [plain(values[k]) for k in sorted(values)]
    return {str(k): plain(v) for k, v in values.items()}

# Narrow follow-up evidence for the stricter footprint/source boundary and sender limit.
methods = {
    'zombie/iso/IsoCell': ['getMinZ', 'getMaxZ', 'getGridSquare'],
    'zombie/iso/IsoObject': ['getUsesExternalWaterSource', 'isExistInTheWorld', 'getObjectIndex', 'getFluidAmount'],
    'zombie/network/PZNetKahluaTableImpl': ['loadIsoGameCharacter'],
    'zombie/network/fields/character/PlayerID': ['parsePlayer'],
}
classes = {}
with zipfile.ZipFile(game / 'projectzomboid.jar') as archive:
    for name, wanted in methods.items():
        member = name + '.class'
        loose = game / member
        data = loose.read_bytes() if loose.exists() else archive.read(member)
        cf = ClassFile(io.BytesIO(data))
        found = [(m.name.value, m.descriptor.value) for m in cf.methods if m.name.value in wanted]
        assert set(wanted) <= {n for n, _ in found}, name
        classes[member] = {'sha256': hashlib.sha256(data).hexdigest(),
                           'source': 'loose' if loose.exists() else 'jar', 'methods': found}

# Prove experiment code is outside the production inventory and registers no runtime ingress.
for path in (research / name for name in ('Guard.lua', 'NativePort.lua', 'Poc.lua')):
    source = path.read_text(encoding='utf-8')
    for pattern in (r'Events\.', r'sendClientCommand\s*\(', r'sendServerCommand\s*\(',
                    r':(?:addFluid|adjustAmount|removeBlood|removeGrime|AddItem|Remove)\s*\(',
                    r"require\s*['\"][^'\"]*(?:B47ANCEDRooms|B47ANCEDQuartermaster)/"):
        assert not re.search(pattern, source), (path, pattern)
production_inventory = (ROOT / 'scripts/production-files.json').read_text(encoding='utf-8')
assert 'research/auto-clean' not in production_inventory
assert before == {str(p.relative_to(ROOT)): sha(p) for p in owned}, 'experiment changed during execution'
assert game_before == {p: sha(game / p) for p in native_paths}, 'native source changed during execution'
report = {
    'projectVersionObserved': (ROOT / 'VERSION').read_text().strip(),
    'headObserved': (subprocess.run(['git','-C',str(ROOT),'rev-parse','--verify','HEAD'],capture_output=True,text=True).stdout.strip() or None),
    'environment': 'Lua 5.1 host; installed vanilla Lua callbacks; simulated engine/fluids/network',
    'scenarioGroups': groups, 'result': 'PASS OFFLINE',
    'files': before, 'nativeSources': game_before, 'jarSha256': jar_sha, 'nativeClasses': classes,
    'simulatedPoc': plain(lua.globals().AUTO_CLEAN_POC_RESULT),
    'nativeExecution': 'NOT TESTED', 'G7': 'BLOCKED / NOT TESTED', 'stableG8': 'BLOCKED',
    'runtimeIngress': 'Production startup selects guarded native transport' if args.source else 'NONE; per-instance wrappers must not be serialized as native network actions',
}
if args.report:
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(f'PASS: {groups} offline scenario groups; syntax, native API signatures and isolation checks')
