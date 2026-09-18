extends SceneTree

const Armor = preload("res://scripts/armor_equipment.gd")
const Gem = preload("res://scripts/linked_gem_system.gd")
var _finished := false
var _stage := "boot"

func _init() -> void:
    call_deferred("_run")
    call_deferred("_watchdog")

func _watchdog() -> void:
    await create_timer(20.0).timeout
    if not _finished:
        _fail("Timed out")

func _fail(message: String) -> void:
    if _finished:
        return
    _finished = true
    push_error("EQUIPMENT_INTERACTION_FAIL [%s]: %s" % [_stage, message])
    quit(1)

func _check(condition: bool, message: String) -> bool:
    if not condition:
        _fail(message)
    return condition

func _run() -> void:
    var scene := load("res://main.tscn") as PackedScene
    if scene == null:
        _fail("Game scene missing")
        return
    var game := scene.instantiate()
    root.add_child(game)
    await process_frame
    await process_frame
    var hud := game.get_node_or_null("MobileUI") as RiftUnifiedInventoryHUD
    var view := game.get_node_or_null("ArmorEquipment") as RiftEquipmentInteractionUI
    if not _check(hud != null and view != null, "Live scene does not mount interactive inventory"):
        return
    hud.call("_toggle_equipment_panel")
    await process_frame
    if not _check(view.is_open() and bool(view.debug_interaction_state().get("tooltip_ready", false)), "Unified inventory did not open"):
        return
    var start_weapon: Dictionary = game.call("debug_weapon_state")
    var first_uid := int(start_weapon.get("instance_uid", 0))
    var starter_gem: Dictionary = ((start_weapon.get("sockets", []) as Array)[0] as Dictionary).get("gem", {})
    var starter_gem_uid := int(starter_gem.get("uid", 0))
    if not _check(first_uid > 0 and starter_gem_uid > 0, "Equipment and gem identities were not preserved"):
        return

    _stage = "two_weapons_repeated_swaps"
    game.call("debug_add_test_weapon", "blade")
    game.call("debug_add_test_weapon", "focus")
    var weapons: Array[Dictionary] = game.get("weapon_inventory")
    var blade_uid := int(weapons[1].get("instance_uid", 0))
    var focus_uid := int(weapons[2].get("instance_uid", 0))
    if not _check(blade_uid > 0 and focus_uid > 0 and blade_uid != focus_uid and blade_uid != first_uid, "Duplicate weapon instance identities"):
        return
    var grid := view.bag_list.get_node("UnifiedItemGrid") as Control
    var blade_card := grid.get_node_or_null("Weapon_1") as Button
    if not _check(blade_card != null and blade_card.text == "", "Weapon card still covers sockets with text"):
        return
    blade_card.pressed.emit()
    if not _check(int(view.debug_interaction_state().get("selected_uid", 0)) == blade_uid, "Click did not select real weapon"):
        return
    view.bag_list.get_node("EquipSelected").call("emit_signal", "pressed")
    if not _check(int(game.get("_equipped_weapon_index")) == 1 and int((game.call("debug_weapon_state") as Dictionary).get("instance_uid", 0)) == blade_uid, "Equip button never changed equipped weapon"):
        return
    if not _check(absf(float((game.call("debug_weapon_state") as Dictionary).get("damage", 0)) - 42.0) < 0.01 and (game.call("debug_hotbar_state") as Dictionary).get("ids", [])[0] == "", "Weapon stats or hotbar not recomputed"):
        return
    for repeat in range(2):
        # Touch-style: select in bag, then tap the target gear slot.
        view.call("_select_item", "weapon", 0)
        var board := view.gear_list.get_node("EquipmentBoard") as GridContainer
        (board.get_node("Equipped_weapon") as Button).pressed.emit()
        var equipped: Dictionary = game.call("debug_weapon_state")
        if not _check(int(game.get("_equipped_weapon_index")) == 0 and int(equipped.get("instance_uid", 0)) == first_uid and int((((equipped.get("sockets", []) as Array)[0]) as Dictionary).get("gem", {}).get("uid", -1)) == starter_gem_uid, "Repeated touch equip lost original weapon or gem UID"):
            return
        if not _check((game.call("debug_hotbar_state") as Dictionary).get("ids", [])[0] == "ember_bolt", "Restoring socketed weapon did not restore its skill"):
            return
        var payload: Dictionary = view.call("_drag_payload", "weapon", 2)
        if not _check(bool(view.call("_can_drop", Vector2.ZERO, payload, "weapon")) and not bool(view.call("_can_drop", Vector2.ZERO, payload, "頭部")), "Drag validation does not respect slot type"):
            return
        var stale := payload.duplicate(true)
        stale["instance_uid"] = -99
        if not _check(not bool(view.call("_can_drop", Vector2.ZERO, stale, "weapon")), "Stale index/UID can equip a different item"):
            return
        view.call("_drop_on_slot", Vector2.ZERO, payload, "weapon")
        if not _check(int(game.get("_equipped_weapon_index")) == 2 and int((game.call("debug_weapon_state") as Dictionary).get("instance_uid", 0)) == focus_uid, "Drag-drop did not equip focus"):
            return
        view.call("_select_item", "weapon", 1)
        (view.gear_list.get_node("EquipmentBoard/Equipped_weapon") as Button).pressed.emit()
        if not _check(int(game.get("_equipped_weapon_index")) == 1 and int((game.call("debug_weapon_state") as Dictionary).get("instance_uid", 0)) == blade_uid, "Repeating swaps duplicated or lost weapon"):
            return
    weapons = game.get("weapon_inventory")
    var uid_counts := {}
    for weapon in weapons:
        uid_counts[int(weapon.get("instance_uid", 0))] = true
    if not _check(weapons.size() == 3 and uid_counts.size() == 3 and (game.call("debug_unified_state") as Dictionary).get("overflow", -1) == 0, "Weapon duplicates, lost items or changed capacity"):
        return

    _stage = "armor_and_sockets"
    var bag: Array[Dictionary] = game.get("armor_inventory")
    var zero := Armor.normalize({"id":"empty_sockets", "slot":"鞋子", "name":"零孔長靴", "rarity":"普通", "level":2, "armor":8.0, "sockets":[], "links":[], "prefix":{}, "suffix":{}})
    var one := Armor.normalize({"id":"one_socket", "slot":"頭部", "name":"單孔頭盔", "rarity":"魔法", "level":2, "armor":10.0, "sockets":[{"color":"red", "gem":{}}], "links":[], "prefix":{}, "suffix":{}})
    var many := Armor.normalize({"id":"many_sockets", "slot":"身體", "name":"三孔胸甲", "rarity":"稀有", "level":2, "armor":18.0, "sockets":[{"color":"red", "gem":Gem.make_gem("crimson_burst", 98765)},{"color":"green", "gem":{}},{"color":"blue", "gem":{}}], "links":[true,false], "prefix":{"stat":"生命", "value":15}, "suffix":{}})
    bag.append(zero)
    bag.append(one)
    bag.append(many)
    game.set("armor_inventory", bag)
    game.call("_refresh_gameplay_ui")
    grid = view.bag_list.get_node("UnifiedItemGrid") as Control
    var zero_card := grid.get_node_or_null("ArmorItem_1") as Button
    var one_card := grid.get_node_or_null("ArmorItem_2") as Button
    var many_card := grid.get_node_or_null("ArmorItem_3") as Button
    if not _check(zero_card != null and one_card != null and many_card != null and zero_card.text.is_empty() and zero_card.get_node_or_null("Socket_0") == null and one_card.get_node_or_null("Socket_0") != null and one_card.get_node_or_null("Socket_1") == null and many_card.get_node_or_null("Socket_2") != null and many_card.get_node_or_null("Link_0") != null and many_card.get_node_or_null("Link_1") == null, "0/1/3 sockets, actual links or socket-first cards incorrect"):
        return
    var zero_uid := int((bag[1] as Dictionary).get("instance_uid", 0))
    var initial_armor_count := (game.get("armor_inventory") as Array).size()
    view.call("_select_item", "armor", 1)
    # Wrong equipment slot cannot silently equip or launch gem editor.
    (view.gear_list.get_node("EquipmentBoard/Equipped_頭部") as Button).pressed.emit()
    if not _check(int((game.get("equipped_armor") as Dictionary)["鞋子"].get("instance_uid", 0)) != zero_uid, "Wrong slot accepted boots"):
        return
    (view.gear_list.get_node("EquipmentBoard/Equipped_鞋子") as Button).pressed.emit()
    if not _check(int((game.get("equipped_armor") as Dictionary)["鞋子"].get("instance_uid", 0)) == zero_uid and (game.get("armor_inventory") as Array).size() == initial_armor_count, "Boots did not equip without loss"):
        return
    if not _check(int((game.call("debug_unified_state") as Dictionary).get("overflow", -1)) == 0, "Armor swap violated capacity"):
        return

    _stage = "tooltip_and_resolutions"
    grid = view.bag_list.get_node("UnifiedItemGrid") as Control
    many_card = grid.get_node("ArmorItem_3") as Button
    many_card.mouse_entered.emit()
    var tooltip := view.root.get_node("ItemInspection") as Panel
    var info := tooltip.get_node("ItemInspectionText") as Label
    if not _check(tooltip.visible and info.text.contains("三孔胸甲") and info.text.contains("生命 +15") and info.text.contains("UID:98765") and info.text.contains("1—2") and tooltip.mouse_filter == Control.MOUSE_FILTER_IGNORE and info.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Hover info omits real fields or steals pointer"):
        return
    many_card.mouse_exited.emit()
    if not _check(not tooltip.visible, "Desktop tooltip failed to hide on exit"):
        return
    for size in [Vector2i(390, 720), Vector2i(844, 390)]:
        root.size = size
        view.call("_layout")
        await process_frame
        grid = view.bag_list.get_node("UnifiedItemGrid") as Control
        many_card = grid.get_node("ArmorItem_3") as Button
        view.call("_select_item", "armor", 3)
        tooltip = view.root.get_node("ItemInspection") as Panel
        var bounds := tooltip.get_global_rect()
        var screen := get_viewport().get_visible_rect().size
        if not _check(tooltip.visible and bounds.position.x >= -0.01 and bounds.position.y >= -0.01 and bounds.end.x <= screen.x + 0.01 and bounds.end.y <= screen.y + 0.01, "Tooltip overflow at %s" % str(size)):
            return
        if not _check(tooltip.mouse_filter == Control.MOUSE_FILTER_IGNORE and (view.gear_list.get_node("EquipmentBoard/Equipped_身體") as Button).mouse_filter != Control.MOUSE_FILTER_IGNORE, "Mobile tooltip blocked equipment target"):
            return
    view.close()
    if not _check(int(view.debug_interaction_state().get("selected_uid", -1)) == 0 and not bool(view.debug_interaction_state().get("tooltip_visible", true)), "Closing bag left stale selection or tooltip"):
        return
    _finished = true
    print("RIFTFORGED_EQUIPMENT_INTERACTION_OK repeated click/tap/drag swaps, UID, sockets 0/1/3, hover, mobile, hotbar")
    quit(0)
