# Ground trash objects

Project Version: 0.4.0-dev.1

MINOR update to Clean Building and confirmed Clean Area selections: optional broom
use and vanilla action timing replace the unreleased custom pickup timer.
Authoritative source remains src/B47ANCEDAutoClean/42. No Rooms or Quartermaster
production changes. Dependencies remain mandatory for the integrated workflow.

## Behavior and configuration

Trash runs before stain supply fetching. An eligible carried Base.Broom or
Base.Broom_Twig is preferred; otherwise an eligible broom may be borrowed from
configured Quartermaster storage under Rooms borrowing policy and capacity checks.
An already-claimed, broken, favorite, attached, consumed or unavailable broom is
not selected. Without an eligible broom, use vanilla ground-cover pickup.
Trash-only work needs no bucket, bleach or water. Brooms are optional. A mixed
job with missing/ineligible stain supplies removes eligible
trash and reports a partial result with stains skipped. Other existing stain
failures still stop the job. Removed/skipped trash counts are separate from stain
counts. Expected hand state permits intentional broom/stain-tool transitions;
completion restores the original primary hand and returns borrowed equipment
under existing return policy. One broom shared with stain cleaning is fetched,
claimed and returned once. A selected tool that changes mid-job cancels safely.
Cancellation never restores objects already removed or silently returns items.

Auto Clean server sandbox settings:

| Stable identifier | Default | Bounds / behavior |
| --- | --- | --- |
| B47ANCEDAutoClean.RemoveTrashObjects | true | Enable decorative trash removal; false keeps stain cleaning available |

Existing saves with missing settings enable trash cleanup; nonboolean enable
values disable it. Authority compares effective settings before each action;
changing the enable setting cancels active work. TrashPickupSeconds is removed
from sandbox definitions, translations and interpretation. Old saved values are
ignored without editing the save. No new migration/schema or setting is required.
Names/tooltips use Sandbox.json in all 29 supported language directories with
explicit English fallback, matching the existing localization policy. Native
timing conversion, 512-object survey bound, protocol/grant internals and
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
Vanilla ISPickUpGroundCoverItem is instantiated for pickup. ISClearAshes is
instantiated for a selected broom; its installed start callback gives Base.Broom
the Rake animation, while the twig variant follows vanilla BuildingHelper's
default clearing animation. The native getDuration, adjustMaxTime,
wait/start/update/stop/perform methods remain inherited. Pickup's default
completion may create items; clearing's default removal is too broad. Both
completions are replaced with the existing exact no-reward removal guard.
No custom Java/JAR code ships or runs.
Run the same Auto Clean build on every peer. The native constructor/grant protocol
is unchanged, but older trash presentation views cannot resolve the new broom
view and fail closed rather than gaining gameplay authority.

Vanilla pickup currently defaults to 100 action ticks; recognized item-backed
ground cover may derive duration from weight, inventory load, traits/gloves and
game mode. Clearing currently returns 60 ticks. Both honor native instant-action
mode; base modifiers handle moodles, hand pain and temperature. These are observed
game values, never mod constants or a new user-configurable duration. MP timing
guard derives its minimum from those owned vanilla callbacks, using the inspected
NetTimedAction conversion to milliseconds. SP trusts completed progress from its
exact native queue, allowing native game-speed acceleration. The technical action
expiry and authenticated progress/confirmation guards remain.

Fingerprints and branch contracts are retained in
tests/fixtures/trash_api_25485521.json and checked by tests/audit_trash_api.py.
The installed loose IsoGridSquare.class takes precedence over its JAR counterpart
for this audit; both implement the same false-argument behavior with different
branch offsets. GameServer is read from the JAR. No vanilla source/bytecode bodies
are committed. A reusable source-only finding was also recorded in the developer's
unmanaged local API audit library; that catalog entry is not runtime proof.
New timing/item evidence is separate in
tests/fixtures/vanilla_trash_actions_25485521.json. It fingerprints the installed
pickup/clearing/base actions, BuildingHelper, weapon item definitions, and native
timing callbacks. Earlier removal fingerprints remain unchanged.

## Ownership and guards

Survey retains exact object/square/sprite/chunk references, bounded by existing
Rooms scope. Cleaning membership excludes supply-logistics tiles outside an area.
Before start and completion, authority checks actor identity/availability,
current square/object membership, unchanged sprite/classification/chunk, native
and delegated permissions, job/scope revision/settings, observed arrival and
native progress. MP independently checks elapsed authority time against the owned
vanilla duration/modifier callbacks; SP uses its exact native queue progress and
retains action expiry. No packet supplies timing. A broom must remain the exact
healthy, carried, primary-hand reference. Mutation latches before the native call;
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

[TESTED: offline] 179 scenario/compatibility checks PASS: the existing 144 checks
plus 35 ground-trash/broom scenarios. Actual production Auto Clean/Rooms modules,
installed native Lua actions/base/queue, and retained server/client transports run
in Lua 5.1 with simulated native engine/world/network/pathfinder/clock. Tests cover
77 sprites and excluded gaps, dropped items/props, same-square index shifts,
building/area scope, trash-only and mixed jobs, missing stain supplies, sandbox
enable/change and obsolete-timer values, denied tiles, native time/progress/confirmation/reconstruction,
replacement/movement/sprite/data changes, cancel/disconnect/expiry, callback
reentry/failure, client presentation without mutation and SP actor binding. New
checks cover carried/configured brooms, same/separate stain tools, one-time
borrowing/return, original-hand restoration, unusable-tool fallback, pending-tool
changes, vanilla moodle/weight/trait/instant durations, twig presentation, native
SP game-speed acceleration and delayed client equipped-broom replication.

Validation commands (verified bundled Python interpreter):

```text
python tests/run_tests.py
python scripts/check_versions.py --root . --json
git diff --check
```

The full validator exits 1 after recording passing offline scenarios because the
version/artifact gate fails on exactly the preserved old published ZIP filename
and its embedded mod.info. All declared current source mirrors match 0.4.0-dev.1.
Source inventory: 79 files, Lua-only; case-correct requires; exact dependencies;
10 UI keys and 3 sandbox translation keys with English fallback in 29 languages.
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
Also test actual sweeping animation, hand/equipment replication, carried and
borrowed broom variants, native modifiers/instant action and SP speed controls.
