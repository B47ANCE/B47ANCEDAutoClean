# B47ANCE'd Auto Clean

Project Version: 0.1.0-dev.1

Separate Lua-only Clean Building mod. Requires B47ANCEDQuartermaster SupplyAPI 1 and B47ANCEDRooms API 1 cleaning capability 1. Authoritative source: src/B47ANCEDAutoClean/42. Mod ID: B47ANCEDAutoClean. No Workshop item has been assigned.

SP and multiplayer use the retained guarded native actions. Rooms owns permissions and sandbox settings; Quartermaster owns configured supply storage and native supply transfers; this mod owns the cleaning workflow, menu, action guards and transient jobs. Default recipe: 10 mL bleach first, then water to remaining bucket capacity.

This extraction has not been deployed or published. Native/SP/dedicated acceptance NOT TESTED; G7 and stable G8 BLOCKED. A public GitHub destination awaits approval.

Run `python tests/run_tests.py` with adjacent Quartermaster and Rooms checkouts.
The validator reads installed Build 42.21 evidence and never launches the game.
Use `python scripts/check_versions.py --root .` for version mirrors. Explicit
packaging is `python scripts/package.py`; it is not run during this extraction.
See [ownership and migration](docs/ARCHITECTURE.md), [validation](docs/ITERATION_REPORT.md)
and [source provenance](docs/EXTRACTION_PROVENANCE.json). Default B47 artwork is
copied byte-for-byte from the verified team branding manifest; no manual art
was overwritten or transformed.
