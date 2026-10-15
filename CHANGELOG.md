# Changelog - Simple Loadout System (The Witcher 3)

Versions are issued by the project's version gate. Written as the change happens (rule 61).

## 1.0.3 - 2026-10-14 - untested (the 'no settings save from the poll' build; the first mod.io package; then the 'horse gear' build, 2026-10-15)

* **Horse gear and the trophy are part of a loadout** (the owner, 2026-10-15: *"I want the horse equipment and trophy
  to also be able to be saved into a loadout."*). Roach's saddle, saddlebags and blinders and Geralt's trophy
  (`EES_HorseSaddle`, `EES_HorseBag`, `EES_HorseBlinders`, `EES_HorseTrophy`) are stored when a loadout is left and put
  back on when it is selected, like the rest of the gear:
  * stored the same way: the `SLS_Loadout` item modifier on the stash piece (saved with the game) and the
    `NoShowInContainer` tag, put back after a load by the same `SLS_SyncStashTags` - so stored horse pieces are hidden
    from the stash list and from Roach's saddlebag list too;
  * taken off and put on only through the game's own path, the one the inventory menu uses: `W3HorseManager
    .UnequipItem(slot)` (hands the piece to Geralt's inventory), and `MoveItemToHorse` + `W3HorseManager.EquipItem`
    from Geralt's inventory. A mod that changes those functions (The Stable's 5.01 patch replaces EquipItem and
    UnequipItem) runs exactly as it does for the menu. `EquipItem` mounts the piece on the live horse when she is
    spawned and `ApplyHorseUpdateOnSpawn` applies `itemSlots` when she next spawns, so SLS never touches the horse
    entity itself; the trophy's abilities and the saddlebags' carry weight follow from the same functions;
  * quest and kept (NoDrop) horse pieces stay on the horse; the menu's paperdoll is told (`PaperdollRemoveItem` /
    `PaperdollUpdateHorseItem`) as the menu's own equip and unequip do.
* **Loadouts stored before this build keep Roach's gear alone.** Each loadout carries a saved fact `sls_horse_<n>` = 1
  once its storage holds its horse gear (none at all counts: a bare horse). A switch moves the horse gear unless the
  target is a loadout with stored pieces but no such fact (stored by 1.0.0-1.0.2), or no loadout is on either side
  (none <-> Always worn); then Roach keeps what she wears and the loadout left behind is marked as holding no horse
  gear, so going back to it leaves her alone too (`SLS_HorseMoves`). An empty loadout counts as holding horse gear
  (nothing yet), so leaving a loadout for a new one stores its horse gear, as it does the rest.
* "Always worn" stays Geralt's own gear only.
* Logs: `stored in loadout N (horse gear): ...`, `restored from loadout N onto the horse: ...`, `horse gear stays on:
  ...` with the reason, and the switch line ends `horse gear moved with the switch` or `horse gear stayed on`. The first
  inventory open after a load adds `horse gear kept by L1, L3` (or `no loadout holds horse gear yet`). `SLS_DebugState`
  marks horse pieces `(horse)`, a loadout that keeps horse gear `+horse`, and lists what the horse wears now.
* No new text on screen (no string-table change); the movie, bundle and settings XML are unchanged.
* The mod.io 1.0.3 file (in CD PROJEKT RED's review) was built before this and does not have horse gear.

* **Fixed: with no menu XML installed, the Loadouts setting was written and saved twice a second.** `SLS_Count` read
  an empty or missing `SimpleLoadoutSystem` / `LoadoutCount` as invalid, wrote the default and called
  `SaveUserSettings` - and the inventory's loadout column asks for the count twice a second (`SLS|poll`). With the
  menu XML in `bin\config` the first write made the value valid, so the Nexus build saved once; without it (the
  mod.io build, which cannot install `bin\config`) there is no settings group, nothing is ever valid, and every poll
  saved the user settings. Now `SLS_Count` only reads: a missing group, an empty value or one outside 1-10 reads as 10
  and writes nothing. The default is written by `SLS_WriteDefaultCount`, only when the group exists, and at most once
  per inventory menu, from the column's `SLS|ready` - never from the poll.
* **mod.io package** (`tools/package_modio.py`): the mod's `Mods\modSimpleLoadoutSystem` folder only, every path lower
  case, with `content\info.json` and the script cooked by REDkit into `precompiled.rsblob` beside the loose `.ws`.
  It has no `bin\config` menu XML (mod.io installs one folder), so the Loadouts slider is not there and the column
  always shows ten loadouts; its README says so.

## 1.0.2 - 2026-10-14 - working (the 'stash hiding fix' build, 7d60141, played in game by the owner from ~03:15; loadouts restored across a save load)

The owner, 2026-10-14: *"I want 10 loadout slots"*, *"I want the always on button to be at the top of the loadout
list"* and *"I want the AMF page for SLS to allow you to choose how many loadouts you want, up to 10."*

* **Fixed: stored loadouts were lost on every load** (the owner, 2026-10-14: "I just died, and when I respawned,
  loadouts 2 and 3 were empty"; `4. plans\sls-w3-loadouts-lost-on-load\FINDINGS.md`). The game does not save item
  tags added while playing, and 1.0.0-1.0.1 (and the first 1.0.2 test build) kept everything in such tags: which
  loadout a stash piece belonged to (`SLS_L<n>`), the stash list's hiding (`NoShowInContainer`) and the always-worn set
  (`SLS_Always`). After any load a stored piece belonged to no loadout and showed in the stash list, and the always-worn
  set was forgotten. Nothing was destroyed - the pieces stayed in the stash. Now, the way the game itself remembers
  stripped gear (`quest_function.ws` MarkEquippedItemsForReequip):
  * a stored piece carries the item modifier `SLS_Loadout` = its loadout's number (1-10; 0 = not stored), which is
    saved with the game. A switch back takes every stash piece with that number;
  * the stash list hides a stored piece with the game's own `NoShowInContainer` tag, as before, but the tag is now put
    back from `SLS_Loadout` on every inventory open, before the menu builds its lists (it is not saved, so a load
    drops it). Log: `stash hiding: N stored piece(s) hidden from the stash list (M tag(s) put back after a load)`.
    The first "persistent loadouts" test build hid them with a wrapper on `W3CommonContainerInventoryComponent
    .ShouldShowItem` alone, and the owner saw stored pieces listed in the stash (2026-10-14): the stash view's own
    `ShouldShowItem` reaches that class only through `super`, and the wrapper was most likely not reached that way. The
    wrapper now only logs once if it is reached for a stored piece (a diagnostic);
  * the always-worn set is the item modifier `SLS_Always` = 1 on Geralt's pieces, cleared when the set is chosen again;
  * the first inventory open after a load logs what the stash holds for each loadout ("first inventory open since the
    load: active loadout 2; stash holds 10 stored piece(s): L2=4, L3=6"), and `SLS_DebugState` reads the modifiers.
  **Upgrading: reassign your loadouts once.** Gear stored under 1.0.0-1.0.1 cannot be told apart after a load, so it is
  in the stash list as ordinary items: take it out of any stash, wear it, and select the loadout again (and choose the
  always-worn set again).
* **Ten loadouts.** Loadout 1-10 (was 1-4). The saved active-loadout fact is unchanged.
* **"Always worn" is at the top of the column**, above Loadout 1. Up/Down runs Always worn, Loadout 1, Loadout 2, ...
* **The Loadouts setting is a slider, 1 to 10, one loadout per nudge** (Options > Mods > Simple Loadout System and the
  same row on Apocrypha Menu Framework's page). It was a list of 4, 3, 2 and 1. The slider stores the count itself in
  both menus. The default is 10. An empty value (never set) is written as 10 the first time it is read, so the slider
  shows what the column shows. A count chosen before (1-4) is kept. Fewer loadouts only hide the higher boxes: the gear
  stored in them stays in the stash and comes back with the boxes.
* **A Loadouts change shows at once**, also while the inventory is open (AMF's page over it): the column asks the
  script twice a second, and the script rebuilds it only when the count changed ("loadouts setting changed: 4 -> 10"
  on the SimpleLoadoutSystem channel).
* **The column fits eleven boxes.** Each box is 44 high with 8 between (was 50 and 10), at the same place: x 763, 160
  wide, clear of the ARMOR grid's scroll bar (728-752) and the paperdoll's first slot frame (about 933), from y 232. The
  full column (Always worn + ten loadouts) ends at y 796, beside the paperdoll's Bombs / Pockets row, above the sort
  buttons' line (934) and the hint bar. The menu uses these units at every 16:9 resolution (1920x1080, 3200x1800).
  Still one column; navigation in and out (left stick, D-pad, right stick Jump Sections) and the one-push fix are
  unchanged.
* **Strings:** the list's choice labels (`sls_count_1..4` and their `preset_value_` keys) are gone, since the slider
  shows the number. "Loadout" + number is used for every box, so no new text was needed in the eleven languages.

## 1.0.1 - 2026-10-13 - working (the 'scroll bar + stick nav' build, 46261c4, tested in game by the owner 2026-10-13 ~23:00)

* **Fixed: the loadout column covered the ARMOR grid's scroll bar** (the owner's screenshot, 2026-10-13). The column
  started at x 724 on the menu, 186 wide; the grid's scroll bar runs at x 728-752 (the grid module at 105, its
  DefaultScrollBar at 623 inside it, the thumb 24 wide), so the boxes sat over it and took its mouse drags. The column
  now starts at x 763 and is 160 wide, in the middle of the gap between the scroll bar and the paperdoll's first slot
  frame (about x 933). The labels still fit; a long translation shrinks as before.
* **Fixed: the left stick went straight past the column** (the owner, 2026-10-13: Weapons -> Armor -> the equipped
  slots, never the boxes). The script log showed "column focus: on" and "column focus: off" back to back: the column
  did take the focus, and a second sideways press from the same push took it straight on to the paperdoll. One push now
  moves one place: a sideways press that comes within 250 ms of the column taking or giving up the focus is the same
  push and is swallowed (leaving still needs a fresh press, as before). The right stick's Jump Sections (Left/Right)
  now stops at the column as well and leaves it again; before, it jumped over the column, and while the column had the
  focus it did nothing at all. Every move into, out of and within the column is logged on the SimpleLoadoutSystem
  channel ("column navigation: in from the item grid: right code ... +0ms", "same push, ignored ..."), so a test shows
  which press did what.

* **Fixed: the settings menu's labels.** The menu looks its labels up with prefixes (`panel_` for the group, `option_` for
  the setting, `preset_value_` for each choice), and the string tables only held the bare keys. So Apocrypha Menu
  Framework made up a name for the mod from "sls_menu" (the owner saw "SLs"), and the game's own Options > Mods would
  have shown `##panel_sls_menu`. The tables now carry `panel_sls_menu` ("Simple Loadout System"),
  `option_sls_menu_count` and `preset_value_sls_count_1..4` in all 18 language files; the bare keys stay for the script.
* **Fixed: the loadout boxes stayed over the character stats page** (RT in the inventory; the owner, 2026-10-07). The
  menu's own OnPlayerStatsShown / OnPlayerStatsHidden are wrapped: the column steps aside (and gives up the pad's focus)
  while the stats page is up and comes back with the items, told through a new "inventory.sls.statsUp" binding.
  Then (the owner: the buttons went too late; "look into how the inventory hides its own armor and weapons sections"):
  the column is one of the menu's own fade-out sections now (CharacterRendererController.addFadeOutComponent, the same
  0.5 s Sine.easeOut alpha tween as the item grid and the paperdoll, in the same frame), and the renderer's
  ACTIVATE / DEACTIVATE stop and give back its input at once; the script's flag is only a backstop.
* **Fixed: the "stats page fade" build broke the whole inventory** (the owner's game, 2026-10-13: the right side one big
  MISSING PICTURE box, the item grid empty; Witcher Gear Overhaul's "values (inventory)" line never logged). The column's
  layer was a Sprite and the renderer's fade list is a `Vector.<MovieClip>`, so `addFadeOutComponent` threw in the menu's
  start-up - and the column started up just BEFORE the menu tells the game it is ready (`OnConfigUI`), so that call never
  went out: no grid, no character preview, no OnConfigUI for any other mod. Now the layer is a MovieClip (a valid fade
  section, so the stats-page fade stays), the column starts AFTER `OnConfigUI`, and its start-up, input, per-frame and
  data handlers are each wrapped: an error switches the column off for that menu, is logged on the SimpleLoadoutSystem
  channel ("ERROR in the loadout column ..."), and the inventory works as if the mod were not there.
* **Build: no build path in the movie.** REDkit's swfimport records the source .swf's absolute path in the .redswf
  (editor-only, for re-import); `build_flash.py` now rewrites it to the bare file name and fixes every size, offset
  and CRC after it, checking all of them before and after.
* **Fixed: "no flash value storage yet" on every inventory open.** The movie's request can come before the base menu
  sets its value storage; the script now fetches it itself (GetMenuFlashValueStorage, as the base menu does).

## 1.0.0 - first build (2026-10-06)

The owner, 2026-10-06: *"start building the simple loadout system. I want four or five buttons to be positioned
vertically in between the armor area and the equip slots, which can be navigated to with the controller. The same
logic as the other SLS mods."*

* **The column**: five boxes - four loadouts and "Always worn" - in the inventory's own movie (inserted into the
  game's `MenuInventory` class at build time, as Unbind Vanilla Controls W3 does for its page), between the ARMOR panel
  and the paperdoll's first slot column, in the game's frame shape (thin outer line, inner line with stepped corners).
  Shown on the player's own inventory only (not in a shop, container, stash or horse view).
* **Controller**: Right at the item grid's right edge (or Left at the paperdoll's left edge) enters the column; Up/Down
  move, A selects, Left/Right leave toward the grid / paperdoll, B closes the menu; the module the column was entered
  from is unfocused meanwhile so it does not react too. Keyboard arrows + E/Enter, and mouse clicks.
* **The switch** (the Skyrim model): the worn gear is the loadout; storing goes to the stash with a per-loadout tag and
  the game's NoShowInContainer tag (hidden from the stash's list), restoring puts each piece back on; from no loadout
  the gear comes off and stays; "Always worn" captures what is worn when it is left, keeps it on through switches, a
  loadout's own piece wins its slot. Gear = swords, armour, gloves, trousers, boots, crossbow, bolts; quest and NoDrop
  items only taken off; the infinite bolts left alone. No switching in combat (the game's own message). Runs only from
  a box's A press, with the inventory open.
* **The bridge**: the movie calls the base menu's OnBreakPoint event (which the game only logs) with "SLS|..." texts;
  the script wraps it - no new event, no vanilla script replaced.
* **Settings**: Options > Mods > Simple Loadout System > Loadouts (1-4, default 4).
* **Languages**: all eighteen of the game's language files; our eleven translated, esmx as Spanish, zh in traditional
  characters, the rest English.
* **Refresh after a switch** (the owner's first test, 2026-10-06: "whatever was last equipped seems to appear whenever you
  unequip everything when switching to an empty loadout" and "I have no clothes on, even though the gear is equipped in
  the inventory ... there might be a refresh issue"): the switch now does what the menu's own equip and unequip do - each
  piece taken off leaves its paperdoll slot (PaperdollRemoveItem), and the 3D Geralt beside the paperdoll, a separate GUI
  scene entity, is told to take the player's items again (UpdateGuiSceneEntityItems). The first build never told it, so
  it kept whatever it last wore.
* **The column takes its presses first** (the owner's retest, 2026-10-06: "the model for an armor automatically gets
  applied to the chest ... after switching between the first and second loadouts repeatedly, it changes to a different
  armor"; the script log showed "Medium armor 11" and "Light armor 04", which he never equipped, stored as loadout gear).
  The column read its presses after the menu's modules, and the item grid - though unfocused - still acted on A: its list
  equipped the armour under its cursor, the piece beside the column, and the switch that followed stored it. While the
  column has the focus it now takes every press first (stage capture and bubble listeners at priority 100) and passes
  only B on, so the grid and the paperdoll never see a press meant for the column.
* **The grid's own actions are off while the column has the focus** (the third retest, 2026-10-06: "whenever I press
  loadout one, it selected the armor next to it"; his screenshot: the ARMOR grid still selecting the item beside the column,
  its tooltip open, the hint bar offering its actions). The press that equipped it never went through our movie: the hint
  bar belongs to the common menu, another movie, and its A reaches the inventory script as OnInputHandled, which hands it
  to the grid's item context and its primary action - equip. Now, as the menu itself does while the player-stats panel is
  up, the column's focus deactivates that context (its buttons leave the hint bar) and the script does not pass
  OnInputHandled on until the focus leaves the column; the movie also blocks the grid's tooltip meanwhile. The earlier
  "takes its presses first" change stays: it keeps the grid's list from moving under the column's Up/Down.
* **Observability**: every decision is logged on the `SimpleLoadoutSystem` channel; `SLS_DebugState()` returns the
  active loadout and each loadout's stored pieces for a test run (read-only).
