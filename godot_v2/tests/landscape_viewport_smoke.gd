extends SceneTree

# Resize regression for short mobile landscape Safari viewports. The public
# browser screenshot showed a cropped bottom edge and hidden action cluster.
var _done := false

func _init() -> void:
    call_deferred("_run")
    call_deferred("_watchdog")

func _watchdog() -> void:
    await create_timer(25.0).timeout
    if not _done:
        push_error("LANDSCAPE_VIEWPORT_FAIL timeout")
        quit(1)

func _check(ok: bool, reason: String) -> bool:
    if not ok:
        _done = true
        push_error("LANDSCAPE_VIEWPORT_FAIL " + reason)
        quit(1)
    return ok

func _within(rect: Rect2, bounds: Rect2, name: String) -> bool:
    return _check(bounds.encloses(rect), "%s outside visible viewport: %s vs %s" % [name, rect, bounds])

func _run() -> void:
    var game := (load("res://main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    await process_frame
    await process_frame
    var hud := game.get_node_or_null("MobileUI") as RiftV5HUD
    if not _check(hud != null and game.has_method("_apply_mobile_landscape_touch_overlay"), "live UI not available"):
        return
    if not _check(game.get_node_or_null("SafeCamp/CampSurroundings") != null, "camp has black side gutters instead of surrounding terrain"):
        return
    hud._test_touch_mode = true
    for screen in [Vector2i(1280, 720), Vector2i(844, 390), Vector2i(932, 430)]:
        root.size = screen
        hud.set_desktop_mode(true)
        hud._layout_desktop(Vector2(screen))
        game.mobile_landscape_enabled = true
        var before := Rect2(hud.attack_button.position, hud.attack_button.size)
        game._apply_mobile_landscape_touch_overlay()
        if not _check(Rect2(hud.attack_button.position, hud.attack_button.size) == before, "legacy overlay moved the primary button after responsive layout"):
            return
        var bounds := Rect2(Vector2.ZERO, Vector2(screen))
        if not _within(before, bounds, "primary") or not _within(Rect2(hud.joystick_back.position, hud.joystick_back.size), bounds, "joystick"):
            return
        if not _check(hud.attack_button.visible and hud.joystick_back.visible and not hud.skill_buttons[4].visible, "mobile primary/joystick representations incorrect"):
            return
        for i in range(4):
            var button := hud.skill_buttons[i]
            var area := Rect2(button.position, button.size)
            if not _within(area, bounds, "skill %d" % (i + 1)):
                return
            if not _check(button.visible and not area.intersects(before), "skill %d hidden or overlaps primary" % (i + 1)):
                return
            for j in range(i + 1, 4):
                if not _check(not area.intersects(Rect2(hud.skill_buttons[j].position, hud.skill_buttons[j].size)), "skills overlap"):
                    return
        if not _within(Rect2(hud.equipment_button.position, hud.equipment_button.size), bounds, "inventory"):
            return
        for i in range(hud.flask_buttons.size()):
            if not _within(Rect2(hud.flask_buttons[i].position, hud.flask_buttons[i].size), bounds, "flask %d" % i):
                return
    _done = true
    print("RIFTFORGED_LANDSCAPE_VIEWPORT_OK short-landscape/primary/four-skills/joystick/inventory/flasks/legacy-overlay/camp-surroundings")
    quit(0)
