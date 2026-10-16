# B47ANCE'd Auto Clean

Project Version: 0.5.1-dev.1

Lua-only Clean Building and Clean Area mod. Requires B47ANCEDQuartermaster SupplyAPI 1 and B47ANCEDRooms API 1 cleaning capability 1. Authoritative source: src/B47ANCEDAutoClean/42. Mod ID: B47ANCEDAutoClean. [Workshop item 3820151540](https://steamcommunity.com/sharedfiles/filedetails/?id=3820151540).

Right-click **Clean Area**, select tiles with Rooms rectangle or paint/erase controls, add explicit floors, then choose **Start Cleaning**. Nothing starts until confirmation; Cancel/Escape discard the preview. Clean Building remains available. See [selection behavior, guards and validation](docs/CLEAN_AREA.md).

Two overhead progress bars track cleaning: vanilla shows the current timed action, while a separate bar shows overall processed-target progress and the fetching/preparing/cleaning/returning phase. The overall bar stays visible through the supply return step and clears when the job ends. See [progress behavior and validation](docs/PROGRESS.md).

Clean Building and Clean Area also remove supported vanilla decorative ground trash objects. Dropped inventory items are left alone. An eligible carried or configured-storage broom is equipped and used when available, then borrowed equipment is returned and the original hand restored. Otherwise, trash uses vanilla ground-cover pickup. Vanilla owns action timing and character modifiers; there is no custom pickup-time setting. Server sandbox settings enable trash removal. See [supported objects, equipment, timing and test evidence](docs/TRASH_OBJECTS.md).

SP and multiplayer use the retained guarded native actions. Rooms owns permissions and cleaning scope settings; Auto Clean owns trash sandbox settings; Quartermaster owns configured supply storage and native supply transfers; this mod owns the cleaning workflow, menu, action guards and transient jobs. Default recipe: 10 mL bleach first, then water to remaining bucket capacity.

MP testing build - dedicated multiplayer NOT TESTED. Both Quartermaster (Workshop 3807217050) and Rooms (Workshop 3820077442) are required Workshop items and native mod.info dependencies. Enable all three mods on every peer. Native/SP/dedicated acceptance NOT TESTED; G7 and stable G8 BLOCKED. Public source repository: [B47ANCE/B47ANCEDAutoClean](https://github.com/B47ANCE/B47ANCEDAutoClean). Implementation is on feature/standalone-auto-clean pending PR review. No local deployment or game/server launch accompanies publication.

Run `python tests/run_tests.py` with adjacent Quartermaster and Rooms checkouts.
The validator reads installed Build 42.21 evidence and never launches the game.
Use `python scripts/check_versions.py --root .` for version mirrors. Explicit
packaging is `python scripts/package.py`. Current 0.5.1-dev.1 source is selected for an explicitly authorized Workshop MP testing upload. The prior published 0.1.0-dev.1 ZIP and checksum are preserved unchanged in dist/history/published-0.1.0-dev.1; dist/current holds the new package. See [publication validation](docs/PUBLICATION_0.5.1.md). Local deployment is separate.
See [ownership and migration](docs/ARCHITECTURE.md), [historical initial extraction evidence](docs/ITERATION_REPORT.md)
and [source provenance](docs/EXTRACTION_PROVENANCE.json). The project/Workshop thumbnail is the user-supplied Auto Clean artwork in
`preview.png` (1254 x 1254 PNG), copied unchanged on 2026-10-15. Its SHA-256 is
`3435f585ae145d9693fb20b1350850a8ced3d043d7df56c7eb710f8fb120de0b`.
The in-game icon and poster retain their verified default B47 artwork. The
current Workshop candidate uses this exact thumbnail; the publication receipt records upload verification.
