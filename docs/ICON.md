# Transparent mod icon

Project Version: 0.5.2-dev.1

Compatible PATCH. `src/B47ANCEDAutoClean/42/icon.png` is the approved transparent
mop-and-bucket cutout exported at the existing 64 x 64 icon dimensions with
Pillow LANCZOS. `mod.info` continues to reference `icon.png`. The complete approved
1254 x 1254 RGBA master and its built-in image-tool prompt are retained in
`assets/auto-clean-icon`; provenance records source/export hashes and dimensions.
There is no new artwork generation, lettering or background fill in this export.
The poster and Workshop thumbnail are unchanged, including the original
thumbnail SHA-256 3435f585ae145d9693fb20b1350850a8ced3d043d7df56c7eb710f8fb120de0b.
The upload JPEG must match the previously published thumbnail export exactly.

Scope: icon, version mirrors, documentation and offline fixtures only. Runtime Lua
diffs are restricted to the Identity version string. No permission, mutation,
sender/challenge/reconstruction, resources, timings, sandbox, dependency or save
changes. No new gameplay setting is appropriate for fixed branding artwork.

Baseline checks found `CleaningNoDesignatedRooms` in the old building fixture
against Rooms 0.2.0-dev.7: it provided vanilla room definitions but no persisted
designated tiles. Fixture-owned ModData now supplies a valid designation. The
fixture throws on vanilla room enumeration; new scenarios verify empty scope
cancels without borrowing/mutation and undesignated dirty tiles stay untouched.
Provider and Auto Clean gameplay source are not modified to bypass the scope.
Quartermaster 0.18.0-dev.1 SupplyAPI 1 remains the public supply boundary.

The Rooms editor now offers discard confirmation for controller exit from a
dirty selection. The UI fixture supplies the missing dialog service and verifies
both declining and accepting discard. Published Rooms compatibility now runs
the complete cached Workshop 0.2.0-dev.5 provider in a separate Lua process,
instead of requiring its API hashes to equal development 0.2.0-dev.7 or mixing
an old editor with current API modules. Both complete source environments pass.
The copied non-Git provider reports no invented Git HEAD.

Validation commands (host Python; no game/server launch):

```text
python scripts/check_source.py
python scripts/check_versions.py --root . --json
python tests/run_tests.py
python scripts/package.py
python scripts/check_versions.py --root . --release --json
python scripts/prepare_workshop.py --output dist/workshop-publish-0.5.2-dev.1-20261018
git diff --check
```

Check alpha integrity, 64 x 64 dimensions and source/master provenance; verify
poster/thumbnail original bytes and staged upload JPEG against prior publication.
Prior 0.5.1 package/checksum are retained with a hash ledger before building the
new current package. The current source overview records implemented capabilities
and runtime limits separately from dependency discovery.

[TESTED: OFFLINE] 194 scenarios PASS, including 13 selector checks against each
Rooms environment and the new designation/discard regressions. Current/release
version checks, source inventory, PNG integrity/alpha/dimensions, archive
CRC/member/path/case/source parity and unchanged thumbnail/poster hashes PASS.
Pre-merge candidate SHA-256:
eded666e50d1c65e657c1ade2abe44644585d88b464c488d279624eb60dedae0.
The merged checkout normalized line endings; retain that candidate unchanged
under dist/history/pre-merge-0.5.2-dev.1 and rebuild from exact merged source.
Final package SHA-256: 0a55a070ab209a94b8ec7542969749f015f0f96d6666cb42a8ee16ec7b405ff4.
SteamCMD rejected cached authentication during dependency download verification;
publication remains blocked until the user reauthenticates locally. This is an
authentication failure, not an offline compatibility or runtime PASS.

[RUNTIME GATE] Actual mod-list rendering, SP/split-screen and dedicated multiplayer
NOT TESTED. G7 BLOCKED / NOT TESTED; stable G8 BLOCKED. This is an explicitly
authorized Workshop MP test update only after offline checks and PR merge pass.
The uploader must not restart or launch Steam. Ask and wait for explicit approval
for the specific desktop restart after verified upload success. Publication does
not deploy local mods or launch the game/server.

## Merge and upload preparation

PR #1 was already merged. PR #2 merged the icon/fixtures at
`6616aabaadd34de40caf3d6e634d0f92a20627a7`; GitHub reported a clean merge
and no configured CI checks or branch protection. No required checks were bypassed.
The follow-up record refreshes source-digest/provenance after checkout only;
no runtime gameplay changes or stable release tag. Workshop authentication
remains blocked until local reauthentication; Steam desktop remains unchanged.
