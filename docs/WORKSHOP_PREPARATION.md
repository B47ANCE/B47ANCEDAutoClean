# First standalone Workshop candidate

Project Version: 0.1.0-dev.1

This is publication metadata and tooling for the existing tested development
version; there is no Lua behavior, protocol, dependency or schema change.
Canonical player-facing inputs are docs/WORKSHOP_DESCRIPTION.md and
docs/WORKSHOP_CHANGELOG.md. scripts/prepare_workshop.py renders the former using
the installed team renderer and writes only new dist staging. It never uploads.

Validated commands (configured Python with Lupa and read-only installed game):

- python scripts/check_versions.py --root .
- python tests/run_tests.py
- python scripts/package.py
- python scripts/check_versions.py --root . --release
- python scripts/prepare_workshop.py --output dist/workshop-candidate-20261015

104 focused scenarios PASS offline. Source inventory: 16 files. ZIP members,
CRC, source bytes, paths and filename case checked. Generated candidate binds
the exact Git commit, package SHA-256, native build and validation report hash.
Adjacent Quartermaster 0.11.0-dev.1 full Build-Workshop.ps1 validation passed,
including 30 supply API scenarios and 131-file source/package/staging parity.

The user explicitly authorized creation and public distribution on 2026-10-15.
SteamCMD successfully created Auto Clean item 3820151540. Both Quartermaster
3807217050 and Rooms 3820077442 were set and visibly verified as required items.
The original zero-ID candidate and first-upload evidence are preserved under
dist/workshop-candidate-20261015. Subsequent preparation uses the assigned ID,
never another zero-ID request. Quartermaster retains its existing item and
visibility. No Rooms update is necessary for this split. No local deployment or
game/server launch is part of this operation.

Actual SP and dedicated acceptance remain NOT TESTED. G7 and stable G8 BLOCKED.
The authorized Workshop test-build exception does not change these gates.
