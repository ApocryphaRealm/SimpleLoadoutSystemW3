# Simple Loadout System (The Witcher 3: Wild Hunt - Remastered)

Loadout boxes inside the game's inventory, between the item grid and the equipment slots, built for the controller -
the [Skyrim Simple Loadout System for Controller](https://github.com/ApocryphaRealm/SimpleLoadoutSystemForController)
carried to The Witcher 3 5.0. Pick a loadout and everything you equip while it is active becomes that loadout; switch
away and the gear goes into that loadout's storage (the stash, hidden from its list), out of your inventory and its
weight; pick it again and it all comes back and is put on. "Always worn" keeps chosen pieces on through every switch.

* What the player gets: `dist/README.txt`
* What changed: `CHANGELOG.md`
* The plan: `4. plans\Simple Loadout System for Witcher 3\PLAN.md` (project)

## Building

* Python 3, FFDec (`ffdec-cli.exe`) and The Witcher 3 REDkit (for `wcc_lite` and the inventory's source movie).
* `python tools/build_flash.py` - the inventory movie with the loadout column, packed into the mod's own
  `blob0.bundle` + `metadata.store`.
* `python tools/gen_strings.py` - the `.w3strings` tables (`--check` compares them with the table).

## Licence

GPL-3.0-or-later (`LICENSE`, `NOTICE.md`). The inventory movie is CD PROJEKT RED's and is not in this repository.
