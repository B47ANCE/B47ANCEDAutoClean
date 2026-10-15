"""Read-only Lua-only inventory, dependency, case and public-boundary checks."""
import json
from pathlib import Path
import re

ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'src/B47ANCEDAutoClean'

def validate():
    files={p.relative_to(SOURCE).as_posix():p for p in SOURCE.rglob('*') if p.is_file()}
    assert set(files)==set(json.loads((ROOT/'scripts/production-files.json').read_text(encoding='utf-8')))
    assert len(files)==len({n.casefold() for n in files})
    info=(SOURCE/'42/mod.info').read_text(encoding='utf-8')
    assert re.findall(r'^id=(.*)$',info,re.M)==['B47ANCEDAutoClean']
    assert re.findall(r'^require=(.*)$',info,re.M)==['B47ANCEDQuartermaster,B47ANCEDRooms']
    assert re.findall(r'^modversion=(.*)$',info,re.M)==[(ROOT/'VERSION').read_text().strip()]
    own=SOURCE/'42/media/lua/shared'
    qm=ROOT.parent/'B47ANCEDQuartermaster/src/B47ANCEDQuartermaster/42/media/lua/shared'
    rooms=ROOT.parent/'B47ANCEDRooms/src/B47ANCEDRooms/42/media/lua/shared'
    for name,path in files.items():
        assert not path.is_symlink() and path.suffix.lower() not in {'.java','.class','.jar','.dll','.exe','.py'}
        if path.suffix!='.lua':continue
        text=path.read_text(encoding='utf-8')
        assert 'research/auto-clean' not in text
        assert not re.search(r'B47ANCEDQuartermaster\.(?:Targets|Store|Presets|Movement|Authority)',text),path
        for dep in re.findall(r"require\s*(?:\(\s*)?['\"]([^'\"]+)",text):
            if dep.startswith('B47ANCEDQuartermaster/'):
                assert dep=='B47ANCEDQuartermaster/SupplyAPI',path
            if dep.startswith(('B47ANCEDAutoClean/','B47ANCEDQuartermaster/','B47ANCEDRooms/')):
                assert any((r/(dep+'.lua')).is_file() for r in (own,qm,rooms)),(path,dep)
    print(f'PASS source inventory: {len(files)} files, Lua-only, exact dependencies and public SupplyAPI boundary')
    return files

if __name__=='__main__':validate()
