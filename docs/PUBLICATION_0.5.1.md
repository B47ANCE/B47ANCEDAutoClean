# Auto Clean 0.5.1-dev.1 Workshop testing distribution

The user authorized publication on 2026-10-15 to existing Auto Clean item
3820151540, App ID 108600. Canonical inputs are docs/WORKSHOP_DESCRIPTION.md and
docs/WORKSHOP_CHANGELOG.md; root preview.png is the original supplied artwork.
The material description changes from published 0.1.0-dev.1 are Clean Area,
guarded native trash/broom cleanup, two progress bars, and the custom thumbnail.
Required Workshop items remain Quartermaster 3807217050 and Rooms 3820077442.
Mod ID, visibility, dependencies, runtime source, authority and native guards
remain unchanged by publication preparation. Version stays 0.5.1-dev.1 because
this packages the already recorded development iteration without new behavior.

The prior published ZIP and checksum are retained unchanged under
dist/history/published-0.1.0-dev.1 with a local retention ledger. Its ZIP SHA-256
is d1b8e948865a9671498b79602f57e5720db9cb5857df43f0460b7a52f5d704fd.
Prior staging and provenance remain intact. Recovery can use that retained
package; restoring distribution is a separate authorized upload, not an automatic
rollback. No artifacts were deleted.

Validation commands (configured host Python; no game/server execution):

```text
python scripts/package.py
python scripts/check_versions.py --root . --release --json
python tests/run_tests.py
python scripts/prepare_workshop.py --output dist/workshop-publish-0.5.1-dev.1-20261015
git diff --check
```

The publication manifest and local receipt bind the exact source commit, version,
package/source/thumbnail hashes, installed Build 42.21.0 (Steam build 25485521),
offline evidence, item identity and actual SteamCMD result. The original supplied
1254 x 1254 PNG is preserved, SHA-256
3435f585ae145d9693fb20b1350850a8ced3d043d7df56c7eb710f8fb120de0b.
Check actual upload and download receipts before claiming distribution success.

[TESTED: OFFLINE] Packaging, ZIP CRC/member/path/case/source parity, current and
release version checks PASS. All 190 scenarios PASS, including native authority,
sender/reconstruction, SP binding, area selection, trash/broom and overhead HUD
cases against simulated engine services. Source inventory PASS: 80 Lua-only mod
files and exact dependency boundaries. The package SHA-256 is
34b0d485fbada68a2f568c3cbd9afda3cdd777510a12f9f93199b41e376a7e36.
Source thumbnail integrity and exact bytes match the supplied artwork. These
checks supersede the old ZIP mismatch for this candidate, not historical reports.

[RUNTIME GATE] Actual SP/split-screen and dedicated MP remain NOT TESTED. G7
BLOCKED / NOT TESTED; stable G8 BLOCKED. Description and changenote explicitly say
"MP testing build - dedicated multiplayer NOT TESTED". Known footprint skips,
unsupported dirt/ashes/graffiti, pathfinding, UI placement, synchronization,
reconstruction, cancel/disconnect/rejoin, save/reload and restart acceptance
remain explicit. Workshop distribution does not prove runtime correctness.
No local deployment or game/server launch is part of publication.
