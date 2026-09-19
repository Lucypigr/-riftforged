extends SceneTree

var finished := false

func _init() -> void:
    call_deferred("_run")
    call_deferred("_watchdog")

func _watchdog() -> void:
    await create_timer(30.0).timeout
    if not finished:
        _check(false, "watchdog timeout")

func _check(ok: bool, description: String) -> bool:
    if not ok and not finished:
        finished = true
        push_error("ARC_TOUCH_FAIL " + description)
        quit(1)
    return ok

func _touch(id: int, down: bool, point: Vector2) -> InputEventScreenTouch:
    var touch := InputEventScreenTouch.new()
    touch.index = id
    touch.pressed = down
    touch.position = point
    return touch

func _drag(id: int, point: Vector2) -> InputEventScreenDrag:
    var drag := InputEventScreenDrag.new()
    drag.index = id
    drag.position = point
    return drag

func _run() -> void:
    var game := (load("res://main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    await process_frame
    await process_frame
    var hud := game.get_node_or_null("MobileUI") as RiftArcTouchHUD
    if not _check(hud != null and game.debug_camp_state()["region"] == "camp", "live scene not using circular input HUD"):
        return
    game._v5_force_mobile = true
    hud._test_touch_mode = true
    for viewport in [Vector2i(844, 390), Vector2i(932, 430), Vector2i(1280, 720)]:
        root.size = viewport
        hud.set_desktop_mode(true)
        hud._layout_desktop(Vector2(viewport))
        var bounds := Rect2(Vector2.ZERO, Vector2(viewport))
        var primary := hud.attack_button.get_global_rect()
        if not _check(hud.attack_button.visible and not hud.skill_buttons[4].visible and bounds.encloses(primary) and not hud.action_dock.visible, "slot five or rectangular grid still displayed"):
            return
        for i in range(4):
            var button := hud.skill_buttons[i]
            var rect := button.get_global_rect()
            var style := button.get_theme_stylebox("normal") as StyleBoxFlat
            if not _check(button.visible and bounds.encloses(rect) and not rect.intersects(primary) and style != null and style.corner_radius_top_left >= 25, "skill %d is not an independent visible circle" % (i + 1)):
                return
            for j in range(i + 1, 4):
                if not _check(not rect.intersects(hud.skill_buttons[j].get_global_rect()), "circle hitboxes overlap"):
                    return
    root.size = Vector2i(844, 390)
    hud._layout_desktop(Vector2(844, 390))
    hud._test_touch_mode = false
    var origin := hud.joystick_center
    hud._input(_touch(2, true, origin + Vector2(8, 0)))
    if not _check(hud.joystick_touch_id == 2 and game.move_input.x > 0.30, "first touch not moving"):
        return
    hud._input(_drag(2, origin + Vector2(160, 0)))
    if not _check(game.move_input.x > 0.95 and hud.joystick_center.x > origin.x + 70, "joystick origin did not follow fast thumb"):
        return
    hud._input(_drag(2, origin + Vector2(85, 0)))
    if not _check(game.move_input.x < -0.50, "cannot reverse direction without returning to original pad"):
        return
    var new_center := hud.joystick_center
    hud._input(_drag(2, new_center + Vector2(0, -29)))
    if not _check(game.move_input.y < -0.90, "continuous turn upward failed"):
        return
    var pad := Rect2(Vector2.ZERO, hud.joystick_back.size)
    if not _check(pad.encloses(Rect2(hud.joystick_knob.position, hud.joystick_knob.size)), "knob left pad"):
        return
    var first := hud.skill_buttons[0].get_global_rect().get_center()
    var mana := float(game.player_mana)
    hud._input(_touch(7, true, first))
    if not _check(hud.debug_aim()["touch_id"] == 7 and hud.debug_aim()["guide"] and game.move_input.y < -0.9, "second thumb cannot begin directional aim"):
        return
    hud._input(_drag(7, first + Vector2(75, -12)))
    hud._input(_touch(7, false, first + Vector2(75, -12)))
    if not _check(game.get_node_or_null("SafeCamp/CampSkillPreview") != null and is_equal_approx(game.player_mana, mana) and not hud.debug_aim()["guide"], "camp equipped skill release produced no harmless visual"):
        return
    var before_preview := game._camp_root.get_child_count()
    var main := hud.attack_button.get_global_rect().get_center()
    hud._input(_touch(8, true, main))
    hud._input(_touch(8, false, main))
    if not _check(game._camp_root.get_child_count() > before_preview and is_equal_approx(game.player_mana, mana), "default large basic attack is an inert circle"):
        return
    hud._input(_touch(2, false, new_center + Vector2(0, -29)))
    if not _check(hud.joystick_touch_id == -1 and game.move_input == Vector2.ZERO and hud.joystick_center.distance_to(origin) < 0.01, "release did not reset movement and floating pad"):
        return
    var blank := hud.skill_buttons[1].get_global_rect().get_center()
    if not _check(not hud.skill_buttons[1].disabled, "unassigned skills must allow configuring"):
        return
    hud._input(_touch(9, true, blank))
    if not _check(game.armor_ui.is_open() and game._hotbar_page, "tapping empty circle did not open hotbar configuration"):
        return
    game.armor_ui.close()
    game.player.global_position = Vector3(0.0, 0.0, 189.5)
    game._interact_portal()
    if not _check(game.debug_camp_state()["region"] == "combat", "portal did not enter battle"):
        return
    var earlier_mana := float(game.player_mana)
    var earlier_shots := (game.debug_skill_aim()["shots"] as Array).size()
    hud._input(_touch(10, true, first))
    hud._input(_drag(10, first + Vector2(75, -10)))
    hud._input(_touch(10, false, first + Vector2(75, -10)))
    if not _check(game.player_mana < earlier_mana and (game.debug_skill_aim()["shots"] as Array).size() > earlier_shots, "real first skill still cannot cast after portal"):
        return
    finished = true
    print("RIFTFORGED_ARC_TOUCH_OK arc5/independent-circle-targets/floating-reversal/turning/two-finger/camp-basic/gem/empty-editor/combat-cast")
    quit(0)
