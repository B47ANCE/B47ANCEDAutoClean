# Clean Area

Project Version: 0.2.0-dev.1

Compatible MINOR addition to published 0.1.0-dev.1. This chat and implementation
remain Auto Clean only: Rooms and Quartermaster source are read, never edited.
The new source is not packaged, locally deployed or published.

Right-click and choose **Clean Area**. Use the existing Rooms rectangle,
paint/erase, explicit floor and undo/redo controls to preview the tiles. Select
**Start Cleaning** to confirm. Empty or unfinished selections cannot start.
Cancel, Escape, death, disconnect, player replacement or uninstall discard the
preview. No supplies are fetched, cleaning requests sent, or room records saved
while selecting. **Clean Building** remains available inside a native building.

## Ownership and guards

Auto Clean's client AreaSelector derives from the Rooms Editor class and reuses
its mouse/controller handling, Draft geometry and native camera/zoom projection.
It provides its own controls and transient lifecycle, with no room-editing
request or persistence. The selector baseline is published Rooms 0.1.0-dev.2 (or compatible). It depends on the existing Rooms modules, not a new
Rooms release. Rooms Geometry, Draft, API and Cleaning implementation are
unchanged between published Rooms 0.1.0-dev.2 and inspected 0.1.0-dev.3.

Client areaBegin carries only protocol, request and row-run geometry. No player,
scope handle, callback, action timing, grant or resource field is accepted.
The native event's player binds the request. Auto Clean normalizes into a fresh,
bounded server-owned selection and surveys loaded tiles in steps of at most 64.
Denied/unloaded input fails before supply collection. The server retains exact
selected square references, permission revision, sandbox settings, transient
tile reservations and lifetime. Replays reuse the original request result.
Overlapping area/building reservations are denied before actions begin.

The target set is exactly the selected geometry. Existing native footprint
validation checks every potentially affected tile at admission and completion;
it never expands the cleaning selection. A selection too narrow for a native
footprint is skipped. Many or all targets, including edges or omitted floors,
may be skipped. The engine's cross-level behavior is not changed.

When starting inside a building, the existing Rooms snapshot supplies bounded
logistics discovery throughout that building. Supplies and finite water can
therefore be outside the cleaning selection. Outside buildings, supplies must
be carried or in configured storage within the selected area, with eligible
water available there. Every native transfer and water use retains its live
Quartermaster/Rooms permission checks. Inventory is never owned by the selector.

Server/native reconstructed actions, sender challenge, one-time mutation,
natural timing, cancellation, exact local-player binding and resource/footprint
guards are retained. No jobs resume after reload/reconnect/restart. Selection
does not create a saved room or alter save schemas.

## Configuration and limits

Existing authoritative Rooms cleaning settings govern both actions: enable,
borrowing, return, bleach dose, tile limit and transfer timing. Default
preparation remains 10 mL bleach first, then water to remaining bucket capacity.
No new gameplay setting is needed: selection is per-task intent. Geometry uses
Rooms' existing technical bounds (512 rows, 4096 tiles, 128-tile horizontal
extent and eight floor layers) plus the lower authoritative cleaning tile limit.
The logistics union is bounded to twice the cleaning tile limit, and the existing
inventory/survey work caps remain. UI coordinates, protocol budgets and shape
validation bounds remain implementation safeguards.

New Auto Clean strings have explicit English fallback in the 29 language folders
observed in Rooms. Existing Rooms tool labels retain its translation policy.
This is fallback coverage, not a claim of 29 human translations.

## Validation and remaining gates

[TESTED offline] 104 retained scenarios plus 16 new area authority/supply/
transport/SP cases and 12 Rooms-derived selector cases pass. Actual native Lua
actions, Rooms API/geometry/draft/editor and Auto Clean production modules are
exercised with simulated engine, inventory, fluids, world, networking,
pathfinding, UI widgets and camera projections. No PZ runtime is executed. An additional 12 selector checks pass against the downloaded published Rooms 0.1.0-dev.2 editor. The relevant API, Cleaning, Geometry and Draft bytes match current Rooms; both editor variants were exercised. Total: 144 offline checks.

Exact commands using the configured host Python:

- python tests/run_clean_area.py
- python scripts/check_source.py
- python tests/run_tests.py
- python scripts/check_versions.py --root .

The full driver runs all scenario checks even if the version/artifact check
fails, records that gate separately, then exits nonzero rather than waiving it.
Current source mirrors are synchronized. The untouched published 0.1.0-dev.1 ZIP
in dist/current intentionally fails the artifact-version gate for 0.2.0-dev.1.
Do not relabel, overwrite or remove it. Reconcile/preserve it during a separately
authorized packaging step before release. Historical extraction/publication
reports retain their original versions and are not current runtime evidence.

[VERIFIED source] Installed 42.21.0 / Steam build 25485521. The API library
isoToScreenX entry matched installed source hashes. ISPanelJoypad:new uses
(x,y,width,height); ISUIElement:instantiate invokes createChildren. The selector
uses the same call forms as Rooms. The existing area table serialization model
also uses Rooms' bounded row arrays. No custom Java/JAR or third-party mod code.

[RUNTIME GATE] Actual visual scale/clipping, click-through/focus, controller,
split-screen, SP pathfinding/fluids, dedicated sender/reconstruction behavior,
observer synchronization, permissions changing mid-action, cancellation,
join/rejoin and restarts remain NOT TESTED. Dedicated G7 and stable G8 BLOCKED.
Linux case checks are static, not Linux runtime proof. Offline PASS is not
native UI or multiplayer acceptance.

Compatibility: update Auto Clean on server and clients together. Existing building intent and the native action constructor remain compatible; an older server rejects the new areaBegin command rather than accepting client authority. No Quartermaster or Rooms update is required for this feature.
