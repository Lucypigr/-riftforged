extends SceneTree

# Reproduce the user's short-landscape mobile session without modifying the
# combat simulation: thumb motion, touch-release casting in camp and arena.
var finished := false

func _init() -> void:
    call_deferred("_run")
    call_deferred("_watchdog")

func _watchdog() -> void:
    await create_timer(24.0).timeout
    if not finished:
        _check(false, "timeout")

func _check(ok: bool, message: String) -> bool:
    if not ok and not finished:
        finished = true
        push_error("TOUCH_SKILL_FAIL " + message)
        quit(1)
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
    var hud := game.get_node_or_null("MobileUI") as RiftLandscapeFitHUD
    if not _check(hud != null and String(game.debug_camp_state()["region"]) == "camp", "live camp/HUD not loaded"):
        return
    hud._test_touch_mode = true
    root.size = Vector2i(844, 390)
    hud.set_desktop_mode(true)
    hud._layout_desktop(Vector2(844, 390))
    var center := hud.joystick_center
    var baseline: float = float(game.player_mana)
    var before_shots: int = (game.debug_skill_aim()["shots"] as Array).size()
    var before_serial: int = int(game.projectile_serial)
    hud._input(_touch(2, true, center + Vector2(8, 0)))
    if not _check(hud.joystick_touch_id == 2 and game.move_input.x >= 0.35, "8-pixel thumb push fails to start responsive movement"):
        return
    hud._input(_drag(2, center + Vector2(29, 0)))
    if not _check(game.move_input.x >= 0.98, "29-pixel thumb push does not reach full speed"):
        return
    var local_pad := Rect2(Vector2.ZERO, hud.joystick_back.size)
    var local_knob := Rect2(hud.joystick_knob.position, hud.joystick_knob.size)
    if not _check(local_pad.encloses(local_knob), "joystick knob leaves its visible circle at full speed"):
        return
    var skill := hud.skill_buttons[0].get_global_rect().get_center()
    if not _check(hud.skill_buttons[0].visible and not hud.skill_buttons[0].disabled, "equipped starter fireball is not touchable"):
        return
    hud._input(_touch(7, true, skill))
    if not _check(hud.debug_aim()["touch_id"] == 7 and hud.debug_aim()["guide"], "second-finger aim did not begin"):
        return
    hud._input(_drag(7, skill + Vector2(70, 0)))
    hud._input(_touch(7, false, skill + Vector2(70, 0)))
    if not _check(hud.debug_aim()["touch_id"] == -1 and not hud.debug_aim()["guide"] and game.get_node_or_null("SafeCamp/CampSkillPreview") != null, "camp release was silently discarded instead of showing safe skill preview"):
        return
    if not _check(is_equal_approx(float(game.player_mana), baseline) and game.projectile_serial == before_serial and (game.debug_skill_aim()["shots"] as Array).size() == before_shots, "camp practice consumed resources or fired a real combat projectile"):
        return
    if not _check(hud.joystick_touch_id == 2 and game.move_input.x >= 0.98, "second finger interrupted movement"):
        return
    hud._input(_touch(2, false, center + Vector2(29, 0)))
    if not _check(hud.joystick_touch_id == -1 and game.move_input == Vector2.ZERO, "joystick release left movement running"):
        return
    # Enter the real combat arena through the same portal as normal gameplay.
    game.player.global_position = Vector3(0.0, 0.0, 189.5)
    game._interact_portal()
    if not _check(String(game.debug_camp_state()["region"]) == "combat", "portal did not enter real combat"):
        return
    var mana_before_combat: float = float(game.player_mana)
    var combat_shots: int = (game.debug_skill_aim()["shots"] as Array).size()
    hud._input(_touch(8, true, skill))
    if not _check(hud.debug_aim()["touch_id"] == 8, "combat skill did not acquire new finger"):
        return
    hud._input(_drag(8, skill + Vector2(72, 0)))
    hud._input(_touch(8, false, skill + Vector2(72, 0)))
    if not _check(float(game.player_mana) < mana_before_combat and (game.debug_skill_aim()["shots"] as Array).size() > combat_shots and hud.debug_aim()["touch_id"] == -1, "actual arena skill did not consume mana, launch projectile and clear aim"):
        return
    finished = true
    print("RIFTFORGED_TOUCH_SKILL_OK responsive-8px/fullspeed-29px/knob-contained/two-finger/camp-preview/portal-real-skill")
    quit(0)
