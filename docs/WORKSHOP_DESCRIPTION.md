# B47ANCE'd Auto Clean

## Overview
Separate Clean Building workflow for Build 42.21.0. Version 0.4.0-dev.1.
MP testing build - dedicated multiplayer NOT TESTED

## Features
- Choose Clean Building to collect suitable supplies from Quartermaster configured storage and clean eligible targets throughout the selected building.
- Choose Clean Area to preview a rectangle or painted selection with Rooms controls, add explicit floors, and edit with erase or undo/redo. Nothing starts until Start Cleaning is selected. Cancelling the selection starts no task and saves no room.
- Remove supported vanilla decorative ground trash objects before stain cleaning. Dropped inventory items, containers, interactive props and unknown sprites are untouched. Trash-only cleanup needs no cleaning supplies; missing stain supplies leave a partial result after trash cleanup.
- Use an eligible carried or configured-storage broom when available; otherwise use vanilla ground-cover pickup. Vanilla action timing and character modifiers apply. Borrowed brooms are returned and the original hand restored.
- Default preparation adds 10 mL bleach first, then fills remaining bucket capacity with water.
- Uses guarded native timed actions, supply borrowing and return, and Rooms permission checks.
- Lua-only implementation with server authority in multiplayer and exact local-player binding in single-player.

## Compatibility & Requirements
Requires B47ANCEDQuartermaster SupplyAPI 1 (Quartermaster 0.11.0-dev.1 or compatible) and B47ANCEDRooms API 1 with cleaning capability 1. Enable all three mods on clients and server. Quartermaster alone no longer adds Clean Building.
Quartermaster Workshop item: 3807217050. Rooms Workshop item: 3820077442.
179 Auto Clean scenario/compatibility checks, including 35 trash/broom scenarios and 12 published-Rooms selector compatibility checks, passed offline against installed Build 42.21 evidence and simulated engine services. Actual SP, split-screen and dedicated multiplayer acceptance are NOT TESTED.

## Configuration
Rooms owns cleaning scope settings, borrowing/return policy and permissions. Auto Clean sandbox settings enable ground trash removal. Pickup/clearing time comes from vanilla; the former custom duration option is removed and old values are ignored. Quartermaster owns configured supply storage. Configure suitable storage and make supplies available for stain cleaning. The bleach-first recipe is unchanged.

## Source Code & Development
GitHub: https://github.com/B47ANCE/B47ANCEDAutoClean
Development version 0.4.0-dev.1. This source iteration has not been packaged, deployed or published. Workshop distribution is for testing; G7 remains NOT TESTED / BLOCKED and stable G8 remains BLOCKED.

## Known Issues
The conservative native footprint guard can skip unsupported targets, including all targets in some layouts. Ashes, graffiti and arbitrary dirt are unsupported. Native pathfinding, fluids, action reconstruction, observers, cancellation, save/reload, reconnect and restart behavior still require in-game testing. Do not treat offline tests as runtime verification. Update Quartermaster and Auto Clean together when moving from embedded cleaning.

## Credits & Permissions
Developed by B47ANCE'd Workshop. Original team implementation extracted from B47ANCE'd Quartermaster with retained provenance. No third-party mod source or assets included. Uses the team's original default branding.
Mod ID: B47ANCEDAutoClean.
