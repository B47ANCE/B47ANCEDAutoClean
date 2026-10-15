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

No upload or deployment has occurred. Auto Clean has no assigned Workshop ID.
The zero-ID VDF is an inspectable creation candidate and must not be submitted
without explicit new-item approval. The paired Quartermaster update remains
held so embedded cleaning is not removed before the separate item is available.
On approval, set Quartermaster and Rooms as required Workshop items in addition
to the existing mod.info dependencies. Preserve Quartermaster's existing item
and visibility. No Rooms update is necessary for this split.

Actual SP and dedicated acceptance remain NOT TESTED. G7 and stable G8 BLOCKED.
The authorized Workshop test-build exception does not change these gates.
