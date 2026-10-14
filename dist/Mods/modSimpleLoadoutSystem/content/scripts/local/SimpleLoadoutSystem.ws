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

// ---- settings ----------------------------------------------------------------------------------------------------

// Ten loadouts since 1.0.2 (the owner, 2026-10-14: "I want 10 loadout slots"); 1.0.0-1.0.1 had four.
function SLS_MaxLoadouts() : int
{
	return 10;
}

// Options > Mods > Simple Loadout System > Loadouts (and the same row on Apocrypha Menu Framework's page): a slider,
// 1 to 10, one loadout per nudge (SimpleLoadoutSystem.xml SLIDER;1;10;9). The value is the count itself. The column
// always starts with "Always worn". Default 10, the most there are: a value that is empty (never set) or not a count
// 1-10 is written as 10 and saved, so the slider shows what the column shows. A count chosen before 1.0.2 (1-4, from
// the old list) is kept as it is. Fewer loadouts only hides the higher boxes: their stored gear stays where it is.
function SLS_Count() : int
{
	var cfg : CInGameConfigWrapper;
	var raw : string;
	var count : int;

	cfg = theGame.GetInGameConfigWrapper();
	if (!cfg)
	{
		return SLS_MaxLoadouts();
	}
	raw = cfg.GetVarValue('SimpleLoadoutSystem', 'LoadoutCount');
	// a slider may store "7" or "7.000000"
	count = RoundF(StringToFloat(raw, -1.0));
	if (count < 1 || count > SLS_MaxLoadouts())
	{
		cfg.SetVarValue('SimpleLoadoutSystem', 'LoadoutCount', IntToString(SLS_MaxLoadouts()));
		theGame.SaveUserSettings();
		SLS_Log("loadouts setting was '" + raw + "' - set to the default " + IntToString(SLS_MaxLoadouts()));
		return SLS_MaxLoadouts();
	}
	return count;
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
		return "stash holds 0 stored pieces";
	}
	return "stash holds " + IntToString(total) + " stored piece(s): " + text;
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

// ---- the switch --------------------------------------------------------------------------------------------------

// Whatever is worn now becomes the always-worn set (leaving the "Always worn" box).
function SLS_CaptureAlways(player : W3PlayerWitcher, inv : CInventoryComponent) : int
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

// Brings a loadout's pieces back from its storage and puts each on in its own slot.
function SLS_Restore(player : W3PlayerWitcher, inv : CInventoryComponent, stash : CInventoryComponent, to : int) : int
{
	var items : array<SItemUniqueId>;
	var back : SItemUniqueId;
	var i, quantity, restored : int;

	items = SLS_StoredIn(stash, to);
	restored = 0;
	for (i = 0; i < items.Size(); i += 1)
	{
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

	items = SLS_AlwaysItems(inv);
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

// True while the loadout column has the pad's focus (the movie says so: "SLS|focus|1" / "SLS|focus|0").
@addField(CR4InventoryMenu)
var slsColumnFocused : bool;

@addMethod(CR4InventoryMenu)
function SLS_OnMovie(text : string)
{
	var box : int;

	if (text == "SLS|ready")
	{
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
		items = SLS_StoredIn(stash, i);
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
	items = SLS_AlwaysItems(inv);
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
