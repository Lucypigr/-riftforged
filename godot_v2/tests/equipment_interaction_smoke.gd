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

func _check(ok: bool, message: String) -> bool:
    if not ok:
        _fail(message)
    return ok

func _armor_index(game: Node, id: String) -> int:
    var items: Array = game.get("armor_inventory")
    for i in range(items.size()):
        if String((items[i] as Dictionary).get("id", "")) == id:
            return i
    return -1

func _run() -> void:
    var game := (load("res://main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    await process_frame
    await process_frame
    var hud := game.get_node_or_null("MobileUI") as RiftUnifiedInventoryHUD
    var view := game.get_node_or_null("ArmorEquipment") as RiftEquipmentInteractionUI
    if not _check(hud != null and view != null, "Interactive inventory not installed in live scene"):
        return
    hud.call("_toggle_equipment_panel")
    await process_frame
    if not _check(view.is_open() and bool(view.debug_interaction_state().get("tooltip_ready", false)), "Equipment view failed to open"):
        return
    var first: Dictionary = game.call("debug_weapon_state")
    var first_uid := int(first.get("instance_uid", 0))
    var gem_uid := int(((first["sockets"] as Array)[0] as Dictionary).get("gem", {}).get("uid", 0))
    if not _check(first_uid > 0 and gem_uid > 0, "Missing stable weapon or gem UID"):
        return

    _stage = "click_tap_drag_repeat"
    game.call("debug_add_test_weapon", "blade")
    game.call("debug_add_test_weapon", "focus")
    var weapons: Array[Dictionary] = game.get("weapon_inventory")
    var blade_uid := int(weapons[1].get("instance_uid", 0))
    var focus_uid := int(weapons[2].get("instance_uid", 0))
    if not _check(blade_uid > 0 and focus_uid > 0 and blade_uid != focus_uid and blade_uid != first_uid, "Weapon identity collision"):
        return
    var grid := view.bag_list.get_node("UnifiedItemGrid") as Control
    var blade := grid.get_node("Weapon_1") as Button
    if not _check(blade.text.is_empty() and blade.get_node_or_null("Socket_0") == null, "Zero-socket weapon card has text or ghost sockets"):
        return
    blade.pressed.emit()
    if not _check(int(view.debug_interaction_state().get("selected_uid", 0)) == blade_uid, "Click selection did not store exact item identity"):
        return
    (view.bag_list.get_node("EquipSelected") as Button).pressed.emit()
    if not _check(int(game.get("_equipped_weapon_index")) == 1 and int((game.call("debug_weapon_state") as Dictionary).get("instance_uid", 0)) == blade_uid and absf(float((game.call("debug_weapon_state") as Dictionary).get("damage", 0)) - 42.0) < 0.01, "Equip button failed to swap weapon or stats"):
        return
    if not _check((game.call("debug_hotbar_state") as Dictionary).get("ids", [])[0] == "", "Old equipped gem still grants a skill"):
        return
    for cycle in range(2):
        view.call("_select_item", "weapon", 0)
        (view.gear_list.get_node("EquipmentBoard/Equipped_weapon") as Button).pressed.emit()
        var weapon: Dictionary = game.call("debug_weapon_state")
        if not _check(int(weapon.get("instance_uid", 0)) == first_uid and int(((weapon["sockets"] as Array)[0] as Dictionary).get("gem", {}).get("uid", 0)) == gem_uid and (game.call("debug_hotbar_state") as Dictionary).get("ids", [])[0] == "ember_bolt", "Touch slot failed to restore original weapon and gem"):
            return
        var payload: Dictionary = view.call("_drag_payload", "weapon", 2)
        var stale := payload.duplicate(true)
        stale["instance_uid"] = -123
        if not _check(bool(view.call("_can_drop", Vector2.ZERO, payload, "weapon")) and not bool(view.call("_can_drop", Vector2.ZERO, payload, "頭部")) and not bool(view.call("_can_drop", Vector2.ZERO, stale, "weapon")), "Drag can target wrong slot or stale index"):
            return
        view.call("_drop_on_slot", Vector2.ZERO, payload, "weapon")
        if not _check(int((game.call("debug_weapon_state") as Dictionary).get("instance_uid", 0)) == focus_uid, "Drop onto weapon slot did not equip"):
            return
        view.call("_select_item", "weapon", 1)
        (view.gear_list.get_node("EquipmentBoard/Equipped_weapon") as Button).pressed.emit()
        if not _check(int((game.call("debug_weapon_state") as Dictionary).get("instance_uid", 0)) == blade_uid, "Repeated swap lost blade"):
            return
    weapons = game.get("weapon_inventory")
    var identities := {}
    for weapon in weapons:
        identities[int(weapon.get("instance_uid", 0))] = true
    if not _check(weapons.size() == 3 and identities.size() == 3 and int((game.call("debug_unified_state") as Dictionary).get("overflow", -1)) == 0, "Swaps duplicated items or exceeded fixed bag"):
        return

    _stage = "armor_0_1_multi_socket"
    var bag: Array[Dictionary] = game.get("armor_inventory")
    bag.append(Armor.normalize({"id":"zero", "slot":"鞋子", "name":"零孔靴", "armor":8.0, "sockets":[], "links":[], "prefix":{}, "suffix":{}}))
    bag.append(Armor.normalize({"id":"single", "slot":"頭部", "name":"單孔盔", "armor":10.0, "sockets":[{"color":"red", "gem":{}}], "links":[], "prefix":{}, "suffix":{}}))
    bag.append(Armor.normalize({"id":"many", "slot":"身體", "name":"三孔胸甲", "armor":18.0, "rarity":"稀有", "sockets":[{"color":"red", "gem":Gem.make_gem("crimson_burst", 98765)},{"color":"green", "gem":{}},{"color":"blue", "gem":{}}], "links":[true,false], "prefix":{"stat":"生命", "value":15}, "suffix":{}}))
    game.set("armor_inventory", bag)
    game.call("_refresh_gameplay_ui")
    grid = view.bag_list.get_node("UnifiedItemGrid") as Control
    var empty_card := grid.get_node("ArmorItem_%d" % _armor_index(game, "zero")) as Button
    var single_card := grid.get_node("ArmorItem_%d" % _armor_index(game, "single")) as Button
    var multi_card := grid.get_node("ArmorItem_%d" % _armor_index(game, "many")) as Button
    if not _check(empty_card.text == "" and empty_card.get_node_or_null("Socket_0") == null and single_card.get_node_or_null("Socket_0") != null and single_card.get_node_or_null("Socket_1") == null and multi_card.get_node_or_null("Socket_2") != null and multi_card.get_node_or_null("Link_0") != null and multi_card.get_node_or_null("Link_1") == null, "0/1/multiple real socket graphics incorrect"):
        return
    var boots_index := _armor_index(game, "zero")
    var boots_uid := int(((game.get("armor_inventory") as Array)[boots_index] as Dictionary).get("instance_uid", 0))
    var original_size := (game.get("armor_inventory") as Array).size()
    view.call("_select_item", "armor", boots_index)
    (view.gear_list.get_node("EquipmentBoard/Equipped_頭部") as Button).pressed.emit()
    if not _check(int((game.get("equipped_armor") as Dictionary)["鞋子"].get("instance_uid", 0)) != boots_uid, "Incompatible equipment slot accepted boots"):
        return
    (view.gear_list.get_node("EquipmentBoard/Equipped_鞋子") as Button).pressed.emit()
    if not _check(int((game.get("equipped_armor") as Dictionary)["鞋子"].get("instance_uid", 0)) == boots_uid and (game.get("armor_inventory") as Array).size() == original_size, "Armor exchange dropped or cloned gear"):
        return

    _stage = "inspection_viewport"
    var inspect_index := _armor_index(game, "many")
    grid = view.bag_list.get_node("UnifiedItemGrid") as Control
    multi_card = grid.get_node("ArmorItem_%d" % inspect_index) as Button
    multi_card.mouse_entered.emit()
    var popup := view.root.get_node("ItemInspection") as Panel
    var label := popup.get_node("ItemInspectionText") as Label
    if not _check(popup.visible and label.text.contains("三孔胸甲") and label.text.contains("生命 +15") and label.text.contains("UID:98765") and label.text.contains("1—2") and popup.mouse_filter == Control.MOUSE_FILTER_IGNORE and label.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Hover inspector missed real item fields or intercepted input: " + label.text):
        return
    multi_card.mouse_exited.emit()
    if not _check(not popup.visible, "PC inspector remained after leaving card"):
        return
    for resolution in [Vector2i(390, 720), Vector2i(844, 390)]:
        root.size = resolution
        view.call("_layout")
        await process_frame
        inspect_index = _armor_index(game, "many")
        view.call("_select_item", "armor", inspect_index)
        popup = view.root.get_node("ItemInspection") as Panel
        var box := popup.get_global_rect()
        var screen := view.get_viewport().get_visible_rect().size
        if not _check(popup.visible and box.position.x >= 0 and box.position.y >= 0 and box.end.x <= screen.x + 0.01 and box.end.y <= screen.y + 0.01, "Inspector overflow: " + str(resolution)):
            return
        if not _check((view.gear_list.get_node("EquipmentBoard/Equipped_身體") as Button).mouse_filter != Control.MOUSE_FILTER_IGNORE and popup.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Inspector blocked mobile equipment touch"):
            return
    view.close()
    if not _check(int(view.debug_interaction_state().get("selected_uid", -1)) == 0 and not bool(view.debug_interaction_state().get("tooltip_visible", true)), "Close left selection or popup on screen"):
        return
    _finished = true
    print("RIFTFORGED_EQUIPMENT_INTERACTION_OK repeat/tap/drag/UID/0-1-3-sockets/hover/portrait/landscape")
    quit(0)
