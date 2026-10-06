// Simple Loadout System (The Witcher 3: Wild Hunt - Remastered) - the loadout switch.
// Copyright (C) 2026 ApocryphaRealm. GPL-3.0-or-later (LICENSE, NOTICE.md).
//
// The loadout column is drawn by the inventory menu's own Flash (this mod's panel_inventory.redswf, built by
// tools/build_flash.py): four loadout boxes and "Always worn", between the item grid and the paperdoll. A box's A press
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
// - No switching in combat.
//
// Storage: the shared stash - the horse manager's inventory, the one every stash in the world opens (inventoryMenu.ws:
// IMS_Stash shows _horseInv). It follows Geralt to every region, is saved with the game and weighs nothing. A stored
// piece carries its loadout's tag (SLS_L1..SLS_L4) and the game's own NoShowInContainer tag, which keeps it out of the
// stash's list (guiContainerInventoryComponent.ws ShouldShowItem). The active loadout is a fact (sls_active), saved
// with the game.

// ---- settings ----------------------------------------------------------------------------------------------------

function SLS_MaxLoadouts() : int
{
	return 4;
}

// Options > Mods > Simple Loadout System > Loadouts (1-4, default 4). The column always ends with "Always worn".
// The list's entries carry the count itself (SimpleLoadoutSystem.xml); no value yet means the default, which is the
// list's first entry, so the menu and the column agree before anything was chosen.
function SLS_Count() : int
{
	var count : int;

	count = StringToInt(theGame.GetInGameConfigWrapper().GetVarValue('SimpleLoadoutSystem', 'LoadoutCount'), -1);
	if (count < 1 || count > SLS_MaxLoadouts())
	{
		return SLS_MaxLoadouts();
	}
	return count;
}

// ---- state -------------------------------------------------------------------------------------------------------

// -1 no loadout, -2 Always worn, 0..3 a loadout. Kept as value + 3 so a missing fact (0) reads as none.
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

function SLS_Tag(loadout : int) : name
{
	switch (loadout)
	{
		case 0: return 'SLS_L1';
		case 1: return 'SLS_L2';
		case 2: return 'SLS_L3';
		case 3: return 'SLS_L4';
	}
	return '';
}

function SLS_Log(text : string)
{
	LogChannel('SimpleLoadoutSystem', text);
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

// ---- the switch --------------------------------------------------------------------------------------------------

// Whatever is worn now becomes the always-worn set (leaving the "Always worn" box).
function SLS_CaptureAlways(player : W3PlayerWitcher, inv : CInventoryComponent) : int
{
	var slots : array<EEquipmentSlots>;
	var old : array<SItemUniqueId>;
	var item : SItemUniqueId;
	var i, count : int;

	old = inv.GetItemsByTag('SLS_Always');
	for (i = 0; i < old.Size(); i += 1)
	{
		inv.RemoveItemTag(old[i], 'SLS_Always');
	}
	slots = SLS_GearSlots();
	count = 0;
	for (i = 0; i < slots.Size(); i += 1)
	{
		if (player.GetItemEquippedOnSlot(slots[i], item) && !SLS_MustStay(inv, item))
		{
			inv.AddItemTag(item, 'SLS_Always');
			count += 1;
			SLS_Log("always worn: " + NameToString(inv.GetItemName(item)));
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
	var tag : name;
	var i, kept, quantity : int;

	slots = SLS_GearSlots();
	tag = SLS_Tag(from);
	kept = 0;
	stored = 0;
	for (i = 0; i < slots.Size(); i += 1)
	{
		if (!player.GetItemEquippedOnSlot(slots[i], item))
		{
			continue;
		}
		if (inv.ItemHasTag(item, 'SLS_Always'))
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
		stash.AddItemTag(moved, tag);
		stash.AddItemTag(moved, 'NoShowInContainer');
		stored += 1;
		SLS_Log("stored in " + SLS_Describe(from) + ": " + NameToString(stash.GetItemName(moved)) + " x" + IntToString(quantity));
	}
	return kept;
}

// Brings a loadout's pieces back from its storage and puts each on in its own slot.
function SLS_Restore(player : W3PlayerWitcher, inv : CInventoryComponent, stash : CInventoryComponent, to : int) : int
{
	var items : array<SItemUniqueId>;
	var back : SItemUniqueId;
	var tag : name;
	var i, quantity, restored : int;

	tag = SLS_Tag(to);
	items = stash.GetItemsByTag(tag);
	restored = 0;
	for (i = 0; i < items.Size(); i += 1)
	{
		quantity = stash.GetItemQuantity(items[i]);
		stash.RemoveItemTag(items[i], tag);
		stash.RemoveItemTag(items[i], 'NoShowInContainer');
		back = stash.GiveItemTo(inv, items[i], quantity, false, false, false);
		if (back == GetInvalidUniqueId())
		{
			// keep it tagged so it is not lost to the stash's list
			stash.AddItemTag(items[i], tag);
			stash.AddItemTag(items[i], 'NoShowInContainer');
			SLS_Log("could not take back " + NameToString(stash.GetItemName(items[i])) + " from " + SLS_Describe(to));
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

// Puts always-worn pieces back on where their slot is free (a loadout's own piece wins its slot).
function SLS_ReapplyAlways(player : W3PlayerWitcher, inv : CInventoryComponent)
{
	var items : array<SItemUniqueId>;
	var other : SItemUniqueId;
	var slot : EEquipmentSlots;
	var i : int;

	items = inv.GetItemsByTag('SLS_Always');
	for (i = 0; i < items.Size(); i += 1)
	{
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

@addMethod(CR4InventoryMenu)
function SLS_OnMovie(text : string)
{
	var box : int;

	if (text == "SLS|ready")
	{
		SLS_PushBoxes();
		return;
	}
	if (StrBeginsWith(text, "SLS|activate|"))
	{
		box = StringToInt(StrAfterLast(text, "|"), -1);
		SLS_Press(box);
		return;
	}
	SLS_Log("unknown message from the column: " + text);
}

// The column's boxes: the loadouts, then "Always worn"; the active one lit.
@addMethod(CR4InventoryMenu)
function SLS_PushBoxes()
{
	var boxes : CScriptedFlashArray;
	var box : CScriptedFlashObject;
	var active, count, i : int;

	if (!m_flashValueStorage)
	{
		SLS_Log("no flash value storage yet - the column stays empty until it asks again");
		return;
	}
	active = SLS_Active();
	count = SLS_Count();
	boxes = m_flashValueStorage.CreateTempFlashArray();
	for (i = 0; i < count; i += 1)
	{
		box = m_flashValueStorage.CreateTempFlashObject();
		box.SetMemberFlashString("label", GetLocStringByKeyExt("sls_loadout") + " " + IntToString(i + 1));
		box.SetMemberFlashBool("lit", active == i);
		boxes.PushBackFlashObject(box);
	}
	box = m_flashValueStorage.CreateTempFlashObject();
	box.SetMemberFlashString("label", GetLocStringByKeyExt("sls_always_worn"));
	box.SetMemberFlashBool("lit", active == -2);
	boxes.PushBackFlashObject(box);
	m_flashValueStorage.SetFlashArray("inventory.sls.boxes", boxes);
}

// A box was activated with A (or clicked). The switch runs here and only here.
@addMethod(CR4InventoryMenu)
function SLS_Press(box : int)
{
	var player : W3PlayerWitcher;
	var inv, stash : CInventoryComponent;
	var from, to, count, kept, stored, restored, always : int;

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
	if (!player.GetHorseManager())
	{
		SLS_Log("press refused: no stash (horse manager)");
		return;
	}
	stash = player.GetHorseManager().GetInventoryComponent();
	if (!inv || !stash)
	{
		SLS_Log("press refused: an inventory is missing");
		return;
	}

	from = SLS_Active();
	if (box == count)
	{
		to = -2;
	}
	else
	{
		to = box;
	}
	if (to == from)
	{
		to = -1;
	}
	SLS_Log("switch " + SLS_Describe(from) + " -> " + SLS_Describe(to));

	if (from == -2)
	{
		always = SLS_CaptureAlways(player, inv);
		showNotification(GetLocStringByKeyExt("sls_always_set") + " " + IntToString(always));
	}
	stored = 0;
	kept = SLS_StoreWorn(this, player, inv, stash, from, stored);
	restored = 0;
	if (to >= 0)
	{
		restored = SLS_Restore(player, inv, stash, to);
	}
	SLS_ReapplyAlways(player, inv);
	SLS_SetActive(to);
	if (kept > 0)
	{
		showNotification(GetLocStringByKeyExt("sls_kept") + " " + IntToString(kept));
	}
	SLS_Log("switch done: stored " + IntToString(stored) + ", restored " + IntToString(restored) + ", kept " + IntToString(kept));

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

// The column also gets its state when the menu itself is set up, in case its own request came first.
@wrapMethod(CR4InventoryMenu)
function OnConfigUI()
{
	wrappedMethod();
	SLS_PushBoxes();
}

// ---- observability -----------------------------------------------------------------------------------------------

// Read-only state for a test run (TestBench W3 calls it): the active loadout and what each loadout's storage holds.
// It never moves anything - the switch runs only from a box's A press (the owner's rule for every SLS).
function SLS_DebugState() : string
{
	var player : W3PlayerWitcher;
	var inv, stash : CInventoryComponent;
	var items : array<SItemUniqueId>;
	var text : string;
	var i, j : int;

	player = GetWitcherPlayer();
	if (!player || !player.GetHorseManager())
	{
		return "no player";
	}
	inv = player.GetInventory();
	stash = player.GetHorseManager().GetInventoryComponent();
	text = "active=" + SLS_Describe(SLS_Active()) + "; count=" + IntToString(SLS_Count());
	for (i = 0; i < SLS_MaxLoadouts(); i += 1)
	{
		items = stash.GetItemsByTag(SLS_Tag(i));
		text += "; L" + IntToString(i + 1) + "=[";
		for (j = 0; j < items.Size(); j += 1)
		{
			if (j > 0)
			{
				text += ", ";
			}
			text += NameToString(stash.GetItemName(items[j])) + " x" + IntToString(stash.GetItemQuantity(items[j]));
		}
		text += "]";
	}
	items = inv.GetItemsByTag('SLS_Always');
	text += "; always=[";
	for (j = 0; j < items.Size(); j += 1)
	{
		if (j > 0)
		{
			text += ", ";
		}
		text += NameToString(inv.GetItemName(items[j]));
	}
	text += "]";
	return text;
}
