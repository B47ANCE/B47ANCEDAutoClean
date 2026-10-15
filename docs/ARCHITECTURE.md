# Ownership and extraction

Project Version: 0.1.0-dev.1

B47ANCEDAutoClean is a separate runtime mod with required dependencies
B47ANCEDQuartermaster and B47ANCEDRooms. The user explicitly requires
Quartermaster for supply fetching. Quartermaster can run without Auto Clean.
Rooms remains independent. There is no dependency cycle.

Auto Clean owns the world menu, bounded building workflow, exact resource claims,
recipe/native mutation evidence guards and transient cleanup jobs. Quartermaster
SupplyAPI 1 owns configured storage queries and guarded native transfer actions.
Rooms API 1 owns native building scope, permissions and existing cleaning sandbox
settings. No configuration or persistence is moved into a client-owned preference.

The default recipe adds 10 mL bleach before filling the rest of a supported 10 L
bucket with finite pure water. Existing prepared solution/refill behavior,
equipment restrictions, capacity checks, actual completion summaries and return
admission are retained. Ashes/graffiti/arbitrary dirt remain unsupported. Native
cross-level stain removal requires a conservative footprint; many or all targets
can still be skipped. This extraction does not weaken that guard.

Multiplayer clients submit bounded intent. The native OnClientCommand player
binds ownership; exact server handles, grants and fresh confirmations bind native
actions. Reconstruction returns the retained action with guard closures. The
fixed native class/channel and constructor parameters are unchanged; no packet
resource, callback or timing field gains authority. Raw native packet handling
can still interrupt an earlier action before Lua confirmation (engine limitation).

Offline startup is available only when both network-role flags are false and
actor identity matches getSpecificPlayer(actor:getPlayerNum()). LocalQueue queues
the retained action; native start/update/complete/perform retain measured guards,
natural timing, cancellation and one-time completion. Network clients cannot use
the offline authority. Supply transfer actions add their own exact-reference,
permission and replay checks inside the existing job guard.

All relevant Rooms sandbox identifiers/defaults and persisted registries remain
unchanged. No jobs are persisted or resumed after load/reconnect/restart. No real
player save is changed by extraction/tests. Rollback requires selecting the old
embedded Quartermaster alone; do not enable an old embedded and new separate
cleaner together. Startup refuses missing/incompatible provider APIs and detected
old active embedded cleaners before installing a menu/class/command listener.

Upgrade requires the new Quartermaster source with SupplyAPI 1, compatible Rooms
and Auto Clean enabled on every peer. Old Workshop Quartermaster 0.10.0-dev.1 has
no supply provider. Workshop distribution has not been changed by this extraction;
Auto Clean has no Workshop item yet. Current source is offline testing work.

See the sibling Quartermaster docs/SUPPLY_API.md for the public API contract.
docs/EXTRACTION_PROVENANCE.json records the original source commit/file hashes;
native research/fixture evidence remains historical. No vanilla or external-mod
source is shipped, and no Java/JAR/native mod dependency is introduced.

[RUNTIME GATE] Native SP, split-screen, dedicated join/rejoin, synchronization,
permission changes, persistence and restarts remain NOT TESTED. G7 and stable G8
BLOCKED. Static/offline source evidence does not certify Linux or game behavior.
