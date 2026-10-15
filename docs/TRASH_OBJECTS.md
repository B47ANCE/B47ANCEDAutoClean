# Ground trash objects

Project Version: 0.3.0-dev.1

Compatible MINOR addition to Clean Building and confirmed Clean Area selections.
Authoritative source remains src/B47ANCEDAutoClean/42. No Rooms or Quartermaster
production changes. Dependencies remain mandatory for the integrated workflow.

## Behavior and configuration

Trash runs before stain supply fetching. Trash-only work needs no bucket, bleach,
tool or water. A mixed job with missing/ineligible stain supplies removes eligible
trash and reports a partial result with stains skipped. Other existing stain
failures still stop the job. Removed/skipped trash counts are separate from stain
counts. Cancellation never restores objects already removed.

Auto Clean server sandbox settings:

| Stable identifier | Default | Bounds / behavior |
| --- | --- | --- |
| B47ANCEDAutoClean.RemoveTrashObjects | true | Enable decorative trash removal; false keeps stain cleaning available |
| B47ANCEDAutoClean.TrashPickupSeconds | 2 | Integer 1–10 seconds per object |

Existing saves with missing settings use defaults. Invalid duration falls back to
2 seconds; nonboolean enable values disable removal. Authority compares effective
settings before each action; changing effective settings cancels active work.
Names/tooltips use Sandbox.json in all 29 supported language directories with
explicit English fallback, matching the existing localization policy. Native
50 ticks/second conversion, 512-object survey bound, protocol/grant internals and
120-second action expiry are implementation/safety limits, not gameplay options.

## Supported objects and installed API evidence

[VERIFIED: source] Installed Project Zomboid 42.21.0, Steam build 25485521.
Vanilla media/lua/shared/Foraging/forageSystem.lua spriteAffinities.trash identifies
77 exact sprite names: d_trash_0–25, trash_01_0–12 and trash_01_16–53.
The omitted trash_01_13–15 and unknown/custom sprites are excluded. Only plain
IsoObject objects with that sprite, zero containers, no sprite grid and empty mod
data qualify. IsoWorldInventoryObject, named/special subclasses, interactive
props, multi-sprite props and containers fail closed. This does not clear dropped
inventory items or collect rewards. It creates no inventory item.

[VERIFIED: source] Installed server Map/MapObjects/MOFeedingTrough.lua:21 and
MOHutch.lua:99 call square:transmitRemoveItemFromSquare(object,false), proving the
two-argument call is exposed to server Lua. Read-only native inspection confirms
the false argument disables expansion to multi-square object parts and returns
the removed object's index (negative on missing object). The authority uses that
call; the client receives position/index/sprite only for presentation.
Installed ISPickUpGroundCoverItem is reference evidence for pickup presentation
and object membership, but its completion may create items and is not reused.
No custom Java/JAR code ships or runs.

Fingerprints and branch contracts are retained in
tests/fixtures/trash_api_25485521.json and checked by tests/audit_trash_api.py.
The installed loose IsoGridSquare.class takes precedence over its JAR counterpart
for this audit; both implement the same false-argument behavior with different
branch offsets. GameServer is read from the JAR. No vanilla source/bytecode bodies
are committed. A reusable source-only finding was also recorded in the developer's
unmanaged local API audit library; that catalog entry is not runtime proof.

## Ownership and guards

Survey retains exact object/square/sprite/chunk references, bounded by existing
Rooms scope. Cleaning membership excludes supply-logistics tiles outside an area.
Before start and completion, authority checks actor identity/availability,
current square/object membership, unchanged sprite/classification/chunk, native
and delegated permissions, job/scope revision/settings, observed arrival and
native progress. The existing authority clock enforces configured elapsed time;
instant-action settings cannot bypass it. Mutation latches before the native call;
errors or unobserved outcomes close uncertain without retry/refund.

The new trash phase uses the existing retained native action transport. Sender
binding, fresh confirmation challenge, one reconstruction, exact action identity,
one-time completion and SP exact local-player guards remain intact. Clients send
job intent, never an object reference or deletion instruction. Job state is
transient, not saved/reconstructed on reconnect. Cancel/disconnect closes work;
native map removal owns synchronization/persistence. Actual join/rejoin, reload,
restart persistence and third-party map callback behavior remain runtime gates.
Stain resource guards and broad native blood-removal footprint are unchanged.

## Validation

[TESTED: offline] 165 scenario/compatibility checks PASS: the existing 144 checks
plus 21 ground-trash scenarios. Actual production Auto Clean/Rooms modules,
installed native Lua actions/base/queue, and retained server/client transports run
in Lua 5.1 with simulated native engine/world/network/pathfinder/clock. Tests cover
77 sprites and excluded gaps, dropped items/props, same-square index shifts,
building/area scope, trash-only and mixed jobs, missing stain supplies, sandbox
disable/bounds/change, denied tiles, time/progress/confirmation/reconstruction,
replacement/movement/sprite/data changes, cancel/disconnect/expiry, callback
reentry/failure, client presentation without mutation and SP actor binding.

Validation commands (verified bundled Python interpreter):

```text
python tests/run_tests.py
python scripts/check_versions.py --root . --json
git diff --check
```

The full validator exits 1 after recording passing offline scenarios because the
version/artifact gate fails on exactly the preserved old published ZIP filename
and its embedded mod.info. All declared current source mirrors match 0.3.0-dev.1.
Source inventory: 79 files, Lua-only; case-correct requires; exact dependencies;
10 UI keys and 5 sandbox translation keys with English fallback in 29 languages.
Installed native/API fingerprints pass. Neither dependency source was modified
by this iteration. No offline pass is presented as a full release-gate pass.
No package, local deployment, game/server launch or Workshop publication is
authorized by this source change. Historical CLEAN_AREA.md remains 0.2.0-dev.1
evidence. The preserved published 0.1.0-dev.1 ZIP in dist/current deliberately
fails the current artifact-version gate; do not relabel it as current validation.

[RUNTIME GATE] Actual SP NOT TESTED; dedicated G7 BLOCKED / NOT TESTED; stable G8
BLOCKED. Test supported vanilla trash in both scopes, dropped-item exclusion,
denied/edge/outside-selection tiles, multiple clients, cancel/disconnect/rejoin,
map synchronization, save/reload and dedicated restart before runtime acceptance.
