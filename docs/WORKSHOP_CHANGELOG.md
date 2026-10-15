Version 0.4.0-dev.1
MP testing build - dedicated multiplayer NOT TESTED

Add Clean Area using Rooms selection controls: rectangle, paint/erase, explicit floors, undo/redo, and Start Cleaning confirmation. Preview and cancellation start no work and do not create or change Rooms designations. Clean Building remains available.

Retains Lua-only SP and multiplayer guards, authenticated sender binding, reconstructed native-action guards, supply borrowing/return and bleach-first preparation: 10 mL bleach, then water to remaining bucket capacity.

Ground trash uses vanilla pickup timing or an eligible carried/configured-storage broom with vanilla clearing timing and presentation. Remove the custom pickup-time option; old values are ignored. Brooms use existing guarded fetching, equipment restoration and return policy. Dropped items and other props remain untouched. 179 scenario/compatibility checks passed offline, including 35 trash/broom scenarios. See docs/TRASH_OBJECTS.md for evidence and limitations. Actual SP and dedicated runtime acceptance NOT TESTED; G7 and stable G8 BLOCKED. This source iteration is not packaged, deployed or published.
