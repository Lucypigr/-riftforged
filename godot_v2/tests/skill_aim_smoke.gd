extends SceneTree

const AimRules = preload("res://scripts/skill_aim_rules.gd")
var finished := false

func _init() -> void:
    call_deferred("_run")
    call_deferred("_watchdog")

func _watchdog() -> void:
    await create_timer(25.0).timeout
    if not finished:
        _fail("watchdog timeout")

func _fail(message: String) -> void:
    if finished:
        return
    finished = true
    push_error("SKILL_AIM_FAIL: " + message)
    quit(1)

func _check(ok: bool, message: String) -> bool:
    if not ok:
        _fail(message)
    return ok

func _touch(id: int, pressed: bool, point: Vector2) -> InputEventScreenTouch:
    var event := InputEventScreenTouch.new()
    event.index = id
    event.pressed = pressed
    event.position = point
    return event

func _drag(id: int, point: Vector2) -> InputEventScreenDrag:
    var event := InputEventScreenDrag.new()
    event.index = id
    event.position = point
    return event

func _run() -> void:
    var game := (load("res://main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    await process_frame
    await process_frame
    var hud := game.get_node_or_null("MobileUI") as RiftSkillAimHUD
    if not _check(hud != null and game.has_method("debug_skill_aim"), "main scene is not running aiming HUD/controller"):
        return
    var expected := {
        "ember_bolt":"direction", "crimson_burst":"none", "swift_aura":"none",
        "rift_trail":"none", "rift_dash":"direction", "cleave":"melee",
        "ground_slam":"melee", "molten_strike":"melee", "burning_arrow":"direction",
        "split_arrow":"direction", "ice_shot":"direction", "galvanic_arrow":"direction",
        "freezing_pulse":"direction", "arc":"auto", "frost_nova":"none"
    }
    for id in expected:
        var gem := {"id":id}
        if not _check(String(AimRules.descriptor(gem)["mode"]) == expected[id], "aim mode missing or wrong: " + id):
            return
    if not _check(expected.size() == 15 and AimRules.descriptor({"id":"ember_bolt"})["range"] == 11.5 and AimRules.descriptor({"id":"rift_dash"})["range"] == 4.6, "fixed skill ranges changed"):
        return
    if not _check(AimRules.valid_direction(Vector3.ZERO, Vector3.ZERO).length() > 0.99 and AimRules.limit_point(Vector3.ZERO, Vector3(99,0,0), 7).length() <= 7.001, "fallback direction or point cap incorrect"):
        return

    game._v5_force_mobile = true
    hud._test_touch_mode = true
    root.size = Vector2i(390, 844)
    hud.set_desktop_mode(false)
    hud._layout_mobile_portrait(Vector2(390, 844))
    game._refresh_gameplay_ui()
    var entries: Array = game._hotbar_entries()
    if not _check(String((entries[0] as Dictionary).get("gem", {}).get("id", "")) == "ember_bolt", "starter fireball not on first slot"):
        return
    var move_point := hud.joystick_center + Vector2(20, 0)
    hud._input(_touch(2, true, move_point))
    if not _check(hud.joystick_touch_id == 2 and game.move_input.length_squared() > 0.01, "left thumb did not own joystick"):
        return
    var action := hud.skill_buttons[0].position + hud.skill_buttons[0].size * 0.5
    var before_mana := float(game.player_mana)
    var before_shots := (game.debug_skill_aim()["shots"] as Array).size()
    hud._input(_touch(7, true, action))
    if not _check(hud.debug_aim()["touch_id"] == 7 and hud.debug_aim()["guide"] and is_equal_approx(game.player_mana, before_mana) and (game.debug_skill_aim()["shots"] as Array).size() == before_shots, "press cast before release"):
        return
    hud._input(_drag(7, action + Vector2(76, 0)))
    if not _check(hud.debug_aim()["guide"] and hud.joystick_touch_id == 2, "drag lost guide or stole joystick"):
        return
    hud._input(_touch(7, false, action + Vector2(76, 0)))
    var state: Dictionary = game.debug_skill_aim()
    var shots: Array = state["shots"]
    if not _check(int(state["releases"]) == 1 and shots.size() > before_shots and float(game.player_mana) < before_mana and not hud.debug_aim()["guide"], "release did not cast exactly once and clear indicator"):
        return
    for shot in shots:
        if not _check(absf((shot["end"] as Vector3).distance_to(shot["start"]) - float(shot["range"])) < 0.02 and (shot["direction"] as Vector3).x > 0.8, "shot did not retain fixed range and manual direction"):
            return
    if not _check(hud.joystick_touch_id == 2 and game.move_input.length_squared() > 0.01, "casting stopped independent joystick input"):
        return

    var mana_after := float(game.player_mana)
    hud._input(_touch(9, true, action))
    var cancel_center := hud._aim_cancel.position + hud._aim_cancel.size * 0.5
    hud._input(_drag(9, cancel_center))
    hud._input(_touch(9, false, cancel_center))
    if not _check(int(game.debug_skill_aim()["releases"]) == 1 and is_equal_approx(game.player_mana, mana_after) and not hud.debug_aim()["guide"], "cancel released a skill or consumed mana"):
        return
    hud._input(_touch(11, true, action))
    game._open_armor_ui()
    if not _check(hud.debug_aim()["touch_id"] == -1 and not hud.debug_aim()["guide"] and is_equal_approx(game.player_mana, mana_after), "inventory did not cancel aiming"):
        return
    hud._input(_touch(2, false, move_point))
    finished = true
    print("RIFTFORGED_SKILL_AIM_OK modes15/ranges/direction/two-touch/press-drag-release/cancel/inventory")
    quit(0)
