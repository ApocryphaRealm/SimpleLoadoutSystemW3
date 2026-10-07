# Changelog - Simple Loadout System (The Witcher 3)

Versions are issued by the project's version gate. Written as the change happens (rule 61).

## 1.0.1 - 2026-10-07 - untested

* **Fixed: the settings menu's labels.** The menu looks its labels up with prefixes (`panel_` for the group, `option_` for
  the setting, `preset_value_` for each choice), and the string tables only held the bare keys. So Apocrypha Menu
  Framework made up a name for the mod from "sls_menu" (the owner saw "SLs"), and the game's own Options > Mods would
  have shown `##panel_sls_menu`. The tables now carry `panel_sls_menu` ("Simple Loadout System"),
  `option_sls_menu_count` and `preset_value_sls_count_1..4` in all 18 language files; the bare keys stay for the script.
* **Fixed: the loadout boxes stayed over the character stats page** (RT in the inventory; the owner, 2026-10-07). The
  menu's own OnPlayerStatsShown / OnPlayerStatsHidden are wrapped: the column steps aside (and gives up the pad's focus)
  while the stats page is up and comes back with the items, told through a new "inventory.sls.statsUp" binding.
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
