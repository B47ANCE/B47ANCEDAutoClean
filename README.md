# B47ANCE'd Auto Clean

Project Version: 0.1.0-dev.1

Separate Lua-only Clean Building mod. Requires B47ANCEDQuartermaster SupplyAPI 1 and B47ANCEDRooms API 1 cleaning capability 1. Authoritative source: src/B47ANCEDAutoClean/42. Mod ID: B47ANCEDAutoClean. [Workshop item 3820151540](https://steamcommunity.com/sharedfiles/filedetails/?id=3820151540).

SP and multiplayer use the retained guarded native actions. Rooms owns permissions and sandbox settings; Quartermaster owns configured supply storage and native supply transfers; this mod owns the cleaning workflow, menu, action guards and transient jobs. Default recipe: 10 mL bleach first, then water to remaining bucket capacity.

MP testing build - dedicated multiplayer NOT TESTED. Both Quartermaster (Workshop 3807217050) and Rooms (Workshop 3820077442) are required Workshop items and native mod.info dependencies. Enable all three mods on every peer. Native/SP/dedicated acceptance NOT TESTED; G7 and stable G8 BLOCKED. Public source repository: [B47ANCE/B47ANCEDAutoClean](https://github.com/B47ANCE/B47ANCEDAutoClean). Implementation is on feature/standalone-auto-clean pending PR review. No local deployment or game/server launch accompanies publication.

Run `python tests/run_tests.py` with adjacent Quartermaster and Rooms checkouts.
The validator reads installed Build 42.21 evidence and never launches the game.
Use `python scripts/check_versions.py --root .` for version mirrors. Explicit
packaging is `python scripts/package.py`. Packaging and Workshop staging are now prepared for the explicitly authorized testing distribution.
See [ownership and migration](docs/ARCHITECTURE.md), [validation](docs/ITERATION_REPORT.md)
and [source provenance](docs/EXTRACTION_PROVENANCE.json). Default B47 artwork is
copied byte-for-byte from the verified team branding manifest; no manual art
was overwritten or transformed.
