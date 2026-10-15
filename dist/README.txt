Witcher III Modding Tool, developed and released by CD PROJEKT RED

Simple Loadout System (The Witcher 3: Wild Hunt - Remastered)
Version 0.0.0

Loadouts inside the game's inventory, built for the controller. A column of boxes sits between the item grid and the
equipment slots: "Always worn" at the top, then up to ten loadouts. Pick a loadout and everything you equip while it is active becomes
that loadout. Switch to another loadout - or back to none - and the gear you were wearing goes into that loadout's own
storage, out of your inventory and your carry weight. Pick it again and it all comes back and is put on.


HOW IT WORKS
- Controller: on the inventory screen, push the left stick (or the D-pad) Right at the right edge of the item grid, or
  Left at the left edge of the equipment slots, to reach the column; the right stick's Jump Sections stops there too.
  Up / Down choose a box, A selects it (A on the active loadout deselects it), Left goes back to the items, Right on
  to the equipment slots, B closes the inventory as always.
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
- Loadout gear: both swords, armour, gloves, trousers, boots, crossbow and bolts, plus Roach's saddle, saddlebags and
  blinders and your trophy. Potions, bombs, pocket items and masks are left alone. Quest items are only taken off,
  never stored; the infinite bolts stay as they are.
- Horse gear and the trophy belong to the loadout they were worn in, like the rest of the gear: switching away stores
  them in that loadout, and selecting a loadout puts its own horse gear and trophy back on - a loadout that holds none
  leaves Roach bare. They are put on and taken off the way the inventory screen does it, so Roach shows the change at
  once when she is near, or the next time you call her when she is not. Horse gear and the trophy can be always worn
  too, exactly like Geralt's pieces: whatever is on Roach (and your trophy) when you leave "Always worn" stays on
  through every switch, unless a loadout holds its own piece for that slot.
- Skills and mutagens: each loadout also remembers the skills in your skill slots and the mutagens in your mutagen
  slots. Switching away records them; selecting a loadout takes every skill and mutagen out and puts its own back in.
  Only what you still have can come back: a skill you no longer know, a slot that is locked, or a mutagen that is no
  longer in your inventory is skipped. Mutagens never leave your inventory.
- "Always worn" has a skill set and mutagens too: whatever skills and mutagens are equipped when you leave the box.
  A loadout that has no skills of its own gets the always-worn skills, and one with no mutagens of its own gets the
  always-worn mutagens (each decided on its own). No loadout at all also uses the always-worn skills and mutagens.
- The extra bonus a mutagen gets from matching skill colours is set again straight after every switch, the same way
  the Character screen sets it.
- Upgrading from 1.0.2: your loadouts hold no horse gear yet. The first time you leave each one, Roach's gear and your
  trophy are stored in it; until then, selecting it leaves Roach bare (her gear is safe in the loadout you left).
- Where the gear is kept: the stash - the one every stash chest in the world opens. Stored loadout gear is hidden from
  the stash's list, so it is not taken out by mistake. Loadouts and the always-worn set are saved with your game.
- Upgrading from 1.0.0 or 1.0.1: those versions lost their loadouts at every load (the stored gear stayed in the
  stash, listed as ordinary items). Assign your loadouts once more: take the gear out of any stash, wear a set, select
  its loadout, and choose the always-worn set again. From this version on they survive saving and loading.
- You cannot change loadouts in combat.


SETTINGS
Options > Mods > Simple Loadout System (also on the Apocrypha Menu Framework's Mods row):
- Loadouts: how many loadout boxes the column shows - a slider, 1 to 10 (default 10). "Always worn" is always there,
  at the top. Fewer loadouts only hides the higher boxes; the gear stored in them stays and is back when the boxes are.
  A change made while the inventory is open shows in the column straight away.


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
