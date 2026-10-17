# Changelog

## [0.5.1-dev.1] - 2026-10-15

- Publication preparation: explicitly authorized Workshop MP testing update with current feature set and thumbnail. Preserve the old ZIP/checksum with verified hashes in dist/history/published-0.1.0-dev.1 and validate the new package separately. Earlier source-iteration failures below remain historical; see docs/PUBLICATION_0.5.1.md for current checks.
- Steam rejected the original preview upload with Limit exceeded. Preserve the original PNG and failed staging; export a quality-95 full-resolution JPEG upload preview and bind both hashes in the publication manifest. Host-only packaging correction; no runtime behavior change.
- Distribution confirmed: SteamCMD update of item 3820151540 succeeded from commit 6d38fa08343faefdcaa5f70c0481a18ca045dfce. Downloaded 80 files match staging exactly; the public page shows current version, thumbnail and both required items. Steam gracefully restarted. Actual SP/dedicated runtime remains NOT TESTED; G7/stable G8 BLOCKED.

- Compatible PATCH: replace the project/Workshop source thumbnail with the user-supplied Auto Clean artwork. Preserve its original 1254 x 1254 PNG bytes; the in-game icon and poster remain unchanged.
- PNG integrity and exact source/destination SHA-256 PASS offline (Pillow verification and byte comparison). `python scripts/check_source.py` and `git diff --check` PASS; `python tests/run_tests.py` passes 190 offline scenarios but exits 1 for the existing package-version gate. `python scripts/check_versions.py --root . --json` confirms current source mirrors and reports the two preserved older ZIP mismatches. No gameplay or authority changes. Actual SP/dedicated runtime NOT TESTED; G7/stable G8 BLOCKED. No packaging, deployment or Workshop upload.

## [0.5.0-dev.1] - 2026-10-15

- Compatible MINOR: retain vanilla current-action progress and add a separate overhead whole-cleaning bar for building and area jobs, using authority-owned processed/total target counts and phase labels.
- Presentation only: no action timing, mutation, supply return, sender/reconstruction, scope or permission changes.
- 190 offline scenario/compatibility checks PASS, including 11 HUD cases with installed vanilla ISProgressBar and simulated native UI/viewport. Current source mirrors match; the preserved older package still blocks the full artifact-version gate. Actual visual SP/dedicated runtime NOT TESTED, G7 and stable G8 BLOCKED. No packaging, deployment or Workshop publication.

## [0.4.0-dev.1] - 2026-10-15

- MINOR: use vanilla ground-cover pickup timing and optional broom clearing timing/presentation; fetch an eligible broom through Quartermaster when available, otherwise pick up by hand.
- Remove the custom trash pickup duration option. Legacy values are ignored; native durations and actor modifiers apply. Preserve exact authority, sender/reconstruction, timing, scope and single-object removal guards.
- 179 scenario/compatibility checks PASS offline, including 35 trash/broom scenarios with actual native Lua duration/modifier/presentation callbacks and guarded reconstruction. Actual SP and dedicated G7 NOT TESTED / BLOCKED, stable G8 BLOCKED. Preserved older package still fails the full artifact-version gate. No package/deployment/publication.

## [0.3.0-dev.1] - 2026-10-15

- Compatible MINOR: add guarded cleanup of verified vanilla decorative trash objects to building and selected-area tasks; dropped inventory items remain untouched.
- Add authoritative Auto Clean sandbox controls for enabling trash removal and pickup time. Retain exact scope, permission, sender/reconstruction, timing, cancellation and one-time mutation guards.
- 165 offline scenario/compatibility checks PASS, including 21 trash-object scenarios and installed API fingerprints. Actual SP and dedicated G7 NOT TESTED / BLOCKED, stable G8 BLOCKED. Preserved published 0.1.0-dev.1 artifacts still block release-version validation. No new package, deployment, game/server launch or publication.

## [0.2.0-dev.1] - 2026-10-15

- Compatible MINOR: add Clean Area with a transient Rooms selector and explicit Start Cleaning confirmation.
- Validate selected geometry on authority and preserve sender, reconstruction, resource, footprint and local-player guards. Clean Building remains available.
- Auto Clean only; reuse Rooms UI and public permission services without changing Rooms or Quartermaster. No save-schema or native timed-action protocol change. No packaging, deployment, game/server launch or publication requested.
- 144 offline scenario/compatibility checks PASS; actual SP and dedicated G7 NOT TESTED / BLOCKED, stable G8 BLOCKED. Published 0.1.0-dev.1 artifacts are preserved unchanged and block the artifact-version gate until authorized packaging reconciliation.

## [0.1.0-dev.1] - 2026-10-15

- Extract the Lua-only SP/MP Clean Building feature from Quartermaster 0.10.0-dev.1.
- Require Quartermaster SupplyAPI 1 and Rooms; keep all permission, resource, footprint, sender/reconstruction and local-player guards.
- No persistent schema changes; jobs do not resume on reload/reconnect. No deployment or Workshop publication. SP/dedicated runtime NOT TESTED; G7 and stable G8 BLOCKED.

Publication metadata: standalone Workshop item 3820151540; required Workshop items Quartermaster 3807217050 and Rooms 3820077442. Authorized MP testing distribution; runtime acceptance remains NOT TESTED.
