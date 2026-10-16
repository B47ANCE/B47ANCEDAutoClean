Version 0.5.1-dev.1
MP testing build - dedicated multiplayer NOT TESTED

Use the supplied Auto Clean artwork as the project/Workshop source thumbnail, preserving the original PNG bytes. In-game icon and poster are unchanged. Use this artwork for the Workshop thumbnail.

Add a second overhead bar for overall Clean Area/Clean Building progress while preserving vanilla's current-action bar. Show authoritative processed-target percentage and fetching/preparing/cleaning/returning phase; clear the widget when work ends. No gameplay or native timing changes. 190 scenarios passed offline, including 11 HUD cases; actual in-game visual and multiplayer acceptance NOT TESTED.

Add Clean Area using Rooms selection controls: rectangle, paint/erase, explicit floors, undo/redo, and Start Cleaning confirmation. Preview and cancellation start no work and do not create or change Rooms designations. Clean Building remains available.

Retains Lua-only SP and multiplayer guards, authenticated sender binding, reconstructed native-action guards, supply borrowing/return and bleach-first preparation: 10 mL bleach, then water to remaining bucket capacity.

Ground trash uses vanilla pickup timing or an eligible carried/configured-storage broom with vanilla clearing timing and presentation. The custom pickup-time option remains removed; old values are ignored. Brooms use existing guarded fetching, equipment restoration and return policy. Dropped items and other props remain untouched. See docs/TRASH_OBJECTS.md and docs/PROGRESS.md for evidence and limitations. Actual SP and dedicated runtime acceptance NOT TESTED; G7 and stable G8 BLOCKED. This is a Workshop MP testing update; local deployment and game/server launch are separate.
