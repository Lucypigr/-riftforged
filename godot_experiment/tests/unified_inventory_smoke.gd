extends SceneTree

const Armor = preload("res://scripts/armor_equipment.gd")
const Gem = preload("res://scripts/linked_gem_system.gd")
const Bag = preload("res://scripts/unified_bag.gd")

var finished := false

func _init() -> void:
    call_deferred("_watchdog")
    call_deferred("_run")

func _watchdog() -> void:
    await create_timer(15.0).timeout
    if not finished:
        _fail("Timeout")

func _fail(message: String) -> void:
    finished = true
    push_error("UNIFIED_INVENTORY_FAIL: " + message)
    quit(1)

func _run() -> void:
    var game := (load("res://main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    await process_frame
    await process_frame
    var hud := game.get_node("MobileUI") as RiftUnifiedInventoryHUD
    var armor_ui := game.get_node("ArmorEquipment") as RiftUnifiedEquipmentUI
    if hud == null or armor_ui == null:
        _fail("Unified HUD and equipped inventory were not mounted")
        return
    var state: Dictionary = game.call("debug_unified_state")
    var view: Dictionary = state.get("view", {})
    if int(view.get("columns", 0)) != 12 or int(view.get("rows", 0)) != 5 or int(view.get("overflow", -1)) != 0:
        _fail("Shared inventory must be one real 12x5 grid without overflow pages")
        return
    hud.call("_toggle_equipment_panel")
    await process_frame
    view = (game.call("debug_unified_state") as Dictionary).get("view", {})
    if not bool(view.get("panel_open", false)) or not bool(view.get("equipment_board", false)) or not bool(view.get("item_grid", false)):
        _fail("Equipment button did not show one combined gear/grid window")
        return
    var board := game.get_node_or_null("ArmorEquipment/ArmorRoot/ArmorPanel/GearScroll/GearList/EquipmentBoard") as GridContainer
    var chest := board.get_node_or_null("Equipped_身體") as Button if board != null else null
    var head := board.get_node_or_null("Equipped_頭部") as Button if board != null else null
    var weapon := board.get_node_or_null("Equipped_weapon") as Button if board != null else null
    if head == null or chest == null or weapon == null or head.get_node_or_null("Socket_0") == null or head.get_node_or_null("Socket_1") != null or weapon.get_node_or_null("Link_0") == null:
        _fail("Sockets must be drawn on their equipment artwork; unopened sockets must stay hidden")
        return
    var grid := game.get_node_or_null("ArmorEquipment/ArmorRoot/ArmorPanel/BagScroll/BagList/UnifiedItemGrid") as Control
    if grid == null or grid.get_node_or_null("ArmorItem_0") == null or grid.get_node_or_null("Cell_11_4") == null:
        _fail("Unequipped armor does not occupy the same 12x5 grid as weapons")
        return
    armor_ui.close()
    var wearables: Array[Dictionary] = game.get("armor_inventory")
    for i in range(11):
        wearables.append(Armor.normalize({"id":"capacity_" + str(i), "slot":"頭部", "name":"空間測試頭盔", "rarity":"普通", "level":1, "armor":7.0, "prefix":{}, "suffix":{}}))
    game.set("armor_inventory", wearables)
    state = game.call("debug_unified_state")
    if int(state.get("items", -1)) != 12 or int(state.get("overflow", -1)) != 0:
        _fail("Deterministic 2x2 gear placement overlaps or loses items")
        return
    var ground_item := {"id":"too_full", "slot":"頭部", "name":"不能遺失的頭盔", "rarity":"普通", "level":1, "armor":8.0, "color":Color(0.8,0.8,0.8), "prefix":{}, "suffix":{}}
    var player := game.get_node("Player") as CharacterBody3D
    game.call("_spawn_loot_visual", player.global_position, ground_item)
    await create_timer(0.12).timeout
    game.call("_update_loot")
    state = game.call("debug_unified_state")
    if int(state.get("ground", 0)) < 1 or int(state.get("armor", -1)) != 12:
        _fail("Full bag consumed ground equipment or duplicated it")
        return
    var equipped: Dictionary = game.get("equipped_armor")
    var current_head: Dictionary = equipped["頭部"]
    var sockets: Array = current_head["sockets"]
    sockets[0]["gem"] = Gem.make_gem("crimson_burst", 91919)
    current_head["sockets"] = sockets
    equipped["頭部"] = current_head
    game.set("equipped_armor", equipped)
    game.call("_refresh_gameplay_ui")
    if (game.call("debug_hotbar_state") as Dictionary).get("ids", [])[1] != "crimson_burst":
        _fail("Equipped helmet gem does not supply the hotbar")
        return
    game.call("_equip_armor", 0)
    if (game.call("debug_hotbar_state") as Dictionary).get("ids", [])[1] != "":
        _fail("Unequipped helmet still grants its hotbar skill")
        return
    game.call("_equip_armor", 11)
    if (game.call("debug_hotbar_state") as Dictionary).get("ids", [])[1] != "crimson_burst":
        _fail("Returning a socketed helmet lost the gem")
        return
    var weapons: Array[Dictionary] = game.get("weapon_inventory")
    if (Bag.pack(weapons, int(game.get("_equipped_weapon_index")), game.get("armor_inventory"))["overflow"] as Array).size() != 0:
        _fail("Equipment swaps overflowed the physical bag")
        return
    finished = true
    print("RIFTFORGED_UNIFIED_INVENTORY_OK 12x5/art/sockets/hotbar/full-bag/equip-swap")
    quit(0)
