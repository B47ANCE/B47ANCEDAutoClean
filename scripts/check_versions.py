#!/usr/bin/env python3
"""Read-only, dependency-free validation of explicitly inventoried project versions."""
import argparse
import json
import ntpath
from pathlib import Path
import re
import string
import zipfile

CORE = r'(0|[1-9][0-9]*)'
SEMVER = re.compile(
    rf'(?P<major>{CORE})\.(?P<minor>{CORE})\.(?P<patch>{CORE})'
    r'(?:-(?P<prerelease>[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?'
    r'(?:\+(?P<build>[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?'
)

def semver(value):
    match = SEMVER.fullmatch(value)
    if not match:
        raise ValueError('invalid SemVer: ' + repr(value))
    pre = match.group('prerelease') or ''
    if any(part.isdigit() and len(part) > 1 and part[0] == '0' for part in pre.split('.')):
        raise ValueError('numeric prerelease identifiers cannot have leading zeroes: ' + value)
    return {name: match.group(name) or '' for name in ['major', 'minor', 'patch', 'prerelease', 'build']}

def shape(value, allowed, required, label):
    if not isinstance(value, dict):
        raise ValueError(label + ' must be an object')
    unknown = set(value) - set(allowed)
    missing = set(required) - set(value)
    if unknown or missing:
        raise ValueError(f'{label}: unknown fields {sorted(unknown)}, missing fields {sorted(missing)}')

def relative(root, name):
    if not isinstance(name, str) or not name or ntpath.isabs(name) or '..' in name.replace('\\', '/').split('/'):
        raise ValueError('path must be project-relative without traversal: ' + repr(name))
    result = (root / name).resolve()
    if not result.is_relative_to(root):
        raise ValueError('path escapes project: ' + name)
    return result

def expression(pattern):
    if not isinstance(pattern, str):
        raise ValueError('pattern must be a string')
    compiled = re.compile(pattern, re.MULTILINE)
    if 'version' not in compiled.groupindex:
        raise ValueError('pattern requires a named (?P<version>...) capture')
    return compiled

def representation(spec, version, parts):
    template = spec.get('format', '{version}')
    fields = {'version': version, **parts}
    for _, field, fmt, conversion in string.Formatter().parse(template):
        if field is not None and (field not in fields or fmt or conversion):
            raise ValueError('format permits only plain version/major/minor/patch/prerelease/build fields')
    if template != '{version}' and not spec.get('reason', '').strip():
        raise ValueError('derived external representation requires a reason')
    return template.format(**fields)

def compare(text, spec, expected, label, errors):
    matches = list(expression(spec['pattern']).finditer(text))
    count = spec.get('count', 1)
    if type(count) is not int or count < 1:
        raise ValueError(label + ': count must be a positive integer')
    if len(matches) != count:
        errors.append(f'{label}: expected {count} project-version match(es), found {len(matches)}')
    for match in matches:
        actual = match.group('version')
        if actual != expected:
            errors.append(f'{label}: stale/mismatched project version {actual!r}; expected {expected!r}')

def validate(root, release=False, config_name='version-inventory.json'):
    root = Path(root).resolve()
    report = {'version': None, 'release_check': release, 'errors': [], 'notes': [], 'checked': []}
    errors, notes, checked = report['errors'], report['notes'], report['checked']
    try:
        config = json.loads(relative(root, config_name).read_text(encoding='utf-8'))
        shape(config, ['schema', 'canonical', 'mirrors', 'changelog', 'packaging', 'other_versions', 'historical'],
              ['schema', 'canonical', 'mirrors', 'changelog', 'packaging', 'other_versions', 'historical'], 'inventory')
        if type(config['schema']) is not int or config['schema'] != 1:
            raise ValueError('unsupported inventory schema')
        raw = relative(root, config['canonical']).read_text(encoding='utf-8')
        # Exactly one ASCII version line, optional final newline. No hidden whitespace.
        version = raw.removesuffix('\n').removesuffix('\r')
        parts = semver(version)
        report['version'] = version
        checked.append(config['canonical'])
        if not isinstance(config['mirrors'], list):
            raise ValueError('mirrors must be a list')
        seen = set()
        for mirror in config['mirrors']:
            shape(mirror, ['path', 'pattern', 'count', 'format', 'reason', 'stage'], ['path', 'pattern'], 'mirror')
            path = relative(root, mirror['path'])
            key = (str(path), mirror['pattern'])
            if key in seen or path == relative(root, config['canonical']):
                raise ValueError('duplicate mirror or canonical declared as mirror: ' + mirror['path'])
            seen.add(key)
            stage = mirror.get('stage', 'always')
            if stage not in ['always', 'release']:
                raise ValueError('mirror stage must be always or release')
            expression(mirror['pattern'])
            expected = representation(mirror, version, parts)
            if not path.exists() and stage == 'release' and not release:
                notes.append('Deferred until release: ' + mirror['path'])
                continue
            compare(path.read_text(encoding='utf-8'), mirror, expected, mirror['path'], errors)
            checked.append(mirror['path'])

        log = config['changelog']
        shape(log, ['path', 'pattern'], ['path', 'pattern'], 'changelog')
        content = relative(root, log['path']).read_text(encoding='utf-8')
        entries = list(expression(log['pattern']).finditer(content))
        if not entries:
            errors.append(log['path'] + ': no changelog entries')
        else:
            first = entries[0]
            label = first.group('version')
            allowed = {version}
            if parts['prerelease'] and not release:
                allowed.add('Unreleased')
            if label not in allowed:
                errors.append(f'{log["path"]}: newest entry {label!r} does not cover {version!r}')
            end = entries[1].start() if len(entries) > 1 else len(content)
            if not content[first.end():end].strip():
                errors.append(log['path'] + ': newest changelog entry has no change text')
        checked.append(log['path'])

        packaging = config['packaging']
        shape(packaging, ['artifacts', 'not_applicable_reason'], ['artifacts'], 'packaging')
        if not isinstance(packaging['artifacts'], list):
            raise ValueError('packaging.artifacts must be a list')
        if not packaging['artifacts']:
            if not isinstance(packaging.get('not_applicable_reason'), str) or not packaging['not_applicable_reason'].strip():
                raise ValueError('no artifacts: explicit packaging not_applicable_reason is required')
            notes.append('Packaging N/A: ' + packaging['not_applicable_reason'])
        elif packaging.get('not_applicable_reason'):
            raise ValueError('packaging cannot declare both artifacts and N/A')
        for artifact in packaging['artifacts']:
            shape(artifact, ['glob', 'pattern', 'format', 'reason', 'zip_members'], ['glob', 'pattern'], 'artifact')
            relative(root, artifact['glob'])
            compiled = expression(artifact['pattern'])
            expected = representation(artifact, version, parts)
            matches = sorted(root.glob(artifact['glob']))
            if not matches:
                (errors if release else notes).append('No current package matches ' + artifact['glob'])
            members = artifact.get('zip_members', [])
            if not isinstance(members, list):
                raise ValueError('zip_members must be a list')
            for member in members:
                shape(member, ['member', 'pattern', 'count', 'format', 'reason'], ['member', 'pattern'], 'zip member')
                expression(member['pattern'])
                representation(member, version, parts)
            for path in matches:
                relative(root, str(path.relative_to(root)))
                if not path.is_file():
                    errors.append(str(path.relative_to(root)) + ': artifact is not a file')
                    continue
                match = compiled.fullmatch(path.name)
                if not match:
                    errors.append(path.name + ': package filename does not match declared version pattern')
                elif match.group('version') != expected:
                    errors.append(f'{path.name}: package version {match.group("version")!r}; expected {expected!r}')
                if members:
                    with zipfile.ZipFile(path) as archive:
                        for member in members:
                            data = archive.read(member['member']).decode('utf-8')
                            compare(data, member, representation(member, version, parts), path.name+'!'+member['member'], errors)
                checked.append(str(path.relative_to(root)))

        for name in ['other_versions', 'historical']:
            if not isinstance(config[name], list):
                raise ValueError(name + ' must be a list')
        for item in config['other_versions']:
            shape(item, ['category', 'reference', 'reason'], ['category', 'reference', 'reason'], 'other version')
            if item['category'] not in ['pz', 'dependency', 'framework', 'compatibility', 'inventory-schema', 'project-fixture']:
                raise ValueError('unknown non-project version category')
            if not item['reference'] or not item['reason']:
                raise ValueError('other version needs reference and reason')
        for item in config['historical']:
            shape(item, ['reference', 'reason'], ['reference', 'reason'], 'historical record')
            if not item['reference'] or not item['reason']:
                raise ValueError('historical record needs reference and reason')
        notes.append('Only explicit mirrors checked; review inventory completeness and historical/non-project classifications.')
    except (OSError, ValueError, TypeError, KeyError, re.error, zipfile.BadZipFile) as exc:
        errors.append('Inventory/version validation error: ' + str(exc))
    return report

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--config', default='version-inventory.json')
    parser.add_argument('--release', action='store_true', help='Require current release changelog and all declared artifacts')
    parser.add_argument('--json', action='store_true')
    args = parser.parse_args()
    report = validate(args.root, args.release, args.config)
    if args.json:
        print(json.dumps(report, indent=2))
    else:
        print('Project Version: ' + str(report['version']))
        for error in report['errors']:
            print('FAIL: ' + error)
        for note in report['notes']:
            print('NOTE: ' + note)
        print('Version consistency ' + ('FAIL — G8 BLOCKED' if report['errors'] else 'PASS (version checks only)'))
    return 1 if report['errors'] else 0

if __name__ == '__main__':
    raise SystemExit(main())
