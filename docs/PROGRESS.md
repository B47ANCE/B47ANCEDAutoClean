# Two overhead progress bars

Project Version: 0.5.1-dev.1

Compatible MINOR presentation feature for existing Clean Building and confirmed
Clean Area jobs. The native timed-action bar remains unchanged and follows the
game's own current-action visibility/timing. A separate vanilla ISProgressBar
widget above it shows overall cleaning progress for the owning local player.

The second bar starts after a cleaning job is submitted, never during area
selection preview. It shows Surveying until authority finishes the bounded survey,
then a phase and percentage: Fetching supplies, Preparing supplies, Cleaning or
Returning supplies. It stays visible while walking and returning equipment and
is removed at completion, partial completion, failure or cancellation. No new
Clean Room command or selection geometry is introduced; a selected room-sized
area uses the existing Clean Area flow.

## What the percentage means

One surveyed blood square or eligible trash object is one target. Percentage is
authority-confirmed processed targets divided by surveyed targets. Processed
includes cleaned/removed targets, already-clean squares and skipped targets;
the existing final summary reports actual cleaning/removal and skip counts.
This is a target count, not an elapsed-time estimate. The vanilla bar continues
to show fractional progress of the current action separately.

The overall bar can reach 100% when the final target is processed and still say
Returning supplies until the job ends. Supply fetching, mixing, walking and
returning have phase labels but no invented target weights. A no-target job ends
without fabricating progress. Client animation never marks a target completed.

## Ownership, lifecycle and configuration

BuildingJob retains the original surveyed trash count and reports existing
stain/trash completion counters, survey readiness and stage. BuildingWire attaches
a read-only progress snapshot to existing actor-owned buildingState responses.
No request schema, native action constructor, grant, callback or command changes.
Server ingress rejects client-supplied progress/counts. Clients accept snapshots
only for their pending request and owned job; invalid display counters are ignored.
Single-player uses the same job counters under exact local-player binding.

Progress.lua is a client-only renderer. It never schedules/completes actions,
changes game state or touches the native current-action progress bar. No server
UI module is loaded. Native mutation, timing, sender/reconstruction, permission,
resource, footprint and return guards remain unchanged. Jobs and display state
are transient; neither is saved or resumed on reconnect/restart. All peers should
run the same Auto Clean build for the new optional response metadata. Older
clients can ignore it; a newer HUD without it stays in Surveying until job end.

The widget is bound to the exact active record/local actor. Cancellation,
uninstall, death, actor replacement and stale render callbacks remove only its
own widget. Existing job/network timeouts stop work through the existing lifecycle.
Each split-screen actor has a separate per-player widget. Mouse, key and capture
flags are false; no focus or controller bindings are acquired. Offscreen/viewport
overflow drawing is suppressed; text is clipped. Font metrics, movement and zoom
are recalculated during rendering using vanilla overhead projection conventions.

No new sandbox setting is appropriate: this changes local presentation only.
UI coordinates, padding, font and bar spacing are internal layout values, not
shared gameplay configuration. Existing Rooms and Auto Clean gameplay settings
are unchanged. Six display keys use the current explicit English fallback in
all 29 supported language directories.

## Installed evidence and validation

[VERIFIED: source] Project Zomboid 42.21.0 / Steam build 25485521:

- ISProgressBar defines local fraction clamping and native-styled background,
  fill and text drawing.
- ISUIElement defines input passthrough, world-following, per-player rendering,
  lifecycle and stencil methods used by this widget.
- ISSearchManager demonstrates zoom-aware overhead projection with viewport-local
  coordinates and per-player rendering. Read-only inspection of native action-bar
  positioning informed the separate vertical gap; actual overlap is not verified.

Fingerprints are in tests/fixtures/progress_ui_25485521.json and rechecked by
tests/audit_progress_ui.py. The reusable setter finding is recorded in the
developer's unmanaged local API catalog. No vanilla source bodies are copied.

[TESTED: offline] 190 scenario/compatibility checks PASS: 179 existing gameplay,
transport, area, trash/broom and compatibility checks plus 11 HUD scenarios.
The HUD suite executes production Progress/BuildingWire and the installed vanilla
ISProgressBar with simulated native UI drawing, viewports and engine services.
It covers authority counters, phase labels, constant progress during walking,
movement/zoom/font changes, clipping, split-screen ownership, invalid snapshots,
cancel/death/replacement/uninstall, stale callbacks, area preview/confirmation,
matching multiplayer responses and rejection of client-supplied progress counters.
Existing gameplay suites deliberately stub the HUD; dedicated HUD cases load the
actual widget separately. Neither layer is in-game proof.

Commands (verified bundled Python interpreter):

```text
python tests/run_tests.py
python scripts/check_versions.py --root . --json
git diff --check
```

The full validator exits 1 because the preserved published 0.1.0-dev.1 ZIP in
dist/current and its embedded mod.info do not match current source. Current
declared version mirrors pass; the two old-artifact errors remain release blockers.
Source: 80 Lua-only runtime files, 16 UI keys and 3 sandbox keys with English
fallback in 29 languages. No dependency source is modified. No package,
deployment, game/server launch or Workshop upload accompanies this iteration.

[RUNTIME GATE] Actual visual SP/split-screen and dedicated MP NOT TESTED. G7 and
stable G8 remain BLOCKED. Verify both bars together during native actions,
overhead labels/usernames, camera movement/zoom, UI scale, split-screen clipping,
controller/mouse passthrough, cancellation, disconnect/rejoin and final supply
returns in PZ. Offline draw calls cannot prove pixel placement or MP acceptance.

## Authorized Workshop preparation, 2026-10-15

The source-iteration gate failures above are historical observations. The prior
published ZIP and checksum are now retained unchanged under
`dist/history/published-0.1.0-dev.1`; the new current package is checked separately.
See [current publication validation](PUBLICATION_0.5.1.md). This does not upgrade
SP/dedicated evidence: actual runtime NOT TESTED; G7/stable G8 BLOCKED.
