# B47ANCE'd Auto Clean

Read `%USERPROFILE%/.codex/AGENTS.md`. Lua-only; exact authority-owned resource
handles; authenticated multiplayer commands or exact offline local-player binding.

Canonical version: VERSION. Authoritative source: src/B47ANCEDAutoClean/42.
Mod ID: B47ANCEDAutoClean. Initial project version: 0.1.0-dev.1. No Workshop ID
has been assigned. Proposed public GitHub destination: B47ANCE/B47ANCEDAutoClean;
create/configure only after the user approves that exact destination.

Required dependencies: Quartermaster SupplyAPI 1 and Rooms API 1 / cleaning 1.
Quartermaster owns configured supplies/transfers; Rooms owns geometry, policy and
sandbox settings. Do not read Quartermaster's private storage/movement tables.
Keep the retained mutation, footprint, sender/challenge/reconstruction guards.

Run scripts/check_versions.py and tests/run_tests.py. The latter expects adjacent
B47ANCEDQuartermaster and B47ANCEDRooms source checkouts and the installed B42.21
game for read-only native Lua/bytecode evidence. Host Python dependencies never
ship with the mod. scripts/package.py is an explicit packaging entry point.

Tests/research retained from Quartermaster are original team code with documented
provenance, not external-mod source. Old fixture evidence keeps its original
version/environment. SP and dedicated runtime NOT TESTED; G7/stable G8 BLOCKED.
Do not deploy, launch a game/server, create a Workshop item or publish without
explicit authorization. No background cleanup or deletion of release artifacts.
