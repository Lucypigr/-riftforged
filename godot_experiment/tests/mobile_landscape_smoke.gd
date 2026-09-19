extends SceneTree

var _done := false

func _init() -> void:
    call_deferred("_run")
    call_deferred("_watchdog")

func _watchdog() -> void:
    await create_timer(20.0).timeout
    if not _done:
        _fail("timeout")

func _fail(reason: String) -> void:
    if _done:
        return
    _done = true
    push_error("MOBILE_LANDSCAPE_FAIL: " + reason)
    quit(1)

func _touch(pressed: bool, point: Vector2) -> InputEventScreenTouch:
    var event := InputEventScreenTouch.new()
    event.index = 0
    event.pressed = pressed
    event.position = point
    return event

func _run() -> void:
    var game := (load("res://main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    await process_frame
    await process_frame
    var hud := game.get_node("MobileUI") as RiftMobileLandscapeHUD
    var view := game.get_node("ArmorEquipment") as RiftMobileEquipmentUI
    if hud == null or view == null:
        _fail("Mobile HUD or equipment class not connected to live game")
        return
    game.call("debug_add_test_weapon", "blade")
    var old_weapon: Dictionary = game.call("debug_weapon_state")
    var old_uid := int(old_weapon.get("instance_uid", 0))
    var new_uid := int(((game.get("weapon_inventory") as Array)[1] as Dictionary).get("instance_uid", 0))
    if old_uid <= 0 or new_uid <= 0 or old_uid == new_uid:
        _fail("Physical weapon UIDs not stable")
        return
    root.size = Vector2i(1280, 720)
    view.set("_simulate_touch_landscape", true)
    hud.set_desktop_mode(true)
    view.call("_layout")
    hud.call("_layout_touch_landscape", Vector2(1280, 720))
    hud.call("_toggle_equipment_panel")
    await process_frame
    var sizes: Dictionary = hud.debug_touch_landscape_hud()
    if (sizes["equipment_size"] as Vector2).x < 130 or (sizes["skill_size"] as Vector2).x < 100 or hud.attack_button.size.x < 80:
        _fail("Landscape touch HUD retains too-small buttons")
        return
    var layout: Dictionary = view.debug_mobile_interaction()
    if not bool(layout["landscape"]) or (layout["panel"] as Vector2).x < 1000 or float(layout["grid_cell"]) < 58:
        _fail("Landscape still uses narrow stacked layout or tiny bag cells")
        return
    var grid := view.bag_list.get_node("UnifiedItemGrid") as Control
    var card := grid.get_node("Weapon_1") as Button
    var board := view.gear_list.get_node("EquipmentBoard") as GridContainer
    var gear := board.get_node("Equipped_weapon") as Button
    var bag_scroll := view.panel.get_node("BagScroll") as ScrollContainer
    var gear_scroll := view.panel.get_node("GearScroll") as ScrollContainer
    var from := card.get_global_rect().get_center()
    var to := gear.get_global_rect().get_center()
    if not bag_scroll.get_global_rect().has_point(from) or not gear_scroll.get_global_rect().has_point(to) or gear.size.y < 100:
        _fail("Bag or equipment targets not visible/touchable")
        return
    view._input(_touch(true, from))
    if int(view.debug_mobile_interaction()["finger"]) != 0:
        _fail("Touch did not capture inventory item")
        return
    view.set("_touch_started", Time.get_ticks_msec() - 500)
    view._process(0.02)
    if not bool(view.debug_mobile_interaction()["holding"]) or not bool(view.debug_interaction_state()["tooltip_visible"]):
        _fail("Long press failed to show equipment information")
        return
    view._input(_touch(false, from))
    if bool(view.debug_interaction_state()["tooltip_visible"]) or int(game.get("_equipped_weapon_index")) != 0:
        _fail("Long-press release equipped item or left floating inspector")
        return
    view._input(_touch(true, from))
    var drag := InputEventScreenDrag.new()
    drag.index = 0
    drag.position = from.lerp(to, 0.5)
    view._input(drag)
    drag.position = to
    view._input(drag)
    if not bool(view.debug_mobile_interaction()["dragging"]) or not bool(view.debug_mobile_interaction()["ghost_visible"]):
        _fail("Finger drag did not show moving item preview")
        return
    view._input(_touch(false, to))
    await process_frame
    if int(game.get("_equipped_weapon_index")) != 1 or int((game.call("debug_weapon_state") as Dictionary).get("instance_uid", 0)) != new_uid:
        _fail("Touch drag did not equip correct weapon")
        return
    if bool(view.debug_mobile_interaction()["ghost_visible"]) or int(view.debug_mobile_interaction()["finger"]) != -1:
        _fail("Touch gesture did not clean up on release")
        return
    view.call("_select_item", "weapon", 0)
    (view.gear_list.get_node("EquipmentBoard/Equipped_weapon") as Button).pressed.emit()
    if int((game.call("debug_weapon_state") as Dictionary).get("instance_uid", 0)) != old_uid:
        _fail("Tap-to-slot regression after touch drag")
        return
    view.close()
    root.size = Vector2i(390, 844)
    view.call("_layout")
    await process_frame
    if bool(view.debug_mobile_interaction()["landscape"]) or view.is_open():
        _fail("Portrait transition or close state broken")
        return
    _done = true
    print("RIFTFORGED_MOBILE_LANDSCAPE_OK big-targets/side-by-side/hold/touch-drag/tap/portrait")
    quit(0)
