"""Read-only installed API evidence. Parses bytes; never executes Java or PZ."""
import hashlib
import io
import json
from pathlib import Path
import re
import zipfile


def audit(game,record=False):
    from jawa.cf import ClassFile
    paths=['media/lua/shared/Foraging/forageSystem.lua',
           'media/lua/server/Map/MapObjects/MOFeedingTrough.lua',
           'media/lua/server/Map/MapObjects/MOHutch.lua',
           'media/lua/shared/TimedActions/ISPickUpGroundCoverItem.lua',
           'media/lua/shared/Moveables/ISMoveableSpriteProps.lua']
    fingerprints={p:hashlib.sha256((game/p).read_bytes()).hexdigest() for p in paths}
    forage=(game/paths[0]).read_text(encoding='utf-8-sig')
    names=set(re.findall(r'"([^"]+)"',re.search(r'\btrash\s*=\s*\{([^}]+)',forage)[1]))
    assert names=={f'd_trash_{i}' for i in range(26)}|{f'trash_01_{i}' for i in [*range(13),*range(16,54)]}
    assert len(names)==77
    for path in paths[1:3]:
        assert re.search(r':transmitRemoveItemFromSquare\([^,\n]+,\s*false\)',(game/path).read_text(encoding='utf-8-sig'))
    assert ':getSpriteGrid()' in (game/paths[4]).read_text(encoding='utf-8-sig')
    wanted={'zombie/iso/IsoGridSquare':{'transmitRemoveItemFromSquare'},
            'zombie/network/GameServer':{'RemoveItemFromMap'}}
    rows={};contracts={}
    with zipfile.ZipFile(game/'projectzomboid.jar') as archive:
        for name,methods in wanted.items():
            member=name+'.class';loose=game/member
            data=loose.read_bytes() if loose.exists() else archive.read(member)
            cf=ClassFile(io.BytesIO(data));metadata={}
            for method in cf.methods:
                if method.name.value not in methods:continue
                rr=[]
                for ins in method.code.disassemble():
                    values=[]
                    for operand in ins.operands:
                        if getattr(getattr(operand,'op_type',None),'name',None)=='CONSTANT_INDEX':
                            c=cf.constants.get(operand.value)
                            values.append(c.class_.name.value+'.'+c.name_and_type.name.value+':'+c.name_and_type.descriptor.value if hasattr(c,'class_') else str(c))
                        else:values.append(operand.value)
                    rr.append([ins.pos,ins.mnemonic,values])
                key=method.name.value+method.descriptor.value;rows[name+'.'+key]=rr
                metadata[key]=hashlib.sha256(json.dumps(rr,separators=(',',':')).encode()).hexdigest()
            contracts[member]={'sha256':hashlib.sha256(data).hexdigest(),'origin':'loose' if loose.exists() else 'jar','methods':metadata}
    square='zombie/iso/IsoGridSquare.transmitRemoveItemFromSquare'
    rr=rows[square+'(Lzombie/iso/IsoObject;Z)I'];at={p:(op,args) for p,op,args in rr}
    assert at[30]==('iload_2',[]) and at[31]==('ifeq',[94]) # loose class: false -> 125, bypass multi-part expansion
    assert at[126][1]==['zombie/network/GameServer.RemoveItemFromMap:(Lzombie/iso/IsoObject;)I']
    assert at[25]==('iload_2',[]) and at[26][1]==['zombie/iso/IsoGridSquare.RemoveTileObject:(Lzombie/iso/IsoObject;Z)I']
    send=rows['zombie/network/GameServer.RemoveItemFromMap(Lzombie/iso/IsoObject;)I']
    refs=[v for _,_,args in send for v in args if isinstance(v,str)]
    assert any('INetworkPacket.sendToRelative:' in v for v in refs)
    assert any('RemoveItemFromSquarePacket.removeItemFromMap:' in v for v in refs)
    result={'gameVersion':'42.21.0','steamBuild':'25485521','runtime':'NOT TESTED',
            'sourceSha256':fingerprints,'jarSha256':hashlib.sha256((game/'projectzomboid.jar').read_bytes()).hexdigest(),
            'nativeContracts':contracts,'trashSpriteCount':len(names)}
    expected=Path(__file__).parent/'fixtures/trash_api_25485521.json'
    if record:
        expected.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    assert result==json.loads(expected.read_text(encoding='utf-8')),'Trash API evidence changed; re-audit before use'
    return result
