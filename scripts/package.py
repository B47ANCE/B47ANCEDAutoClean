"""Explicit packaging only; never deploys or publishes."""
import hashlib
from pathlib import Path
from pathlib import PurePosixPath
import zipfile
from check_source import ROOT,SOURCE,validate

files=validate();version=(ROOT/'VERSION').read_text().strip()
out=ROOT/'dist/current';out.mkdir(parents=True,exist_ok=True)
archive=out/f'B47ANCEDAutoClean-{version}.zip'
if archive.exists():raise SystemExit('Preserve existing artifact; use a new version or retained staging plan')
directories=['common/','common/media/AnimSets/','common/media/actiongroups/','42/media/AnimSets/','42/media/actiongroups/']
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
    for name in directories:z.writestr('B47ANCEDAutoClean/'+name,b'')
    for name,path in sorted(files.items()):z.writestr('B47ANCEDAutoClean/'+name,path.read_bytes())
with zipfile.ZipFile(archive) as z:
    names=z.namelist();assert len(names)==len(set(names))==len({n.casefold() for n in names})
    assert z.testzip() is None
    for n in names:assert not PurePosixPath(n).is_absolute() and '..' not in PurePosixPath(n).parts and '\\' not in n
    assert {n.removeprefix('B47ANCEDAutoClean/'):z.read(n) for n in names if not n.endswith('/')}=={n:p.read_bytes() for n,p in files.items()}
digest=hashlib.sha256(archive.read_bytes()).hexdigest()
(out/(archive.name+'.sha256')).write_text(digest+'  '+archive.name+'\n',encoding='utf-8')
print(archive,digest)
