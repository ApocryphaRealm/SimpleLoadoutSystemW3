// Simple Loadout System (The Witcher 3: Wild Hunt - Remastered) - the loadout switch.
// Copyright (C) 2026 ApocryphaRealm. GPL-3.0-or-later (LICENSE, NOTICE.md).
//
// The loadout column is drawn by the inventory menu's own Flash (this mod's panel_inventory.redswf, built by
// tools/build_flash.py): "Always worn" at the top, then up to ten loadout boxes, between the item grid and the
// paperdoll. A box's A press
// reaches this script through the base menu's OnBreakPoint event, which the game uses only for a log line: the movie
// sends "SLS|activate|<box>"; "SLS|ready" asks for the boxes' state. Only annotations here - no vanilla script is
// replaced, so nothing needs merging.
//
// The model is the Skyrim mod's (Simple Loadout System for Controller 1.0.2):
// - The worn gear is the loadout. Pick a loadout and what you wear from then on is that loadout; pick another (or the
//   same one again, which deselects it) and what you wear goes into the loadout's own storage, out of your inventory
//   and its weight, and the next loadout's gear comes back and is put on.
// - From no loadout, the worn gear comes off and stays in the inventory (it belonged to no loadout).
// - "Always worn": select it, wear what should stay on through every switch, leave it - that is the set. A switch
//   never stores or takes off those pieces; a loadout's own piece for the same slot wins and the always-worn one goes
//   back on when the slot is free.
// - Nothing moves except in the switch a box's A press starts, with the inventory open (the owner's rule for every SLS).
// - Gear: both swords, armour, gloves, trousers, boots, crossbow and bolts. Quest items and items the game will not let
//   go (NoDrop) are only taken off, never stored; the infinite bolts are left alone.
// - Horse gear (1.0.3, the owner: "I want the horse equipment and trophy to also be able to be saved into a loadout"):
//   Roach's saddle, saddlebags, blinders and Geralt's trophy (EES_HorseSaddle, EES_HorseBag, EES_HorseBlinders,
//   EES_HorseTrophy) are locked to the loadout they were worn in, like the rest of the gear - see "horse gear" below.
//   They can be always worn too, exactly like Geralt's pieces (SLS_Always on the piece; a loadout's own piece for the
//   slot wins while that loadout is on, and the always-worn one goes back on when the slot is free).
// - Skills and mutagens (1.0.3, the owner: "i want the loadout to remember which skills and mutagens were equipped in
//   that loadout as well ... only currently known and activated abilities can be saved in the loadout", and "make it
//   also affected by the always worn so that loadouts that dont have a set of skills and abilities and mutagens will use
//   the always worn set"): see "skills and mutagens" below.
// - No switching in combat.
//
// Storage: the shared stash - the horse manager's inventory, the one every stash in the world opens (inventoryMenu.ws:
// IMS_Stash shows _horseInv). It follows Geralt to every region, is saved with the game and weighs nothing.
// A stored piece carries the ITEM MODIFIER SLS_Loadout = its loadout's number (1..10; 0 = not stored), and the
// always-worn set carries the item modifier SLS_Always = 1 on Geralt's own items. Item modifiers are saved with the
// game; run-time item tags (AddItemTag) are NOT - 1.0.0, 1.0.1 and the first 1.0.2 test build kept loadouts in tags,
// and every stored loadout was forgotten at the next load (the owner, 2026-10-14; 4. plans\sls-w3-loadouts-lost-on-load\FINDINGS.md). The game
// itself remembers stripped gear the same way (quest_function.ws MarkEquippedItemsForReequip, SetItemModifierInt).
// The stash's list hides a stored piece with the game's own NoShowInContainer tag (W3CommonContainerInventoryComponent
// .ShouldShowItem), the way 1.0.0-1.0.1 did within a session. That tag is not saved, so it is put back from the modifier
// on every inventory open, before the menu builds its lists (SLS_SyncStashTags in the OnConfigUI wrapper): the modifier
// is the saved truth, the tag only what the list reads. The active loadout is a fact (sls_active), saved with the game.
//
// Horse gear. An equipped horse item already lives in that same stash: the horse manager's inventory holds it and its
// saved itemSlots names it (horseManager.ws). It is taken off and put on only through the game's own path, the one the
// inventory menu uses (inventoryMenu.ws OnEquipItem / OnUnequipItem): W3HorseManager.UnequipItem(slot), which hands the
// item to Geralt's inventory, and MoveItemToHorse + W3HorseManager.EquipItem from Geralt's inventory. Mods that change
// horse gear (The Stable replaces EquipItem / UnequipItem) therefore run as they do for the menu, and the live horse is
// updated by those functions when it is spawned, or from itemSlots when it next spawns (ApplyHorseUpdateOnSpawn). A
// stored horse piece is an ordinary stored piece: SLS_Loadout on the stash item and the NoShowInContainer tag.
// Horse gear is locked to the loadout it was worn in, like Geralt's gear (the owner's first test, 2026-10-15: with an
// exception that kept Roach's gear on for loadouts stored before 1.0.3, "the horse gear stayed equipped in all of them
// instead of being locked into one of them"). Leaving ANY loadout stores what Roach wears into it; entering one puts on
// what it holds, and a loadout that holds no horse gear leaves her bare in those slots - nothing is lost, it is in the
// loadout that was left. Between none and Always worn her gear is taken off into Geralt's inventory, as his own is.
// The saved fact sls_horse_<n> = 1 records that a loadout's storage holds its horse gear (for the logs and
// SLS_DebugState only; no decision reads it).

// ---- settings ----------------------------------------------------------------------------------------------------

// Ten loadouts since 1.0.2 (the owner, 2026-10-14: "I want 10 loadout slots"); 1.0.0-1.0.1 had four.
function SLS_MaxLoadouts() : int
{
	return 10;
}

// Options > Mods > Simple Loadout System > Loadouts (and the same row on Apocrypha Menu Framework's page): a slider,
// 1 to 10, one loadout per nudge (SimpleLoadoutSystem.xml SLIDER;1;10;9). The value is the count itself. The column
// always starts with "Always worn". Default 10, the most there are. A count chosen before 1.0.2 (1-4, from the old
// list) is kept as it is. Fewer loadouts only hides the higher boxes: their stored gear stays where it is.
//
// SLS_Count only READS - it runs from the column's twice-a-second poll. A value that is empty (never set), not a count
// 1-10, or a settings group that does not exist at all (the mod.io build ships no bin\config menu XML, so there is no
// slider and no group) reads as 10 and writes nothing. 1.0.0-1.0.2 wrote and saved the user settings here on every
// invalid read, which with no menu XML meant a settings save from every poll (1.0.3).
function SLS_Count() : int
{
	var cfg : CInGameConfigWrapper;
	var raw : string;
	var count : int;

	cfg = theGame.GetInGameConfigWrapper();
	if (!cfg || cfg.GetGroupIdx("SimpleLoadoutSystem") < 0)
	{
		return SLS_MaxLoadouts();
	}
	raw = cfg.GetVarValue('SimpleLoadoutSystem', 'LoadoutCount');
	// a slider may store "7" or "7.000000"
	count = RoundF(StringToFloat(raw, -1.0));
	if (count < 1 || count > SLS_MaxLoadouts())
	{
		return SLS_MaxLoadouts();
	}
	return count;
}

// Writes the default (10) into the Loadouts slider once, so the slider shows what the column shows - only when the
// settings group exists (the menu XML is installed) and its value is empty or not a count 1-10. Called once per
// inventory menu, from the column's "SLS|ready" (SLS_OnMovie, guarded by slsDefaultChecked), never from the poll.
function SLS_WriteDefaultCount()
{
	var cfg : CInGameConfigWrapper;
	var raw : string;
	var count : int;

	cfg = theGame.GetInGameConfigWrapper();
	if (!cfg || cfg.GetGroupIdx("SimpleLoadoutSystem") < 0)
	{
		return;
	}
	raw = cfg.GetVarValue('SimpleLoadoutSystem', 'LoadoutCount');
	count = RoundF(StringToFloat(raw, -1.0));
	if (count >= 1 && count <= SLS_MaxLoadouts())
	{
		return;
	}
	cfg.SetVarValue('SimpleLoadoutSystem', 'LoadoutCount', IntToString(SLS_MaxLoadouts()));
	theGame.SaveUserSettings();
	SLS_Log("loadouts setting was '" + raw + "' - set to the default " + IntToString(SLS_MaxLoadouts()));
}

// ---- state -------------------------------------------------------------------------------------------------------

// -1 no loadout, -2 Always worn, 0..9 a loadout. Kept as value + 3 so a missing fact (0) reads as none.
function SLS_Active() : int
{
	var stored : int;

	stored = FactsQuerySum("sls_active");
	if (stored < 1 || stored > SLS_MaxLoadouts() + 2)
	{
		return -1;
	}
	return stored - 3;
}

function SLS_SetActive(active : int)
{
	FactsRemove("sls_active");
	FactsAdd("sls_active", active + 3, -1);
	SLS_Log("active loadout is now " + SLS_Describe(active));
}

function SLS_Describe(active : int) : string
{
	if (active == -1)
	{
		return "none";
	}
	if (active == -2)
	{
		return "Always worn";
	}
	return "loadout " + IntToString(active + 1);
}

function SLS_Log(text : string)
{
	LogChannel('SimpleLoadoutSystem', text);
}

// ---- what is stored (item modifiers, saved with the game) --------------------------------------------------------

// The stash pieces stored in a loadout (0..9): SLS_Loadout == loadout + 1.
function SLS_StoredIn(stash : CInventoryComponent, loadout : int) : array<SItemUniqueId>
{
	var all, items : array<SItemUniqueId>;
	var i : int;

	stash.GetAllItems(all);
	for (i = 0; i < all.Size(); i += 1)
	{
		if (stash.GetItemModifierInt(all[i], 'SLS_Loadout', 0) == loadout + 1)
		{
			items.PushBack(all[i]);
		}
	}
	return items;
}

// Geralt's always-worn pieces: SLS_Always == 1.
function SLS_AlwaysItems(inv : CInventoryComponent) : array<SItemUniqueId>
{
	var all, items : array<SItemUniqueId>;
	var i : int;

	inv.GetAllItems(all);
	for (i = 0; i < all.Size(); i += 1)
	{
		if (inv.GetItemModifierInt(all[i], 'SLS_Always', 0) > 0)
		{
			items.PushBack(all[i]);
		}
	}
	return items;
}

// One line for the log: how many pieces each loadout holds in the stash ("stash holds 10 stored piece(s): L2=4, L3=6").
function SLS_StashSummary(stash : CInventoryComponent) : string
{
	var items : array<SItemUniqueId>;
	var text : string;
	var i, total : int;

	text = "";
	total = 0;
	for (i = 0; i < SLS_MaxLoadouts(); i += 1)
	{
		items = SLS_StoredIn(stash, i);
		if (items.Size() > 0)
		{
			if (total > 0)
			{
				text += ", ";
			}
			text += "L" + IntToString(i + 1) + "=" + IntToString(items.Size());
			total += items.Size();
		}
	}
	if (total == 0)
	{
		return "stash holds 0 stored pieces" + SLS_HorseKeptSummary();
	}
	return "stash holds " + IntToString(total) + " stored piece(s): " + text + SLS_HorseKeptSummary();
}

// "; horse gear kept by L1, L3" - the loadouts whose storage holds their horse gear (sls_horse_<n>); empty when none.
function SLS_HorseKeptSummary() : string
{
	var text : string;
	var i : int;

	text = "";
	for (i = 0; i < SLS_MaxLoadouts(); i += 1)
	{
		if (SLS_HorseKept(i))
		{
			if (text != "")
			{
				text += ", ";
			}
			text += "L" + IntToString(i + 1);
		}
	}
	if (text == "")
	{
		return "; no loadout holds horse gear yet";
	}
	return "; horse gear kept by " + text;
}

// Puts the game's NoShowInContainer tag on every stash piece a loadout holds (SLS_Loadout > 0), so the stash's list
// leaves it out. Run-time tags are not saved, so after a load every stored piece has lost it; this runs on every
// inventory open, before the lists are built. A tag on a piece that is not stored is left alone (it may be the game's).
function SLS_SyncStashTags(stash : CInventoryComponent) : int
{
	var all : array<SItemUniqueId>;
	var i, stored, added : int;

	stash.GetAllItems(all);
	stored = 0;
	added = 0;
	for (i = 0; i < all.Size(); i += 1)
	{
		if (stash.GetItemModifierInt(all[i], 'SLS_Loadout', 0) > 0)
		{
			stored += 1;
			if (!stash.ItemHasTag(all[i], 'NoShowInContainer'))
			{
				stash.AddItemTag(all[i], 'NoShowInContainer');
				added += 1;
			}
		}
	}
	SLS_Log("stash hiding: " + IntToString(stored) + " stored piece(s) hidden from the stash list (" + IntToString(added) + " tag(s) put back after a load)");
	return stored;
}

// ---- gear --------------------------------------------------------------------------------------------------------

function SLS_GearSlots() : array<EEquipmentSlots>
{
	var slots : array<EEquipmentSlots>;

	slots.PushBack(EES_SteelSword);
	slots.PushBack(EES_SilverSword);
	slots.PushBack(EES_Armor);
	slots.PushBack(EES_Gloves);
	slots.PushBack(EES_Pants);
	slots.PushBack(EES_Boots);
	slots.PushBack(EES_RangedWeapon);
	slots.PushBack(EES_Bolt);
	return slots;
}

// Pieces the game must keep: quest items and items it will not transfer. They are only ever taken off.
function SLS_MustStay(inv : CInventoryComponent, item : SItemUniqueId) : bool
{
	return inv.IsItemQuest(item) || (inv.ItemHasTag(item, 'NoDrop') && !inv.ItemHasTag(item, 'Lootable'));
}

// ---- horse gear --------------------------------------------------------------------------------------------------

// Roach's three slots and Geralt's trophy slot (itemsTypes.ws EEquipmentSlots). Their items are held by the horse
// manager, not by Geralt's own itemSlots.
function SLS_HorseSlots() : array<EEquipmentSlots>
{
	var slots : array<EEquipmentSlots>;

	slots.PushBack(EES_HorseSaddle);
	slots.PushBack(EES_HorseBag);
	slots.PushBack(EES_HorseBlinders);
	slots.PushBack(EES_HorseTrophy);
	return slots;
}

// A horse piece (saddle, saddlebags, blinders or trophy), by the game's own test (inventoryComponent.ws
// GetHorseSlotForItem: the Saddle / HorseBag / Trophy / Blinders tags).
function SLS_IsHorseItem(inv : CInventoryComponent, item : SItemUniqueId) : bool
{
	return inv.GetHorseSlotForItem(item) != EES_InvalidSlot;
}

// True when a loadout's (0..9) storage holds its horse gear - the saved fact sls_horse_<loadout + 1>, set by 1.0.3 every
// time it stores into that loadout. A loadout last stored by 1.0.0-1.0.2 does not have it. Read by the logs only.
function SLS_HorseKept(loadout : int) : bool
{
	return FactsQuerySum("sls_horse_" + IntToString(loadout + 1)) > 0;
}

function SLS_SetHorseKept(loadout : int, holds : bool)
{
	FactsRemove("sls_horse_" + IntToString(loadout + 1));
	if (holds)
	{
		FactsAdd("sls_horse_" + IntToString(loadout + 1), 1, -1);
	}
}

// Takes Roach's gear and Geralt's trophy off through the game's own path (W3HorseManager.UnequipItem, which hands each
// piece to Geralt's inventory, as the inventory menu does); with a loadout to leave, each piece then goes to the
// loadout's storage like any other piece. Quest and kept (NoDrop) horse pieces stay on the horse. Returns how many
// pieces could not be stored.
function SLS_StoreHorse(menu : CR4InventoryMenu, hm : W3HorseManager, inv : CInventoryComponent, stash : CInventoryComponent, from : int, out stored : int) : int
{
	var slots : array<EEquipmentSlots>;
	var worn, back, moved : SItemUniqueId;
	var itemName : name;
	var i, kept : int;

	slots = SLS_HorseSlots();
	kept = 0;
	stored = 0;
	for (i = 0; i < slots.Size(); i += 1)
	{
		worn = hm.GetItemInSlot(slots[i]);
		if (!stash.IsIdValid(worn))
		{
			continue;
		}
		itemName = stash.GetItemName(worn);
		if (stash.GetItemModifierInt(worn, 'SLS_Always', 0) > 0)
		{
			SLS_Log("stays on (always worn, horse gear): " + NameToString(itemName));
			continue;
		}
		if (SLS_MustStay(stash, worn))
		{
			if (from >= 0)
			{
				kept += 1;
			}
			SLS_Log("stays on the horse, cannot be stored: " + NameToString(itemName));
			continue;
		}
		// the menu's paperdoll shows the piece under its stash id, which UnequipItem gives up
		menu.PaperdollRemoveItem(worn);
		back = hm.UnequipItem(slots[i]);
		if (!inv.IsIdValid(back))
		{
			if (from >= 0)
			{
				kept += 1;
			}
			SLS_Log("could not take " + NameToString(itemName) + " off the horse - it stays where the game left it");
			continue;
		}
		if (from < 0)
		{
			SLS_Log("taken off the horse, stays in the inventory: " + NameToString(itemName));
			continue;
		}
		moved = inv.GiveItemTo(stash, back, 1, false, false, false);
		if (moved == GetInvalidUniqueId())
		{
			kept += 1;
			SLS_Log("could not store " + NameToString(itemName) + " - it stays in the inventory");
			continue;
		}
		stash.SetItemModifierInt(moved, 'SLS_Loadout', from + 1);
		stash.AddItemTag(moved, 'NoShowInContainer');
		stored += 1;
		SLS_Log("stored in " + SLS_Describe(from) + " (horse gear): " + NameToString(itemName));
	}
	return kept;
}

// Puts a horse piece that has just come back to Geralt's inventory on the horse - the inventory menu's own path
// (inventoryMenu.ws OnEquipItem): MoveItemToHorse, then W3HorseManager.EquipItem, which mounts it on the live horse when
// she is spawned and is applied from itemSlots when she next spawns. Returns the piece's id on the horse (in the stash),
// or an invalid id when it did not end up equipped.
function SLS_EquipHorse(menu : CR4InventoryMenu, hm : W3HorseManager, inv : CInventoryComponent, stash : CInventoryComponent, item : SItemUniqueId) : SItemUniqueId
{
	var onHorse, displaced : SItemUniqueId;
	var itemName : name;

	itemName = inv.GetItemName(item);
	onHorse = hm.MoveItemToHorse(item, 1);
	if (!stash.IsIdValid(onHorse))
	{
		SLS_Log("could not hand " + NameToString(itemName) + " to the horse - it stays in the inventory");
		return GetInvalidUniqueId();
	}
	// a stored loadout number must never sit on a piece the horse wears (it would count as stored)
	stash.SetItemModifierInt(onHorse, 'SLS_Loadout', 0);
	displaced = hm.EquipItem(onHorse);
	if (inv.IsIdValid(displaced))
	{
		SLS_Log("the horse's " + NameToString(inv.GetItemName(displaced)) + " was replaced and is in the inventory");
	}
	if (!hm.IsItemEquipped(onHorse))
	{
		SLS_Log("back in the stash but not put on the horse: " + NameToString(itemName));
		return GetInvalidUniqueId();
	}
	menu.PaperdollUpdateHorseItem(onHorse);
	return onHorse;
}

// ---- skills and mutagens -----------------------------------------------------------------------------------------
//
// Each loadout remembers the skills in Geralt's skill slots and the mutagens in his four mutagen slots, and so does the
// always-worn set. 5.01's character screen (characterMenuDupe.ws, the Remastered tree) still equips through the slot
// system, and SLS uses exactly its calls: CR4Player.EquipSkill(skill, slotID) / UnequipSkill(slotID), and for mutagens
// W3PlayerWitcher.EquipItemInGivenSlot(item, EES_SkillMutagenN, false) / UnequipItemFromSlot(slot) - so the skill
// abilities, the slot groups' colours and the mutagens' own bonuses are applied by the game's ability manager as they
// are for the menu. EquipSkill refuses a skill no longer learned and a locked slot; EquipItemInGivenSlot refuses a locked
// mutagen slot and splits one mutagen off a stack.
// Stored as saved facts (the game keeps facts with the save, as it does sls_active):
//   sls_sk_<set>_<slotID> = the skill (ESkill as int) in that slot, sls_skn_<set> = how many skills the set holds;
//   sls_mutg_<set> = the set's record number g, sls_muts_<set>_<g>_<k> = 1 when mutagen slot k was filled,
//   sls_mut_<set>_<g>_<k>_<item name> = 1 naming the mutagen (an item name can only be kept in a fact's id: facts hold
//   numbers, and WitcherScript has no text-to-name). A new record takes a new number g, so an older record is never read.
//   <set> is L1..L10 for a loadout, A for the always-worn set.
// Mutagens stay in Geralt's inventory; the right ones are only put in the slots. A mutagen is found again by its name
// among his unequipped mutagens (MutagenIngredient), so a stack or two identical mutagens both work.
// The rules: leaving a loadout records its skills and mutagens; leaving the Always worn box records the always-worn set.
// Entering a loadout takes every skill and mutagen out and puts its own set in - or, when it holds no skill set (none
// recorded, or none in it), the always-worn skill set; mutagens are decided the same way, separately. Switching to no
// loadout puts the always-worn sets in. Entering the Always worn box puts the always-worn sets in when they exist, and
// otherwise leaves skills and mutagens as they are, so the first always-worn set starts from what is equipped.
// The colour-match multiplier of a mutagen (the mutagen_color_*_x abilities) is not set by the equip functions: the
// character screen adds it while it draws its slot groups (characterMenuDupe.ws UpdateGroupsData: RemoveMutagenBonus,
// then GetGroupBonusDescription for groups 1-4), a private menu method SLS cannot reach. SLS_ApplyColourBonus does the
// same calculation from the same game data after every switch that changes skills or mutagens: it removes the same
// ability names the same way, then per group takes the mutagen in GetMutagenSlotIDFromGroupID's slot, counts
// 1 + GetGroupBonusCount(GetSkillMutagenColor(mutagen), group) and adds count - 1 of the _x ability that belongs to the
// mutagen's GetMutagenBonusAbilityName (none for a rare mutagen, as the screen). Yellow Mutagens' additions are
// mirrored: its wrap of GetSkillMutagenColor applies to the call itself, and the three yellow _x abilities its wrap of
// GetGroupBonusDescription adds are added the same way. So opening the screen afterwards removes and adds back exactly
// the same abilities. The abilities are saved with the game (they are in the saves' name tables), so a load needs nothing.

// Set index: 0..9 a loadout, -2 the always-worn set.
function SLS_SetTag(which : int) : string
{
	if (which == -2)
	{
		return "A";
	}
	return "L" + IntToString(which + 1);
}

function SLS_SetFact(id : string, value : int)
{
	FactsRemove(id);
	if (value != 0)
	{
		FactsAdd(id, value, -1);
	}
}

function SLS_MutagenSlots() : array<EEquipmentSlots>
{
	var slots : array<EEquipmentSlots>;

	slots.PushBack(EES_SkillMutagen1);
	slots.PushBack(EES_SkillMutagen2);
	slots.PushBack(EES_SkillMutagen3);
	slots.PushBack(EES_SkillMutagen4);
	return slots;
}

function SLS_SkillCount(which : int) : int
{
	return FactsQuerySum("sls_skn_" + SLS_SetTag(which));
}

function SLS_MutagenCount(which : int) : int
{
	return FactsQuerySum("sls_mutn_" + SLS_SetTag(which));
}

function SLS_MutKey(tag : string, g : int, k : int, itemName : name) : string
{
	return "sls_mut_" + tag + "_" + IntToString(g) + "_" + IntToString(k) + "_" + NameToString(itemName);
}

// Records the skills in Geralt's unlocked skill slots as a set's skills.
function SLS_RecordSkills(player : W3PlayerWitcher, which : int) : int
{
	var slots : array<SSkillSlot>;
	var tag, text : string;
	var i, n : int;

	tag = SLS_SetTag(which);
	slots = player.GetSkillSlots();
	n = 0;
	text = "";
	for (i = 0; i < slots.Size(); i += 1)
	{
		if (slots[i].unlocked && slots[i].socketedSkill != S_SUndefined)
		{
			SLS_SetFact("sls_sk_" + tag + "_" + IntToString(slots[i].id), (int)slots[i].socketedSkill);
			if (n > 0)
			{
				text += ", ";
			}
			text += NameToString(SkillEnumToName(slots[i].socketedSkill));
			n += 1;
		}
		else
		{
			SLS_SetFact("sls_sk_" + tag + "_" + IntToString(slots[i].id), 0);
		}
	}
	SLS_SetFact("sls_skn_" + tag, n);
	SLS_Log("skills recorded for " + SLS_Describe(which) + ": " + IntToString(n) + " [" + text + "]");
	return n;
}

// Records the mutagens in Geralt's four mutagen slots as a set's mutagens, under a new record number.
function SLS_RecordMutagens(player : W3PlayerWitcher, inv : CInventoryComponent, which : int) : int
{
	var slots : array<EEquipmentSlots>;
	var all : array<SItemUniqueId>;
	var item : SItemUniqueId;
	var tag, text : string;
	var i, k, g, oldG, n : int;

	tag = SLS_SetTag(which);
	oldG = FactsQuerySum("sls_mutg_" + tag);
	g = oldG + 1;
	// the previous record's facts are removed for every mutagen Geralt holds (one he no longer holds keeps a fact under
	// the old number, which is never read again)
	if (oldG > 0)
	{
		inv.GetAllItems(all);
		for (i = 0; i < all.Size(); i += 1)
		{
			if (inv.ItemHasTag(all[i], 'MutagenIngredient'))
			{
				for (k = 1; k <= 4; k += 1)
				{
					FactsRemove(SLS_MutKey(tag, oldG, k, inv.GetItemName(all[i])));
				}
			}
		}
		for (k = 1; k <= 4; k += 1)
		{
			FactsRemove("sls_muts_" + tag + "_" + IntToString(oldG) + "_" + IntToString(k));
		}
	}
	SLS_SetFact("sls_mutg_" + tag, g);
	slots = SLS_MutagenSlots();
	n = 0;
	text = "";
	for (k = 1; k <= 4; k += 1)
	{
		if (player.GetItemEquippedOnSlot(slots[k - 1], item) && inv.IsIdValid(item))
		{
			FactsAdd(SLS_MutKey(tag, g, k, inv.GetItemName(item)), 1, -1);
			FactsAdd("sls_muts_" + tag + "_" + IntToString(g) + "_" + IntToString(k), 1, -1);
			if (n > 0)
			{
				text += ", ";
			}
			text += IntToString(k) + ":" + NameToString(inv.GetItemName(item));
			n += 1;
		}
	}
	SLS_SetFact("sls_mutn_" + tag, n);
	SLS_Log("mutagens recorded for " + SLS_Describe(which) + ": " + IntToString(n) + " [" + text + "]");
	return n;
}

// Which set's skills (or mutagens) a switch puts in: the target loadout's own set, or the always-worn set when the target
// holds none or is no loadout. -3 = leave skills (mutagens) as they are (entering the Always worn box with no always-worn
// set yet).
function SLS_SkillSource(to : int, skills : bool) : int
{
	var own, always : int;

	if (skills)
	{
		always = SLS_SkillCount(-2);
	}
	else
	{
		always = SLS_MutagenCount(-2);
	}
	if (to >= 0)
	{
		if (skills)
		{
			own = SLS_SkillCount(to);
		}
		else
		{
			own = SLS_MutagenCount(to);
		}
		if (own > 0)
		{
			return to;
		}
		return -2;
	}
	if (to == -2 && always <= 0)
	{
		return -3;
	}
	return -2;
}

// Takes every skill out of Geralt's slots and puts a set's skills in (only skills he still knows, only slots still
// unlocked; each skip is logged).
function SLS_ApplySkills(player : W3PlayerWitcher, src : int) : int
{
	var slots : array<SSkillSlot>;
	var skill : ESkill;
	var tag : string;
	var i, v, n : int;

	slots = player.GetSkillSlots();
	for (i = 0; i < slots.Size(); i += 1)
	{
		if (slots[i].socketedSkill != S_SUndefined)
		{
			player.UnequipSkill(slots[i].id);
		}
	}
	if (SLS_SkillCount(src) <= 0)
	{
		SLS_Log("skills: " + SLS_Describe(src) + " holds no skill set - no skills equipped");
		return 0;
	}
	tag = SLS_SetTag(src);
	slots = player.GetSkillSlots();
	n = 0;
	for (i = 0; i < slots.Size(); i += 1)
	{
		v = FactsQuerySum("sls_sk_" + tag + "_" + IntToString(slots[i].id));
		if (v <= 0)
		{
			continue;
		}
		skill = (ESkill)v;
		if (!player.HasLearnedSkill(skill))
		{
			SLS_Log("skill skipped, no longer learned: " + NameToString(SkillEnumToName(skill)) + " (slot " + IntToString(slots[i].id) + ")");
			continue;
		}
		if (player.GetSkillSlotIndex(slots[i].id, true) < 0)
		{
			SLS_Log("skill skipped, slot " + IntToString(slots[i].id) + " is locked: " + NameToString(SkillEnumToName(skill)));
			continue;
		}
		if (player.EquipSkill(skill, slots[i].id))
		{
			n += 1;
		}
		else
		{
			SLS_Log("skill not equipped (the game refused): " + NameToString(SkillEnumToName(skill)) + " (slot " + IntToString(slots[i].id) + ")");
		}
	}
	SLS_Log("skills: " + IntToString(n) + " equipped from " + SLS_Describe(src));
	return n;
}

// An unequipped mutagen in Geralt's inventory that a set names for mutagen slot k (record g); searched again for every
// slot, because equipping one from a stack splits the stack into a new item.
function SLS_FindMutagen(player : W3PlayerWitcher, inv : CInventoryComponent, tag : string, g : int, k : int) : SItemUniqueId
{
	var all : array<SItemUniqueId>;
	var i : int;

	inv.GetAllItems(all);
	for (i = 0; i < all.Size(); i += 1)
	{
		if (inv.ItemHasTag(all[i], 'MutagenIngredient') && !player.IsItemEquipped(all[i])
			&& FactsQuerySum(SLS_MutKey(tag, g, k, inv.GetItemName(all[i]))) > 0)
		{
			return all[i];
		}
	}
	return GetInvalidUniqueId();
}

// Takes every mutagen out of Geralt's four mutagen slots (they stay in his inventory) and puts a set's mutagens in (only
// mutagens still in the inventory, only slots still unlocked; each skip is logged).
function SLS_ApplyMutagens(player : W3PlayerWitcher, inv : CInventoryComponent, src : int) : int
{
	var slots : array<EEquipmentSlots>;
	var item, worn : SItemUniqueId;
	var pam : W3PlayerAbilityManager;
	var tag : string;
	var k, g, n : int;

	slots = SLS_MutagenSlots();
	for (k = 0; k < slots.Size(); k += 1)
	{
		if (player.GetItemEquippedOnSlot(slots[k], item))
		{
			player.UnequipItemFromSlot(slots[k]);
		}
	}
	if (SLS_MutagenCount(src) <= 0)
	{
		SLS_Log("mutagens: " + SLS_Describe(src) + " holds no mutagens - none equipped");
		return 0;
	}
	tag = SLS_SetTag(src);
	g = FactsQuerySum("sls_mutg_" + tag);
	pam = (W3PlayerAbilityManager)player.abilityManager;
	n = 0;
	for (k = 1; k <= 4; k += 1)
	{
		if (FactsQuerySum("sls_muts_" + tag + "_" + IntToString(g) + "_" + IntToString(k)) <= 0)
		{
			continue;
		}
		if (pam && !pam.IsSkillMutagenSlotUnlocked(slots[k - 1]))
		{
			SLS_Log("mutagen skipped, mutagen slot " + IntToString(k) + " is locked");
			continue;
		}
		item = SLS_FindMutagen(player, inv, tag, g, k);
		if (!inv.IsIdValid(item))
		{
			SLS_Log("mutagen skipped, the one recorded for slot " + IntToString(k) + " is not in the inventory any more");
			continue;
		}
		player.EquipItemInGivenSlot(item, slots[k - 1], false);
		if (player.GetItemEquippedOnSlot(slots[k - 1], worn) && inv.IsIdValid(worn))
		{
			n += 1;
		}
		else
		{
			SLS_Log("mutagen not equipped (the game refused): " + NameToString(inv.GetItemName(item)) + " (slot " + IntToString(k) + ")");
		}
	}
	SLS_Log("mutagens: " + IntToString(n) + " equipped from " + SLS_Describe(src));
	return n;
}

// The screen's own mapping (characterMenuDupe.ws GetGroupBonusDescription): a mutagen's bonus ability -> the colour-match
// _x ability added once per matching skill. '' when the name is none of them.
function SLS_ColourAbility(bonus : name) : name
{
	switch (bonus)
	{
		case 'mutagen_color_red_synergy_bonus': return 'mutagen_color_red_x';
		case 'mutagen_color_green_synergy_bonus': return 'mutagen_color_green_x';
		case 'mutagen_color_blue_synergy_bonus': return 'mutagen_color_blue_x';
		case 'mutagen_color_lesser_red_synergy_bonus': return 'lesser_mutagen_color_red_x';
		case 'mutagen_color_lesser_green_synergy_bonus': return 'lesser_mutagen_color_green_x';
		case 'mutagen_color_lesser_blue_synergy_bonus': return 'lesser_mutagen_color_blue_x';
		case 'greater_mutagen_color_red_synergy_bonus': return 'greater_mutagen_color_red_x';
		case 'greater_mutagen_color_green_synergy_bonus': return 'greater_mutagen_color_green_x';
		case 'greater_mutagen_color_blue_synergy_bonus': return 'greater_mutagen_color_blue_x';
		case 'greater_mutagen_color_white_synergy_bonus': return 'greater_mutagen_color_white_x';
	}
	return '';
}

// Yellow Mutagens' wrap of GetGroupBonusDescription adds these after the screen's own (for any mutagen, rare or not).
function SLS_YellowColourAbility(bonus : name) : name
{
	switch (bonus)
	{
		case 'greater_mutagen_color_yellow_synergy_bonus': return 'greater_mutagen_color_yellow_x';
		case 'mutagen_color_yellow_synergy_bonus': return 'mutagen_color_yellow_x';
		case 'mutagen_color_lesser_yellow_synergy_bonus': return 'lesser_mutagen_color_yellow_x';
	}
	return '';
}

// Sets the mutagen colour-match multiplier for the layout now equipped, exactly as the character screen does when it is
// opened (see "skills and mutagens" above): the screen's RemoveMutagenBonus (plus Yellow Mutagens' yellow names), then
// per slot group 1-4 the _x ability count - 1 times. Logs what each group got, so a test can compare it with the
// screen's own result.
function SLS_ApplyColourBonus(player : W3PlayerWitcher, inv : CInventoryComponent)
{
	var pam : W3PlayerAbilityManager;
	var mutagen : SItemUniqueId;
	var bonus, ability, yellow : name;
	var i, groupId, count : int;
	var text : string;

	for (i = 0; i < 20; i += 1)
	{
		player.RemoveAbility('greater_mutagen_color_blue_green_blue_x');
		player.RemoveAbility('greater_mutagen_color_blue_green_green_x');
		player.RemoveAbility('greater_mutagen_color_blue_white_blue_x');
		player.RemoveAbility('greater_mutagen_color_blue_white_white_x');
		player.RemoveAbility('greater_mutagen_color_blue_x');
		player.RemoveAbility('greater_mutagen_color_green_white_green_x');
		player.RemoveAbility('greater_mutagen_color_green_white_white_x');
		player.RemoveAbility('greater_mutagen_color_green_x');
		player.RemoveAbility('greater_mutagen_color_red_blue_blue_x');
		player.RemoveAbility('greater_mutagen_color_red_blue_red_x');
		player.RemoveAbility('greater_mutagen_color_red_green_green_x');
		player.RemoveAbility('greater_mutagen_color_red_green_red_x');
		player.RemoveAbility('greater_mutagen_color_red_white_red_x');
		player.RemoveAbility('greater_mutagen_color_red_white_white_x');
		player.RemoveAbility('greater_mutagen_color_red_x');
		player.RemoveAbility('greater_mutagen_color_white_x');
		player.RemoveAbility('lesser_mutagen_color_blue_x');
		player.RemoveAbility('lesser_mutagen_color_green_x');
		player.RemoveAbility('lesser_mutagen_color_red_x');
		player.RemoveAbility('mutagen_color_blue_x');
		player.RemoveAbility('mutagen_color_green_x');
		player.RemoveAbility('mutagen_color_red_x');
		player.RemoveAbility('greater_mutagen_color_yellow_x');
		player.RemoveAbility('mutagen_color_yellow_x');
		player.RemoveAbility('lesser_mutagen_color_yellow_x');
	}
	pam = (W3PlayerAbilityManager)player.abilityManager;
	if (!pam)
	{
		SLS_Log("colour bonus: no ability manager - the multiplier was removed and not set again");
		return;
	}
	text = "";
	for (groupId = 1; groupId <= 4; groupId += 1)
	{
		if (!player.GetItemEquippedOnSlot(player.GetMutagenSlotIDFromGroupID(groupId), mutagen))
		{
			text += " g" + IntToString(groupId) + "=none";
			continue;
		}
		count = 1 + player.GetGroupBonusCount(inv.GetSkillMutagenColor(mutagen), groupId);
		bonus = pam.GetMutagenBonusAbilityName(mutagen);
		text += " g" + IntToString(groupId) + "=" + NameToString(inv.GetItemName(mutagen));
		if (!pam.IsMutagenRare(mutagen))
		{
			ability = SLS_ColourAbility(bonus);
			if (ability != '')
			{
				player.AddAbilityMultiple(ability, count - 1);
				text += " " + NameToString(ability) + " x" + IntToString(count - 1);
			}
		}
		else
		{
			text += " (rare: no multiplier, as the screen)";
		}
		yellow = SLS_YellowColourAbility(bonus);
		if (yellow != '')
		{
			player.AddAbilityMultiple(yellow, count - 1);
			text += " " + NameToString(yellow) + " x" + IntToString(count - 1);
		}
	}
	SLS_Log("colour bonus set as the character screen sets it:" + text);
}

// The skills-and-mutagens half of a switch: record what the loadout (or Always worn box) being left has, then put in
// what the target gets.
function SLS_SwitchSkills(player : W3PlayerWitcher, inv : CInventoryComponent, from : int, to : int)
{
	var src : int;
	var changed : bool;

	if (from >= 0 || from == -2)
	{
		SLS_RecordSkills(player, from);
		SLS_RecordMutagens(player, inv, from);
	}
	changed = false;
	src = SLS_SkillSource(to, true);
	if (src == -3)
	{
		SLS_Log("skills stay as they are: no always-worn skill set yet (it is recorded when you leave Always worn)");
	}
	else
	{
		if (to >= 0 && src == -2)
		{
			SLS_Log("skills: " + SLS_Describe(to) + " holds no skill set - the always-worn skill set is used");
		}
		SLS_ApplySkills(player, src);
		changed = true;
	}
	src = SLS_SkillSource(to, false);
	if (src == -3)
	{
		SLS_Log("mutagens stay as they are: no always-worn mutagens yet (they are recorded when you leave Always worn)");
	}
	else
	{
		if (to >= 0 && src == -2)
		{
			SLS_Log("mutagens: " + SLS_Describe(to) + " holds no mutagens - the always-worn mutagens are used");
		}
		SLS_ApplyMutagens(player, inv, src);
		changed = true;
	}
	if (changed)
	{
		SLS_ApplyColourBonus(player, inv);
	}
}

// One line per set for SLS_DebugState: "skills=3 mutagens=2".
function SLS_SkillSummary(which : int) : string
{
	return "skills=" + IntToString(SLS_SkillCount(which)) + " mutagens=" + IntToString(SLS_MutagenCount(which));
}

// ---- the switch --------------------------------------------------------------------------------------------------

// Whatever is worn now becomes the always-worn set (leaving the "Always worn" box): Geralt's gear and, since 1.0.3, the
// horse gear and trophy (SLS_Always = 1 on the piece the horse wears, which is in the stash).
function SLS_CaptureAlways(player : W3PlayerWitcher, hm : W3HorseManager, inv : CInventoryComponent, stash : CInventoryComponent) : int
{
	var slots : array<EEquipmentSlots>;
	var old : array<SItemUniqueId>;
	var item : SItemUniqueId;
	var i, count : int;

	old = SLS_AlwaysItems(inv);
	for (i = 0; i < old.Size(); i += 1)
	{
		inv.SetItemModifierInt(old[i], 'SLS_Always', 0);
	}
	old = SLS_AlwaysItems(stash);
	for (i = 0; i < old.Size(); i += 1)
	{
		stash.SetItemModifierInt(old[i], 'SLS_Always', 0);
	}
	slots = SLS_GearSlots();
	count = 0;
	for (i = 0; i < slots.Size(); i += 1)
	{
		if (player.GetItemEquippedOnSlot(slots[i], item) && !SLS_MustStay(inv, item))
		{
			inv.SetItemModifierInt(item, 'SLS_Always', 1);
			count += 1;
			SLS_Log("always worn: " + NameToString(inv.GetItemName(item)));
		}
	}
	slots = SLS_HorseSlots();
	for (i = 0; i < slots.Size(); i += 1)
	{
		item = hm.GetItemInSlot(slots[i]);
		if (stash.IsIdValid(item) && !SLS_MustStay(stash, item))
		{
			stash.SetItemModifierInt(item, 'SLS_Always', 1);
			count += 1;
			SLS_Log("always worn (horse gear): " + NameToString(stash.GetItemName(item)));
		}
	}
	return count;
}

// Takes off every worn piece of gear; with a loadout to leave, its pieces go to the loadout's storage. Always-worn
// pieces stay on. Returns how many quest/kept pieces stayed in the inventory.
// Each piece taken off also leaves the menu's paperdoll slot (PaperdollRemoveItem, as the menu's own unequip does,
// inventoryMenu.ws UnequipItem) while its id is still the inventory's: 1.0.0 skipped it and the owner saw "whatever was
// last equipped" stay on show after a switch to an empty loadout.
function SLS_StoreWorn(menu : CR4InventoryMenu, player : W3PlayerWitcher, inv : CInventoryComponent, stash : CInventoryComponent, from : int, out stored : int) : int
{
	var slots : array<EEquipmentSlots>;
	var item, moved : SItemUniqueId;
	var i, kept, quantity : int;

	slots = SLS_GearSlots();
	kept = 0;
	stored = 0;
	for (i = 0; i < slots.Size(); i += 1)
	{
		if (!player.GetItemEquippedOnSlot(slots[i], item))
		{
			continue;
		}
		if (inv.GetItemModifierInt(item, 'SLS_Always', 0) > 0)
		{
			SLS_Log("stays on (always worn): " + NameToString(inv.GetItemName(item)));
			continue;
		}
		if (slots[i] == EES_Bolt && SLS_MustStay(inv, item))
		{
			// the infinite bolts: the game hands them back whenever no other bolts are on
			continue;
		}
		quantity = inv.GetItemQuantity(item);
		player.UnequipItem(item);
		menu.PaperdollRemoveItem(item);
		if (from < 0)
		{
			SLS_Log("taken off, stays in the inventory: " + NameToString(inv.GetItemName(item)));
			continue;
		}
		if (SLS_MustStay(inv, item))
		{
			kept += 1;
			SLS_Log("taken off, cannot be stored: " + NameToString(inv.GetItemName(item)));
			continue;
		}
		moved = inv.GiveItemTo(stash, item, quantity, false, false, false);
		if (moved == GetInvalidUniqueId())
		{
			kept += 1;
			SLS_Log("could not store " + NameToString(inv.GetItemName(item)) + " - it stays in the inventory");
			continue;
		}
		// the loadout's number on the stash piece (saved with the game) and the game's tag that keeps it out of the
		// stash's list (not saved - SLS_SyncStashTags puts it back after a load)
		stash.SetItemModifierInt(moved, 'SLS_Loadout', from + 1);
		stash.AddItemTag(moved, 'NoShowInContainer');
		stored += 1;
		SLS_Log("stored in " + SLS_Describe(from) + ": " + NameToString(stash.GetItemName(moved)) + " x" + IntToString(quantity));
	}
	return kept;
}

// Brings a loadout's pieces back from its storage and puts each on in its own slot; a horse piece goes back on the horse
// (SLS_EquipHorse) instead of on Geralt.
function SLS_Restore(menu : CR4InventoryMenu, player : W3PlayerWitcher, hm : W3HorseManager, inv : CInventoryComponent, stash : CInventoryComponent, to : int) : int
{
	var items : array<SItemUniqueId>;
	var back : SItemUniqueId;
	var i, quantity, restored : int;
	var horsePiece : bool;
	var pieceName : name;

	items = SLS_StoredIn(stash, to);
	restored = 0;
	for (i = 0; i < items.Size(); i += 1)
	{
		horsePiece = SLS_IsHorseItem(stash, items[i]);
		if (horsePiece && hm.IsItemEquipped(items[i]))
		{
			// cannot happen through SLS (a worn horse piece never keeps a loadout number); never give away what the horse wears
			stash.SetItemModifierInt(items[i], 'SLS_Loadout', 0);
			SLS_Log("the horse wears " + NameToString(stash.GetItemName(items[i])) + " - its loadout number was cleared, it stays on");
			continue;
		}
		quantity = stash.GetItemQuantity(items[i]);
		stash.SetItemModifierInt(items[i], 'SLS_Loadout', 0);
		stash.RemoveItemTag(items[i], 'NoShowInContainer');
		back = stash.GiveItemTo(inv, items[i], quantity, false, false, false);
		if (back == GetInvalidUniqueId())
		{
			// keep it in the loadout so it is not lost to the stash's list
			stash.SetItemModifierInt(items[i], 'SLS_Loadout', to + 1);
			stash.AddItemTag(items[i], 'NoShowInContainer');
			SLS_Log("could not take back " + NameToString(stash.GetItemName(items[i])) + " from " + SLS_Describe(to));
			continue;
		}
		// in case the move carried the modifier over: Geralt's own copy belongs to no stored loadout
		inv.SetItemModifierInt(back, 'SLS_Loadout', 0);
		if (horsePiece)
		{
			// the loadout's own piece wins its slot: an always-worn piece there is taken off and waits in the inventory
			// (SLS_ReapplyAlways puts it back when the slot is free again)
			SLS_HorseAlwaysWaits(menu, hm, inv, stash, inv.GetHorseSlotForItem(back));
			// the name first: once on the horse the piece is no longer in Geralt's inventory
			pieceName = inv.GetItemName(back);
			if (stash.IsIdValid(SLS_EquipHorse(menu, hm, inv, stash, back)))
			{
				SLS_Log("restored from " + SLS_Describe(to) + " onto the horse: " + NameToString(pieceName));
			}
			restored += 1;
			continue;
		}
		if (!player.EquipItem(back))
		{
			SLS_Log("back in the inventory but not put on: " + NameToString(inv.GetItemName(back)));
		}
		restored += 1;
		SLS_Log("restored from " + SLS_Describe(to) + ": " + NameToString(inv.GetItemName(back)) + " x" + IntToString(quantity));
	}
	return restored;
}

// Takes an always-worn horse piece off the horse's slot so a loadout's own piece can have it; the piece waits in Geralt's
// inventory, still always-worn (the mark is set again on the inventory copy in case the move did not carry it).
function SLS_HorseAlwaysWaits(menu : CR4InventoryMenu, hm : W3HorseManager, inv : CInventoryComponent, stash : CInventoryComponent, slot : EEquipmentSlots)
{
	var worn, back : SItemUniqueId;
	var itemName : name;

	if (slot == EES_InvalidSlot)
	{
		return;
	}
	worn = hm.GetItemInSlot(slot);
	if (!stash.IsIdValid(worn) || stash.GetItemModifierInt(worn, 'SLS_Always', 0) <= 0)
	{
		return;
	}
	itemName = stash.GetItemName(worn);
	menu.PaperdollRemoveItem(worn);
	back = hm.UnequipItem(slot);
	if (inv.IsIdValid(back))
	{
		inv.SetItemModifierInt(back, 'SLS_Always', 1);
		inv.SetItemModifierInt(back, 'SLS_Loadout', 0);
	}
	SLS_Log("always worn waits (slot taken, horse gear): " + NameToString(itemName));
}

// Puts always-worn pieces back on where their slot is free (a loadout's own piece wins its slot) - Geralt's on Geralt,
// horse pieces on the horse (SLS_EquipHorse).
function SLS_ReapplyAlways(menu : CR4InventoryMenu, player : W3PlayerWitcher, hm : W3HorseManager, inv : CInventoryComponent, stash : CInventoryComponent)
{
	var items : array<SItemUniqueId>;
	var other, onHorse : SItemUniqueId;
	var slot : EEquipmentSlots;
	var i : int;
	var itemName : name;

	items = SLS_AlwaysItems(inv);
	for (i = 0; i < items.Size(); i += 1)
	{
		if (SLS_IsHorseItem(inv, items[i]))
		{
			slot = inv.GetHorseSlotForItem(items[i]);
			itemName = inv.GetItemName(items[i]);
			if (stash.IsIdValid(hm.GetItemInSlot(slot)))
			{
				SLS_Log("always worn waits (slot taken, horse gear): " + NameToString(itemName));
				continue;
			}
			onHorse = SLS_EquipHorse(menu, hm, inv, stash, items[i]);
			if (stash.IsIdValid(onHorse))
			{
				stash.SetItemModifierInt(onHorse, 'SLS_Always', 1);
				SLS_Log("always worn back on (horse gear): " + NameToString(itemName));
			}
			continue;
		}
		if (player.IsItemEquipped(items[i]))
		{
			continue;
		}
		slot = inv.GetSlotForItemId(items[i]);
		if (slot == EES_InvalidSlot || player.GetItemEquippedOnSlot(slot, other))
		{
			SLS_Log("always worn waits (slot taken): " + NameToString(inv.GetItemName(items[i])));
			continue;
		}
		player.EquipItemInGivenSlot(items[i], slot, false);
		SLS_Log("always worn back on: " + NameToString(inv.GetItemName(items[i])));
	}
}

// ---- the inventory menu ------------------------------------------------------------------------------------------

// The movie's messages ride on OnBreakPoint, which the game only logs. Ours never reach the base method; every other
// text does. (An event wrapper: no early return - logic library, AMF Witcher 3.)
@wrapMethod(CR4MenuBase)
function OnBreakPoint(text : string)
{
	var menu : CR4InventoryMenu;

	if (StrBeginsWith(text, "SLS|"))
	{
		menu = (CR4InventoryMenu)this;
		if (menu)
		{
			menu.SLS_OnMovie(text);
		}
		else
		{
			SLS_Log("message from a menu that is not the inventory, ignored: " + text);
		}
	}
	else
	{
		wrappedMethod(text);
	}
}

// True while the loadout column has the pad's focus (the movie says so: "SLS|focus|1" / "SLS|focus|0").
@addField(CR4InventoryMenu)
var slsColumnFocused : bool;

@addMethod(CR4InventoryMenu)
function SLS_OnMovie(text : string)
{
	var box : int;

	if (text == "SLS|ready")
	{
		// the Loadouts slider's default is written here at most once per inventory menu (never from the poll below)
		if (!slsDefaultChecked)
		{
			slsDefaultChecked = true;
			SLS_WriteDefaultCount();
		}
		SLS_PushBoxes();
		return;
	}
	// the column asks twice a second while it is on screen: a Loadouts change made meanwhile (Apocrypha Menu Framework's
	// page can be open over the inventory) rebuilds it at once. Nothing is logged unless the count changed.
	if (text == "SLS|poll")
	{
		if (SLS_Count() != slsShownCount)
		{
			SLS_Log("loadouts setting changed: " + IntToString(slsShownCount) + " -> " + IntToString(SLS_Count()));
			SLS_PushBoxes();
		}
		return;
	}
	if (text == "SLS|focus|1")
	{
		SLS_SetColumnFocus(true);
		return;
	}
	if (text == "SLS|focus|0")
	{
		SLS_SetColumnFocus(false);
		return;
	}
	if (StrBeginsWith(text, "SLS|activate|"))
	{
		box = StringToInt(StrAfterLast(text, "|"), -1);
		SLS_Press(box);
		return;
	}
	// how the column took or gave up the pad's focus, and which press did it (left stick / D-pad / right stick)
	if (StrBeginsWith(text, "SLS|nav|"))
	{
		SLS_Log("column navigation: " + StrAfterFirst(text, "SLS|nav|"));
		return;
	}
	// the column caught an error of its own and switched itself off for this menu; the inventory carries on without it
	if (StrBeginsWith(text, "SLS|error|"))
	{
		SLS_Log("ERROR in the loadout column - it is off until the inventory is opened again (the inventory itself works): " + StrAfterFirst(text, "SLS|error|"));
		return;
	}
	SLS_Log("unknown message from the column: " + text);
}

// THE GRID'S ACTIONS ARE OFF WHILE THE COLUMN HAS THE FOCUS (the owner's two retests, 2026-10-06: "whenever I press
// loadout one, it selected the armor next to it"; his screenshot showed the ARMOR grid still selecting the item beside the
// column, its tooltip open and the hint bar offering that item's actions). The hint bar is the common menu's - another
// movie - and its A reaches this menu as OnInputHandled, which hands it to the current context (the grid's item context),
// whose primary action equips the selected item: no listener in our movie can stop that. So, the way the menu itself
// does it while the player-stats panel is up (OnPlayerStatsShown / OnPlayerStatsHidden): the context is deactivated while
// the column has the focus (its buttons leave the hint bar) and put back after, and OnInputHandled is not passed on.
@addMethod(CR4InventoryMenu)
function SLS_SetColumnFocus(focused : bool)
{
	if (slsColumnFocused == focused)
	{
		return;
	}
	slsColumnFocused = focused;
	if (focused)
	{
		SLS_Log("column focus: on (the grid's actions are off)");
	}
	else
	{
		SLS_Log("column focus: off (the grid's actions are back)");
	}
	if (!m_currentContext)
	{
		return;
	}
	if (focused)
	{
		m_currentContext.Deactivate();
	}
	else
	{
		ActivateContext(m_currentContext);
		m_currentContext.UpdateContext();
	}
}

// An event wrapper: no early return (logic library, AMF Witcher 3).
@wrapMethod(CR4InventoryMenu)
function OnInputHandled(NavCode : string, KeyCode : int, ActionId : int)
{
	if (slsColumnFocused)
	{
		SLS_Log("hint-bar input " + NavCode + " not passed to the grid's context: the loadout column has the focus");
	}
	else
	{
		wrappedMethod(NavCode, KeyCode, ActionId);
	}
}

// THE STATS PAGE (RT) - the owner, 2026-10-07: the loadout boxes stayed visible over the character stats page. The menu
// hears the page open and close (OnPlayerStatsShown / OnPlayerStatsHidden, where it also turns the grid's context off and
// on); the column is told through the "inventory.sls.statsUp" binding and steps aside, and gives up the pad's focus.
// Event wrappers: no early return (logic library, AMF Witcher 3).
@addField(CR4InventoryMenu)
var slsStatsUp : bool;

@wrapMethod(CR4InventoryMenu)
function OnPlayerStatsShown()
{
	var r : bool;

	r = wrappedMethod();
	slsStatsUp = true;
	SLS_SetColumnFocus(false);
	SLS_PushStats();
	SLS_Log("stats page up: the column steps aside");
	return r;
}

@wrapMethod(CR4InventoryMenu)
function OnPlayerStatsHidden()
{
	var r : bool;

	r = wrappedMethod();
	slsStatsUp = false;
	SLS_PushStats();
	SLS_Log("stats page closed: the column is back");
	return r;
}

@addMethod(CR4InventoryMenu)
function SLS_PushStats()
{
	if (SLS_Storage())
	{
		m_flashValueStorage.SetFlashBool("inventory.sls.statsUp", slsStatsUp);
	}
}

// The menu's value storage. CR4MenuBase sets m_flashValueStorage in its own OnConfigUI; the movie's "SLS|ready" can
// arrive before that (the log said "no flash value storage yet" on every inventory open, 2026-10-07), so it is fetched
// here when it is not set yet - the same call the base menu makes.
@addMethod(CR4InventoryMenu)
function SLS_Storage() : bool
{
	if (!m_flashValueStorage)
	{
		m_flashValueStorage = GetMenuFlashValueStorage();
	}
	if (m_flashValueStorage)
	{
		return true;
	}
	return false;
}

// How many loadout boxes the column was last given (the "SLS|poll" check).
@addField(CR4InventoryMenu)
var slsShownCount : int;

// True once this inventory menu has checked the Loadouts slider's default (SLS_WriteDefaultCount, from "SLS|ready").
@addField(CR4InventoryMenu)
var slsDefaultChecked : bool;

// The column's boxes: "Always worn" at the top (the owner, 2026-10-14: "I want the always on button to be at the top of
// the loadout list"), then the loadouts; the active one lit. Box 0 is "Always worn", box n is loadout n.
@addMethod(CR4InventoryMenu)
function SLS_PushBoxes()
{
	var boxes : CScriptedFlashArray;
	var box : CScriptedFlashObject;
	var active, count, i : int;

	if (!SLS_Storage())
	{
		SLS_Log("no flash value storage yet - the column stays empty until it asks again");
		return;
	}
	active = SLS_Active();
	count = SLS_Count();
	boxes = m_flashValueStorage.CreateTempFlashArray();
	box = m_flashValueStorage.CreateTempFlashObject();
	box.SetMemberFlashString("label", GetLocStringByKeyExt("sls_always_worn"));
	box.SetMemberFlashBool("lit", active == -2);
	boxes.PushBackFlashObject(box);
	for (i = 0; i < count; i += 1)
	{
		box = m_flashValueStorage.CreateTempFlashObject();
		box.SetMemberFlashString("label", GetLocStringByKeyExt("sls_loadout") + " " + IntToString(i + 1));
		box.SetMemberFlashBool("lit", active == i);
		boxes.PushBackFlashObject(box);
	}
	slsShownCount = count;
	m_flashValueStorage.SetFlashArray("inventory.sls.boxes", boxes);
	m_flashValueStorage.SetFlashBool("inventory.sls.statsUp", slsStatsUp);
}

// A box was activated with A (or clicked). The switch runs here and only here.
@addMethod(CR4InventoryMenu)
function SLS_Press(box : int)
{
	var player : W3PlayerWitcher;
	var hm : W3HorseManager;
	var inv, stash : CInventoryComponent;
	var from, to, count, kept, stored, restored, always, horseStored : int;

	count = SLS_Count();
	if (box < 0 || box > count)
	{
		SLS_Log("press on box " + IntToString(box) + " refused: out of range (" + IntToString(count) + " loadouts)");
		return;
	}
	if (GetCurrentInventoryState() != IMS_Player)
	{
		SLS_Log("press refused: the inventory is not the player's own view");
		return;
	}
	if (thePlayer.IsInCombat())
	{
		SLS_Log("press refused: in combat");
		showNotification(GetLocStringByKeyExt("menu_cannot_perform_action_combat"));
		return;
	}
	player = GetWitcherPlayer();
	if (!player)
	{
		SLS_Log("press refused: no player");
		return;
	}
	inv = player.GetInventory();
	hm = player.GetHorseManager();
	if (!hm)
	{
		SLS_Log("press refused: no stash (horse manager)");
		return;
	}
	stash = hm.GetInventoryComponent();
	if (!inv || !stash)
	{
		SLS_Log("press refused: an inventory is missing");
		return;
	}

	from = SLS_Active();
	// box 0 is "Always worn", box n is loadout n (index n - 1)
	if (box == 0)
	{
		to = -2;
	}
	else
	{
		to = box - 1;
	}
	if (to == from)
	{
		to = -1;
	}
	SLS_Log("switch " + SLS_Describe(from) + " -> " + SLS_Describe(to));

	if (from == -2)
	{
		always = SLS_CaptureAlways(player, hm, inv, stash);
		showNotification(GetLocStringByKeyExt("sls_always_set") + " " + IntToString(always));
	}
	stored = 0;
	kept = SLS_StoreWorn(this, player, inv, stash, from, stored);
	// Roach's gear and the trophy are locked to the loadout they were worn in: stored into the loadout left (any loadout,
	// also one stored before 1.0.3), or taken off into the inventory from none / Always worn - as Geralt's gear is
	horseStored = 0;
	kept += SLS_StoreHorse(this, hm, inv, stash, from, horseStored);
	stored += horseStored;
	if (from >= 0)
	{
		// the loadout left behind now holds its horse gear (none at all is a bare horse)
		SLS_SetHorseKept(from, true);
	}
	restored = 0;
	if (to >= 0)
	{
		restored = SLS_Restore(this, player, hm, inv, stash, to);
	}
	SLS_ReapplyAlways(this, player, hm, inv, stash);
	// skills and mutagens: the loadout (or Always worn box) left records its set, the target gets its own or the
	// always-worn one
	SLS_SwitchSkills(player, inv, from, to);
	SLS_SetActive(to);
	if (kept > 0)
	{
		showNotification(GetLocStringByKeyExt("sls_kept") + " " + IntToString(kept));
	}
	SLS_Log("switch done: stored " + IntToString(stored) + " (" + IntToString(horseStored) + " horse), restored " + IntToString(restored) + ", kept " + IntToString(kept));

	// The menu's own refresh after equipping or unequipping (inventoryMenu.ws OnEquipItem / UnequipItem): the paperdoll,
	// the grid, the weight, the stats - and the 3D Geralt beside them, a separate GUI scene entity that only takes the
	// player's items when told (UpdateGuiSceneEntityItems). 1.0.0 never told it: the owner saw no clothes on the model
	// while the inventory showed the gear equipped ("there might be a refresh issue").
	PaperdollUpdateAll();
	UpdateData();
	UpdateEncumbranceInfo();
	UpdatePlayerStatisticsData();
	UpdateGuiSceneEntityItems();
	SLS_PushBoxes();
}

// Before the menu is set up (and builds the stash list - OnConfigUI opens a stash as IMS_Stash), every stored piece gets
// its NoShowInContainer tag back from the saved modifier. After it, the column gets its state, in case its own request
// came first. On the first inventory open after a load it also logs what the stash holds for each loadout, so a test
// (or a player's log) shows at once whether the stored loadouts came through the load.
@wrapMethod(CR4InventoryMenu)
function OnConfigUI()
{
	var r : bool;
	var player : W3PlayerWitcher;
	var stash : CInventoryComponent;

	player = GetWitcherPlayer();
	if (player && player.GetHorseManager())
	{
		stash = player.GetHorseManager().GetInventoryComponent();
	}
	if (stash)
	{
		SLS_SyncStashTags(stash);
	}
	else
	{
		SLS_Log("stash hiding skipped: no player or no stash (horse manager) yet");
	}
	r = wrappedMethod();
	SLS_PushBoxes();
	if (player && stash && !player.slsStashLogged)
	{
		player.slsStashLogged = true;
		SLS_Log("first inventory open since the load: active " + SLS_Describe(SLS_Active()) + "; " + SLS_StashSummary(stash));
	}
	return r;
}

// Set on the first inventory open of a session; not a saved field, so it is false again after every load (the player
// entity is made anew from the save).
@addField(W3PlayerWitcher)
var slsStashLogged : bool;

// ---- the stash's list --------------------------------------------------------------------------------------------

// DIAGNOSTIC ONLY. The first "persistent loadouts" build hid stored pieces with this wrapper alone (return false when
// SLS_Loadout > 0), and in the owner's game (2026-10-14) the stored pieces stayed listed in the stash. The stash view is
// a W3GuiContainerInventoryComponent, whose own ShouldShowItem reaches this class only through
// super.ShouldShowItem(item); the likely reason is that a wrapper on the base class is not reached through super (not
// proven). The hiding is now the game's NoShowInContainer tag (SLS_SyncStashTags), which that same super call checks.
// This wrapper only logs, once per list component, whether it is reached for a stored piece - which settles the question
// - and changes nothing.
@addField(W3CommonContainerInventoryComponent)
var slsWrapLogged : bool;

@wrapMethod(W3CommonContainerInventoryComponent)
function ShouldShowItem(item : SItemUniqueId) : bool
{
	if (!slsWrapLogged && _inv && _inv.GetItemModifierInt(item, 'SLS_Loadout', 0) > 0)
	{
		slsWrapLogged = true;
		SLS_Log("diagnostic: the container ShouldShowItem wrapper IS reached for a stored piece (" + NameToString(_inv.GetItemName(item)) + ")");
	}
	return wrappedMethod(item);
}

// ---- observability -----------------------------------------------------------------------------------------------

// Read-only state for a test run (TestBench W3 calls it): the active loadout and what each loadout's storage holds.
// It never moves anything - the switch runs only from a box's A press (the owner's rule for every SLS).
function SLS_DebugState() : string
{
	var player : W3PlayerWitcher;
	var hm : W3HorseManager;
	var inv, stash : CInventoryComponent;
	var items : array<SItemUniqueId>;
	var slots : array<EEquipmentSlots>;
	var worn : SItemUniqueId;
	var text : string;
	var i, j : int;

	player = GetWitcherPlayer();
	if (!player || !player.GetHorseManager())
	{
		return "no player";
	}
	hm = player.GetHorseManager();
	inv = player.GetInventory();
	stash = hm.GetInventoryComponent();
	text = "active=" + SLS_Describe(SLS_Active()) + "; count=" + IntToString(SLS_Count());
	// a horse piece is marked (horse); "+horse" after a loadout = its storage holds its horse gear (sls_horse_<n>)
	for (i = 0; i < SLS_MaxLoadouts(); i += 1)
	{
		items = SLS_StoredIn(stash, i);
		text += "; L" + IntToString(i + 1);
		if (SLS_HorseKept(i))
		{
			text += "+horse";
		}
		text += "=[";
		for (j = 0; j < items.Size(); j += 1)
		{
			if (j > 0)
			{
				text += ", ";
			}
			text += NameToString(stash.GetItemName(items[j])) + " x" + IntToString(stash.GetItemQuantity(items[j]));
			if (SLS_IsHorseItem(stash, items[j]))
			{
				text += " (horse)";
			}
		}
		text += "]";
	}
	// how many skills / mutagens each set holds
	text += "; skill sets: A " + SLS_SkillSummary(-2);
	for (i = 0; i < SLS_MaxLoadouts(); i += 1)
	{
		if (SLS_SkillCount(i) > 0 || SLS_MutagenCount(i) > 0)
		{
			text += ", L" + IntToString(i + 1) + " " + SLS_SkillSummary(i);
		}
	}
	// what Roach wears now (the horse manager's slots) and Geralt's trophy
	slots = SLS_HorseSlots();
	text += "; horse=[";
	for (j = 0; j < slots.Size(); j += 1)
	{
		if (j > 0)
		{
			text += ", ";
		}
		worn = hm.GetItemInSlot(slots[j]);
		if (stash.IsIdValid(worn))
		{
			text += NameToString(stash.GetItemName(worn));
		}
		else
		{
			text += "-";
		}
	}
	text += "]";
	items = SLS_AlwaysItems(inv);
	text += "; always=[";
	for (j = 0; j < items.Size(); j += 1)
	{
		if (j > 0)
		{
			text += ", ";
		}
		text += NameToString(inv.GetItemName(items[j]));
		if (SLS_IsHorseItem(inv, items[j]))
		{
			text += " (horse, waiting)";
		}
	}
	items = SLS_AlwaysItems(stash);
	for (j = 0; j < items.Size(); j += 1)
	{
		text += ", " + NameToString(stash.GetItemName(items[j])) + " (horse)";
	}
	text += "]";
	return text;
}
