# Simple Loadout System (The Witcher 3) - copyright and licence

Copyright (C) 2026 ApocryphaRealm

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public
License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied
warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program (`LICENSE`). If not, see
<https://www.gnu.org/licenses/>.

SPDX-License-Identifier: GPL-3.0-or-later

## What is ours, and what is not

Ours: the WitcherScript (`dist/Mods/modSimpleLoadoutSystem/content/scripts/local/SimpleLoadoutSystem.ws`), the
ActionScript inserted into the inventory menu (`flash/sls_column.as.txt`), the settings XML, the string tables and
their generator, and the build tools.

Not ours: the inventory screen's movie (`panel_inventory.redswf`) is CD PROJEKT RED's. It is never in this repository:
`tools/build_flash.py` reads it from the player's own REDkit install, inserts our code and rebuilds it with REDkit's
`wcc_lite` (the Witcher III Modding Tool, whose rules the owner accepted on 2026-10-06; the README carries the line they
ask for). The built `blob0.bundle` ships in the mod's download only.
