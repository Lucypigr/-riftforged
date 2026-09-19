extends SceneTree

const GemRules = preload("res://scripts/linked_gem_system.gd")
var _finished := false
var _stage := "boot"

func _init() -> void:
    call_deferred("_run")
    call_deferred("_watchdog")

func _watchdog() -> void:
    await create_timer(22.0).timeout
    if not _finished:
        _fail("Timeout")

func _fail(reason: String) -> void:
    if _finished:
        return
    _finished = true
    push_error("V5_SMOKE_FAIL [%s]: %s" % [_stage, reason])
    quit(1)

func _check(condition: bool, reason: String) -> bool:
    if not condition:
        _fail(reason)
    return condition

func _touch(id: int, pressed: bool, location: Vector2) -> InputEventScreenTouch:
    var event := InputEventScreenTouch.new()
    event.index = id
    event.pressed = pressed
    event.position = location
    return event

func _mouse(pressed: bool, location: Vector2) -> InputEventMouseButton:
    var event := InputEventMouseButton.new()
    event.button_index = MOUSE_BUTTON_LEFT
    event.pressed = pressed
    event.position = location
    return event

func _check_layout(hud: RiftV5HUD, screen: Vector2) -> bool:
    var area := Rect2(Vector2.ZERO, screen)
    var attack := Rect2(hud.attack_button.position, hud.attack_button.size)
    var stick := Rect2(hud.joystick_back.position, hud.joystick_back.size)
    if not _check(attack.size.x > 1.32 * hud.skill_buttons[0].size.x and area.encloses(attack) and area.encloses(stick), "Attack is too small or outside safe display"):
        return false
    for i in range(hud.skill_buttons.size()):
        var button := hud.skill_buttons[i]
        var rect := Rect2(button.position, button.size)
        if not _check(button.size.x >= 43.0 and area.encloses(rect) and not rect.intersects(attack) and not rect.intersects(stick), "Skill %d overlaps attack/joystick or screen edge: %s" % [i, rect]):
            return false
        for j in range(i + 1, hud.skill_buttons.size()):
            var other := Rect2(hud.skill_buttons[j].position, hud.skill_buttons[j].size)
            if not _check(not rect.intersects(other), "Skill %d and %d overlap" % [i, j]):
                return false
    return true

func _run() -> void:
    var game := (load("res://main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    await process_frame
    await process_frame
    var hud := game.get_node_or_null("MobileUI") as RiftV5HUD
    var bag := game.get_node_or_null("ArmorEquipment") as RiftV5EquipmentUI
    var gems := game.get_node_or_null("LinkedGemInventory") as RiftV5GemUI
    if not _check(hud != null and bag != null and gems != null and game.has_method("debug_v5_state"), "Actual main game not wired to V5 controls, gear or gems"):
        return
    var initial: Dictionary = game.call("debug_v5_state")
    if not _check(bool((initial["inventory"] as Dictionary).get("gem_embedded", false)) and gems.panel.get_parent() == bag.panel and not gems.is_open() and not bag.is_open(), "Gem and equipment panels are still separate modals"):
        return
    if not _check(hud.skill_buttons.size() == 5 and hud.attack_button.action_mode == BaseButton.ACTION_MODE_BUTTON_PRESS and not hud.gem_panel.visible, "Hotbar count/press-only attack or deprecated dummy gem panel incorrect"):
        return

    _stage = "pc_mouse"
    game._v5_force_mobile = false
    game._unhandled_input(_mouse(true, Vector2(420.0, 370.0)))
    if not _check(game.mouse_fire_held, "Desktop left click stopped working"):
        return
    game._unhandled_input(_mouse(false, Vector2(420.0, 370.0)))
    if not _check(not game.mouse_fire_held, "Desktop mouse release did not clear held state"):
        return

    _stage = "same_window"
    game.call("debug_add_test_weapon", "blade")
    var blade: Dictionary = (game.get("weapon_inventory") as Array)[1]
    var uid := int(blade.get("instance_uid", 0))
    hud.call("_toggle_equipment_panel")
    await process_frame
    if not _check(bag.is_open() and not gems.is_open() and bool((game.call("debug_v5_state") as Dictionary).get("modal", false)), "Single inventory entry did not open gear page and block gameplay"):
        return
    bag.call("_select_item", "weapon", 1)
    if not _check(int((bag.selected_edit_target() as Dictionary).get("uid", 0)) == uid, "Inventory selection lost bag weapon UID"):
        return
    (bag.bag_list.get_node("EditSelectedSockets") as Button).pressed.emit()
    await process_frame
    var state: Dictionary = game.call("debug_v5_state")
    if not _check(bag.is_open() and gems.is_open() and bool((state["inventory"] as Dictionary).get("gem_page", false)) and int(state["target_uid"]) == uid and String(state["target_kind"]) == "weapon", "Selected bag weapon did not open its sockets inside same inventory"):
        return
    var stash_count: int = game.gem_inventory.size()
    var currency_before := int(game.gem_currency.get("jeweller", 0))
    game.call("_use_currency", "jeweller")
    var modified: Dictionary = (game.get("weapon_inventory") as Array)[1]
    if not _check(int(modified.get("instance_uid", 0)) == uid and (modified.get("sockets", []) as Array).size() == 1 and game.gem_inventory.size() == stash_count and int(game.gem_currency.get("jeweller", 0)) == currency_before - 1, "Editing bag sockets rerolled item identity or consumed wrong resources"):
        return
    var socket_color := String((modified["sockets"][0] as Dictionary).get("color", ""))
    var matching := -1
    for i in range(game.gem_inventory.size()):
        if String(game.gem_inventory[i].get("color", "")) == socket_color:
            matching = i
            break
    if matching >= 0:
        var chosen_uid := int(game.gem_inventory[matching].get("uid", 0))
        game.call("_select_gem", matching)
        game.call("_use_socket", 0)
        modified = (game.get("weapon_inventory") as Array)[1]
        if not _check(int(((modified["sockets"] as Array)[0] as Dictionary).get("gem", {}).get("uid", 0)) == chosen_uid and game.gem_inventory.size() == stash_count - 1, "Same-window gem install lost identity or duplicated stash"):
            return
        game.call("_use_socket", 0)
        if not _check(game.gem_inventory.size() == stash_count, "Same-window extraction did not return gem to real stash"):
            return
    (bag.panel.get_node("GearTab") as Button).pressed.emit()
    if not _check(bag.is_open() and not gems.is_open() and not bool((game.call("debug_v5_state") as Dictionary)["inventory"].get("gem_page", true)), "Switching page closed entire bag or left overlay open"):
        return

    _stage = "touch_and_modal"
    bag.close()
    game._v5_force_mobile = true
    hud._test_touch_mode = true
    root.size = Vector2i(390, 844)
    hud.set_desktop_mode(false)
    hud.call("_layout_mobile_portrait", Vector2(390, 844))
    if not _check_layout(hud, Vector2(390, 844)):
        return
    var first_joystick := hud.joystick_center + Vector2(26.0, -8.0)
    var fire_before: int = int(game.projectile_serial)
    game.attack_cooldown = 0.0
    hud._input(_touch(2, true, first_joystick))
    if not _check(hud.joystick_touch_id == 2 and game.move_input.length() > 0.10, "Joystick did not own first finger and move character"):
        return
    var drag := InputEventScreenDrag.new()
    drag.index = 2
    drag.position = hud.joystick_center + Vector2(44.0, 0.0)
    hud._input(drag)
    game._unhandled_input(_mouse(true, first_joystick))
    game._physics_process(0.016)
    if not _check(not game.mouse_fire_held and game.projectile_serial == fire_before and game.attack_cooldown <= 0.001, "Joystick or synthetic touch-mouse triggered basic attack"):
        return
    hud._input(_touch(5, true, hud.attack_button.position + hud.attack_button.size * 0.5))
    if not _check(hud.joystick_touch_id == 2 and game.move_input.length() > 0.10, "Second finger hijacked joystick"):
        return
    # Engine button signal: one explicit press, while first finger moves.
    var enemy: CharacterBody3D = (game.enemies[0] as Dictionary)["node"]
    enemy.global_position = game.player.global_position + Vector3(2.0, 0.0, 0.0)
    hud.attack_button.pressed.emit()
    if not _check(game.projectile_serial == fire_before + 1 and game.attack_cooldown > 0.0 and game.move_input.length() > 0.10, "Explicit second-finger button did not attack once while moving"):
        return
    game.attack_cooldown = 0.0
    game._physics_process(0.016)
    if not _check(game.projectile_serial == fire_before + 1 and not game.mouse_fire_held, "Held joystick or attack generated a second unrequested shot"):
        return
    var mana_before: float = float(game.player_mana)
    hud.skill_buttons[0].pressed.emit()
    if not _check(game.player_mana < mana_before and game.attack_cooldown <= 0.001, "Casting while moving failed or also triggered basic attack"):
        return
    hud._input(_touch(2, false, first_joystick))
    if not _check(hud.joystick_touch_id == -1 and game.move_input == Vector2.ZERO, "Releasing joystick left movement state"):
        return
    hud._input(_touch(2, true, first_joystick))
    game.call("_open_armor_ui")
    if not _check(hud.joystick_touch_id == -1 and game.move_input == Vector2.ZERO and not game.mouse_fire_held and hud.attack_button.disabled, "Opening inventory did not cancel gameplay input"):
        return
    game.attack_cooldown = 0.0
    game._unhandled_input(_mouse(true, first_joystick))
    bag.close()
    game._physics_process(0.016)
    if not _check(game.projectile_serial >= fire_before + 1 and game.attack_cooldown <= 0.001 and not game.mouse_fire_held and game.move_input == Vector2.ZERO and not hud.attack_button.disabled, "Closing inventory fired or retained a stale touch"):
        return

    _stage = "responsive_landscape"
    root.size = Vector2i(1280, 720)
    hud.set_desktop_mode(true)
    hud.call("_layout_desktop", Vector2(1280, 720))
    if not _check_layout(hud, Vector2(1280, 720)):
        return
    if not _check(hud.attack_button.size.x >= 110.0 and hud.skill_buttons.size() == 5 and not hud.gem_button.visible, "Landscape thumb-cluster not active"):
        return
    _finished = true
    print("RIFTFORGED_V5_OK integrated-gear/gems/UID/currency/two-touch/isolated-mouse/press-only/skills/mana/portrait/landscape")
    quit(0)
