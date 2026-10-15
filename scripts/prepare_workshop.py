"""Prepare inspectable Workshop staging and VDF; never upload, deploy or launch."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import zipfile

from check_source import ROOT, SOURCE, validate


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    output.relative_to((ROOT / 'dist').resolve())
    if output.exists():
        raise SystemExit('Preserve prior staging: select a new output directory')
    files = validate()
    version = (ROOT / 'VERSION').read_text().strip()
    inventory = json.loads((ROOT / 'SOURCE_INVENTORY.json').read_text())
    item = inventory['workshop_id']
    if item is not None and not str(item).isdigit():
        raise SystemExit('Invalid assigned Workshop identity')
    if item is not None:
        assert (ROOT / 'WORKSHOP_ID.txt').read_text().strip() == str(item)
    report = json.loads((ROOT / 'dist/validation.json').read_text(encoding='utf-8'))
    assert report['result'] == 'PASS OFFLINE' and report['projectVersionObserved'] == version
    assert report['offlineScenarioGroups'] >= 190 and report['trashScenarioGroups'] >= 35 and report['progressScenarioGroups'] >= 11 and report['versionGate'] == 'PASS'
    for relative, digest in report['productionSources'].items():
        assert hashlib.sha256((ROOT / relative).read_bytes()).hexdigest() == digest
    provider = ROOT.parent / 'B47ANCEDQuartermaster'
    assert hashlib.sha256((provider / 'src/B47ANCEDQuartermaster/42/media/lua/shared/B47ANCEDQuartermaster/SupplyAPI.lua').read_bytes()).hexdigest() == report['quartermasterSupplyApiSha256']
    archive = ROOT / 'dist/current' / f'B47ANCEDAutoClean-{version}.zip'
    with zipfile.ZipFile(archive) as z:
        assert z.testzip() is None
        assert {n.removeprefix('B47ANCEDAutoClean/'): z.read(n) for n in z.namelist()
                if not n.endswith('/')} == {n: p.read_bytes() for n, p in files.items()}
        z.extractall(output / 'Contents/mods')
    stage = output / 'Contents/mods/B47ANCEDAutoClean'
    assert {p.relative_to(stage).as_posix(): p.read_bytes()
            for p in stage.rglob('*') if p.is_file()} == {n: p.read_bytes() for n, p in files.items()}
    shutil.copyfile(ROOT / 'preview.png', output / 'preview.png')
    renderer = Path.home() / '.codex/b47anced-team/tools/Build-WorkshopDescription.py'
    spec = importlib.util.spec_from_file_location('workshop_renderer', renderer)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    description = module.render((ROOT / 'docs/WORKSHOP_DESCRIPTION.md').read_text(encoding='utf-8'),
                                module.github_url(ROOT))
    # Steam renders h1; its Workshop page leaves the renderer's size tag literal.
    description = description.replace('[size=large][b]', '[h1]').replace('[/b][/size]', '[/h1]')
    note = (ROOT / 'docs/WORKSHOP_CHANGELOG.md').read_text(encoding='utf-8').strip()
    for text in (description, note):
        assert 'MP testing build - dedicated multiplayer NOT TESTED' in text
        assert version in text and '\\n' not in text
    # Match the existing team's conservative uploader limit.
    assert len(description.encode('utf-8')) <= 8000
    (output / 'description.bbcode').write_text(description, encoding='utf-8')
    (output / 'changenote.txt').write_text(note + '\n', encoding='utf-8')
    def escape(text):
        return str(text).replace('\\', '\\\\').replace('"', '\\"').replace('\r\n', '\n').replace('\r', '\n')
    fields = dict(appid='108600', publishedfileid=str(item or 0),
                  contentfolder=str(output / 'Contents'), previewfile=str(output / 'preview.png'),
                  title="B47ANCE'd Auto Clean", description=description, changenote=note)
    # New-item approval is required before submitting the zero-ID candidate.
    vdf = '"workshopitem"\n{\n' + ''.join(f'    "{k}" "{escape(v)}"\n' for k, v in fields.items()) + '}\n'
    # SteamCMD on Windows treats BOM-less non-ASCII VDF text as the local codepage.
    (output / 'candidate.vdf').write_text(vdf, encoding='utf-8-sig')
    commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    manifest = dict(version=version, git_commit=commit, workshop_id=item,
                    new_item_approval_required=item is None, mod_id='B47ANCEDAutoClean',
                    app_id=108600, game_version='42.21.0', steam_build='25485521',
                    package_sha256=hashlib.sha256(archive.read_bytes()).hexdigest(),
                    source_sha256={n: hashlib.sha256(p.read_bytes()).hexdigest() for n, p in files.items()},
                    offline=f"{report['offlineScenarioGroups']} focused scenarios PASS",
                    validation_sha256=hashlib.sha256((ROOT / 'dist/validation.json').read_bytes()).hexdigest(),
                    quartermaster_commit=report['quartermasterHeadObserved'],
                    quartermaster_supply_api_sha256=report['quartermasterSupplyApiSha256'],
                    SP='NOT TESTED', G7='BLOCKED / NOT TESTED', stable_G8='BLOCKED')
    (output / 'release-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(dict(stage=str(output), workshop_id=item, files=len(files),
                          new_item_approval_required=item is None), indent=2))


if __name__ == '__main__':
    main()
