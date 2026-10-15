# Changelog

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
