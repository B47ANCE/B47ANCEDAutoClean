"""Offline native transport contracts and Lua reconstruction tests. Never runs Java/PZ."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import re
import runpy
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--game', type=Path, required=True)
parser.add_argument('--report', type=Path)
parser.add_argument('--source', action='store_true', help='Exercise activated production modules')
args = parser.parse_args()
game = args.game.resolve()

def sha(data):
    return hashlib.sha256(data).hexdigest()

paths = sorted((ROOT / 'research/auto-clean').glob('*.lua')) + [
    ROOT / 'tests/test_auto_clean_guard.lua', ROOT / 'tests/test_auto_clean_transport.lua',
    ROOT / 'tests/run_auto_clean_guard.py', Path(__file__).resolve(),
]
before = {p.relative_to(ROOT).as_posix(): sha(p.read_bytes()) for p in paths}
production = {p.relative_to(ROOT).as_posix(): sha(p.read_bytes()) for p in sorted((ROOT / 'src').rglob('*')) if p.is_file()}
version_before = (ROOT / 'VERSION').read_text().strip()
sys.argv = [str(ROOT / 'tests/run_auto_clean_guard.py'), '--game', str(game)]
if args.source:
    sys.argv.append('--source')
base = runpy.run_path(str(ROOT / 'tests/run_auto_clean_guard.py'))
lua = base['lua']
from jawa.cf import ClassFile

def rows(cf, method):
    result = []
    for ins in method.code.disassemble():
        operands = []
        for operand in ins.operands:
            if not hasattr(operand, 'op_type'):
                operands.append(str(operand))
            elif operand.op_type.name == 'CONSTANT_INDEX':
                c = cf.constants.get(operand.value)
                if hasattr(c, 'class_'):
                    operands.append(c.class_.name.value + '.' + c.name_and_type.name.value + ':' + c.name_and_type.descriptor.value)
                elif hasattr(c, 'string'):
                    operands.append(c.string.value)
                elif hasattr(c, 'name'):
                    operands.append(c.name.value)
                else:
                    operands.append(str(c))
            else:
                operands.append(operand.value)
        result.append([ins.pos, ins.mnemonic, operands])
    return result

contracts = {}
wanted = {
    'zombie/network/GameServer': ['receiveClientCommand', 'getPlayerFromConnection', 'getAnyPlayerFromConnection'],
    'zombie/core/NetTimedAction': ['set', 'parse', 'copyFrom', 'start', 'getDuration', 'getAdjustedDuration', 'perform', 'update'],
    'zombie/core/ActionManager': ['start', 'update'],
    'zombie/core/Action': ['parse', 'setTimeData', 'getProgress'],
    'zombie/network/packets/NetTimedActionPacket': ['getAction', 'processServer'],
    'zombie/characters/CharacterTimedActions/LuaTimedActionNew': ['start', 'update'],
    'zombie/network/fields/character/PlayerID': ['parsePlayer'],
    'zombie/Lua/LuaManager$Exposer': ['exposeAll'],
}
all_rows = {}
with zipfile.ZipFile(game / 'projectzomboid.jar') as archive:
    for name, methods in wanted.items():
        member = name + '.class'
        loose = game / member
        data = loose.read_bytes() if loose.exists() else archive.read(member)
        cf = ClassFile(io.BytesIO(data))
        entries = {}
        for method in cf.methods:
            if method.name.value in methods:
                key = method.name.value + method.descriptor.value
                rr = rows(cf, method)
                all_rows[name + '.' + key] = rr
                entries[key] = {'instructionSha256': sha(json.dumps(rr, separators=(',', ':')).encode()),
                                'instructionCount': len(rr)}
        assert set(methods) <= {m.name.value for m in cf.methods}, name
        contracts[member] = {'sha256': sha(data), 'source': 'loose' if loose.exists() else 'jar', 'methods': entries}

def method(name, short, descriptor=None):
    found = [v for k, v in all_rows.items() if k.startswith(name + '.' + short + '(') and (descriptor is None or k == name + '.' + short + descriptor)]
    assert len(found) == 1, (name, short)
    return found[0]

def refs(rr):
    return [operand for _, _, operands in rr for operand in operands if isinstance(operand, str)]

server = 'zombie/network/GameServer'
receive = method(server, 'receiveClientCommand')
at = {pos: (op, operands) for pos, op, operands in receive}
assert at[64] == ('aload_1', []) and at[65] == ('iload_3', [])
assert at[66][1][0].startswith(server + '.getPlayerFromConnection:') and at[69] == ('astore', [8])
assert at[76] == ('aload_1', []) and at[77][1][0].startswith(server + '.getAnyPlayerFromConnection:')
assert at[80] == ('astore', [8]) and at[217] == ('ldc_w', ['OnClientCommand'])
assert at[224] == ('aload', [8]) and at[226] == ('aload', [7]) and 'LuaEventManager.triggerEvent:' in at[228][1][0]
for name in wanted[server]:
    rr = method(server, name)
    assert not any('IDToPlayerMap' in r for r in refs(rr))
    if name != 'receiveClientCommand':
        assert any('IConnection.getPlayerAt:' in r for r in refs(rr))

net = 'zombie/core/NetTimedAction'
set_rows = method(net, 'set', '(Lzombie/characters/IsoPlayer;Lse/krka/kahlua/vm/KahluaTable;)V')
assert 'new' in refs(set_rows)  # Other field names come from the fixed Lua prototype.
for marker in ('prototype', 'numParams', 'locvars'):
    assert any(marker in r for r in refs(set_rows))
parse = method(net, 'parse')
assert 'netAction' in refs(parse) and any('LuaReturn.getFirst:' in r for r in refs(parse))
packet = 'zombie/network/packets/NetTimedActionPacket'
get_action = refs(method(packet, 'getAction'))
assert any('copyFrom:' in r for r in get_action) and not any('LuaCaller' in r for r in get_action)
assert 'netAction' in refs(method(net, 'copyFrom', '(Lzombie/core/NetTimedAction;)V'))
process = refs(method(packet, 'processServer'))
assert any('ActionManager.start:' in r for r in process) and any('ActionManager.stopPlayerActions:' in r for r in process)
assert len(method(net, 'update')) == 1  # dedicated native update has no Lua callback
exposed = refs(method('zombie/Lua/LuaManager$Exposer', 'exposeAll'))
assert 'zombie/core/NetTimedAction' in exposed and 'zombie/core/ActionManager' not in exposed
assert any('IDToPlayerMap' in r for r in refs(method('zombie/network/fields/character/PlayerID', 'parsePlayer')))
assert 'getDuration' in refs(method(net, 'getDuration'))
assert 'adjustMaxTime' in refs(method(net, 'getAdjustedDuration'))
assert 'serverStart' in refs(method(net, 'start')) and any('setTimeData:' in r for r in refs(method(net, 'start')))
clock = refs(method('zombie/core/Action', 'setTimeData'))
assert any('GameTime.getServerTimeMills:' in r for r in clock) and any('Action.getDuration:' in r for r in clock)
client_start = refs(method('zombie/characters/CharacterTimedActions/LuaTimedActionNew', 'start'))
client_update = refs(method('zombie/characters/CharacterTimedActions/LuaTimedActionNew', 'update'))
assert any('setWaitForFinished:' in r for r in client_start) and any('createNetTimedAction:' in r for r in client_start)
assert any('ActionManager.isDone:' in r for r in client_update) and any('ActionManager.isRejected:' in r for r in client_update)

module_dir = ROOT / ('src/B47ANCEDAutoClean/42/media/lua/shared/B47ANCEDAutoClean' if args.source else 'research/auto-clean')
action_source = (module_dir / 'NativeAction.lua').read_text()
assert re.search(r'function class:new\(character, operation, phase, grant\)', action_source)
for p in paths:
    if p.suffix == '.lua':
        lua.execute('assert(loadstring(...))', p.read_text(encoding='utf-8'))
    if p.parent.name == 'auto-clean' and p.suffix == '.lua':
        src = p.read_text(encoding='utf-8')
        assert not re.search(r':(?:addFluid|adjustAmount|removeBlood|removeGrime|AddItem|Remove)\s*\(', src), p
        if p.name != 'BuildingWire.lua':
            assert not re.search(r"require\s*['\"][^'\"]*(?:B47ANCEDRooms|B47ANCEDQuartermaster)/", src), p
        assert not re.search(r':(?:forceComplete|setCurrentTime|setTime)\s*\(', src), p

# Exercise actual vanilla metatable inheritance and the raw callback fields used by Java.
# The earlier guard suite deliberately used a minimal base-action double.
extra_native = ['media/lua/shared/ISBaseObject.lua', 'media/lua/shared/TimedActions/ISBaseTimedAction.lua']
extra_hashes = {p: sha((game / p).read_bytes()) for p in extra_native}
for p in extra_native + base['native_paths'][:5]:
    lua.execute('dofile(...)', (game / p).as_posix())
groups = lua.execute((ROOT / 'tests/test_auto_clean_transport.lua').read_text(encoding='utf-8'))
assert extra_hashes == {p: sha((game / p).read_bytes()) for p in extra_native}, 'base Lua changed during run'
assert before == {p.relative_to(ROOT).as_posix(): sha(p.read_bytes()) for p in paths}, 'research/test drift during run'
assert production == {p.relative_to(ROOT).as_posix(): sha(p.read_bytes()) for p in sorted((ROOT / 'src').rglob('*')) if p.is_file()}, 'concurrent production drift during run'
assert version_before == (ROOT / 'VERSION').read_text().strip(), 'version changed during run'
report = {
    'projectVersionObserved': version_before,
    'headObserved': (subprocess.run(['git','-C',str(ROOT),'rev-parse','--verify','HEAD'],capture_output=True,text=True).stdout.strip() or None),
    'environment': 'Lua 5.1; actual installed native Lua callbacks; simulated network, scheduling, world and fluid storage; Java bytecode parsed only',
    'result': 'PASS OFFLINE', 'guardScenarioGroups': base['groups'], 'transportScenarioGroups': groups,
    'files': before, 'nativeSources': {**base['game_before'], **extra_hashes}, 'jarSha256': base['jar_sha'],
    'transportNativeContracts': contracts,
    'guardNativeClasses': base['classes'],
    'productionFiles': len(production), 'productionHashMapSha256': sha(json.dumps(production, sort_keys=True, separators=(',', ':')).encode()),
    'productionDriftDuringTest': False,
    'simulatedPoc': base['plain'](lua.globals().AUTO_CLEAN_TRANSPORT_RESULT),
    'senderBinding': 'Source: native OnClientCommand player from actual connection; offline: cross-actor confirmation refused. Raw timed-action packet sender NOT proven.',
    'activation': 'Production startup/modules; native execution NOT TESTED' if args.source else 'Inert research; explicit installers exist but never invoked in PZ',
    'nativeExecution': 'NOT TESTED', 'G7': 'BLOCKED / NOT TESTED', 'stableG8': 'BLOCKED',
}
if args.report:
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(f'PASS: {base["groups"]} guard + {groups} transport scenario groups; native command sender/reconstruction source contracts; ' + ('production modules' if args.source else 'inert installation'))
