# Changelog - Simple Loadout System (The Witcher 3)

Versions are issued by the project's version gate. Written as the change happens (rule 61).

## Unreleased - first build (2026-10-06)

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
* **Observability**: every decision is logged on the `SimpleLoadoutSystem` channel; `SLS_DebugState()` returns the
  active loadout and each loadout's stored pieces for a test run (read-only).
