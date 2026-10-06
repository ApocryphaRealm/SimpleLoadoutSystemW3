Witcher III Modding Tool, developed and released by CD PROJEKT RED

Simple Loadout System (The Witcher 3: Wild Hunt - Remastered)
Version 0.0.0

Loadouts inside the game's inventory, built for the controller. A column of boxes sits between the item grid and the
equipment slots: four loadouts and "Always worn". Pick a loadout and everything you equip while it is active becomes
that loadout. Switch to another loadout - or back to none - and the gear you were wearing goes into that loadout's own
storage, out of your inventory and your carry weight. Pick it again and it all comes back and is put on.


HOW IT WORKS
- Controller: on the inventory screen, press Right at the right edge of the item grid (or Left at the left edge of the
  equipment slots) to reach the column. Up / Down choose a box, A selects it (A on the active loadout deselects it),
  Left goes back to the items, Right on to the equipment slots, B closes the inventory as always.
  Keyboard and mouse: the arrow keys and E or Enter, or click a box.
- Selecting a loadout takes off the gear you are wearing. Those items stay in your inventory - they belonged to no
  loadout. If the loadout already holds gear, it comes back and is put on.
- While a loadout is active, whatever you equip is part of it, and whatever you take off leaves it and is an ordinary
  inventory item again, ready for another loadout.
- Switching away stores the gear you are wearing in that loadout's storage. The inventory itself is the loadout view: a
  loadout's gear is in your inventory only while that loadout is active.
- Always worn: select "Always worn", put on what you always want on, then pick a loadout or press A on "Always worn"
  again: whatever you were wearing when you left the box is the always-worn set, and a message says how many pieces it
  holds. Switching never stores or takes off those pieces. If a loadout holds its own piece for the same slot, the
  loadout's piece is worn and the always-worn one waits in your inventory until the slot is free again.
- Loadout gear: both swords, armour, gloves, trousers, boots, crossbow and bolts. Potions, bombs, pocket items, masks,
  trophies and horse gear are left alone. Quest items are only taken off, never stored; the infinite bolts stay as they
  are.
- Where the gear is kept: the stash - the one every stash chest in the world opens. Stored loadout gear is hidden from
  the stash's list, so it is not taken out by mistake.
- You cannot change loadouts in combat.


SETTINGS
Options > Mods > Simple Loadout System (also on the Apocrypha Menu Framework's Mods row):
- Loadouts: how many loadout boxes the column shows (1-4, default 4). "Always worn" is always there.


INSTALL
Copy the Mods and bin folders into the game folder (or install with Mod Organizer 2 or Vortex). No script merging is
needed: the mod changes no script of the game's, it only adds to them. It replaces the inventory screen's movie
(panel_inventory.redswf), so it does not combine with another mod that replaces that same file.

The column's text follows the game's language (English, Japanese, Korean, Chinese, Russian, German, French, Spanish,
Italian, Polish and Czech).


REQUIREMENTS
The Witcher 3: Wild Hunt - Remastered (patch 5.0 or later).


LICENCE
GPL-3.0-or-later (LICENSE, NOTICE.md). Source: https://github.com/ApocryphaRealm/SimpleLoadoutSystemW3
The inventory movie is CD PROJEKT RED's, changed by this mod and rebuilt with the Witcher III Modding Tool (REDkit).
