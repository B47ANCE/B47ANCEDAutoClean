# Source extraction validation

Project Version: 0.1.0-dev.1

[VERIFIED source] Independent mod identity B47ANCEDAutoClean; required native
mod.info dependencies B47ANCEDQuartermaster,B47ANCEDRooms. Quartermaster provider
0.11.0-dev.1 commit f274ece1854a1845113f759206243951d2df2cde is pushed and verified
on its existing public feature branch. Rooms 0.1.0-dev.2 remains unchanged.

[TESTED offline] 104 Auto Clean guard/transport/building/lifecycle/SP scenarios
pass against actual Quartermaster SupplyAPI and Rooms source plus installed
vanilla Lua. The native engine, fluid model, world, pathfinder, clocks and
network are simulated. Full Quartermaster regressions pass, including 29
provider scenarios. Exact source inventories: Auto Clean 16 files, Quartermaster
131 files. Lua-only runtime and case-correct dependency paths were checked.

Ten original modules retain exact code after normalizing only their require
namespace and line endings; extraction provenance identifies the exact source
commit and hashes. Only the installer/provider adapter changes behavior at the
boundary. Existing protocol constructor parameters, measured mutation guards,
resource locks, local identity and sender/reconstruction guards remain intact.

Commands:

```powershell
# From B47ANCEDAutoClean
python scripts/check_versions.py --root .
python tests/run_tests.py
# From B47ANCEDQuartermaster
python scripts/check_versions.py --root .
python scripts/check_deployment.py
python tests/run_tests.py
```

No new package, local deployment, game/server launch or Workshop publication.
The previous published Quartermaster package/hash/provenance are retained under
its dist/history/0.10.0-dev.1-auto-clean-extraction with a verified preservation
ledger. The new Auto Clean project has no assigned Workshop item.

[RUNTIME GATE] Actual SP, split-screen, native load order, dedicated client
join/rejoin, observers, permission changes, saves and restarts NOT TESTED.
G7 BLOCKED / NOT TESTED; stable G8 BLOCKED. Offline PASS is not game validation.
