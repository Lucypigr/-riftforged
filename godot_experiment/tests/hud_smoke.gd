extends SceneTree

# Regression guard for the Web/Compatibility HUD and real five-key controls.
func _fail(message: String) -> void:
    push_error(message)
    quit(1)

func _init() -> void:
    call_deferred("_run")

func _press_key(game: Node, keycode: Key) -> void:
    var event := InputEventKey.new()
    event.keycode = keycode
    event.pressed = true
    game.call("_unhandled_input", event)

func _run() -> void:
    var packed := load("res://main.tscn") as PackedScene
    if packed == null:
        _fail("Main game scene missing")
        return
    var game := packed.instantiate()
    root.add_child(game)
    await process_frame
    await process_frame
    var ui := game.get_node_or_null("MobileUI") as RiftPoEInventoryUI
    var root_ui := game.get_node_or_null("MobileUI/Root") as Control
    if ui == null or root_ui == null:
        _fail("POE-style HUD not installed in actual game")
        return
    var life := root_ui.get_node_or_null("LifeOrb") as Control
    var mana := root_ui.get_node_or_null("ManaOrb") as Control
    var bottom := root_ui.get_node_or_null("BottomHudFrame") as Panel
    var dock := root_ui.get_node_or_null("ActionDock") as Panel
    var basic := root_ui.get_node_or_null("BasicAttackSlot") as Panel
    var flasks: Array[Button] = []
    for i in range(2):
        var flask := root_ui.get_node_or_null("FlaskButton%d" % i) as Button
        if flask == null:
            _fail("Missing flask control %d" % i)
            return
        flasks.append(flask)
    if life == null or mana == null or bottom == null or dock == null or basic == null or not life.visible or not mana.visible or not bottom.visible or not dock.visible:
        _fail("ARPG resource orbs, basic slot or HUD frame missing")
        return
    var life_color: Color = life.call("debug_liquid_color")
    var mana_color: Color = mana.call("debug_liquid_color")
    if life_color.r < 0.80 or life_color.g > 0.15 or mana_color.b < 0.80 or mana_color.r > 0.15:
        _fail("Life and mana liquid colours regressed")
        return
    if String(life.call("debug_render_mode")) != "canvas_draw" or String(mana.call("debug_render_mode")) != "canvas_draw":
        _fail("Web/Compatibility resource orbs depend on unreliable shader")
        return
    var hotbar: Dictionary = game.call("debug_hotbar_state")
    var ids: Array = hotbar.get("ids", [])
    if ids != ["ember_bolt", "", "", "", ""] or hotbar.get("basic_attack", "") != "left_click":
        _fail("Only an installed active gem may occupy initial 1–5 slots")
        return
    for i in range(5):
        var skill := root_ui.get_node_or_null("SkillButton%d" % i) as Button
        if skill == null or not skill.visible or skill.z_index <= dock.z_index or not skill.text.contains(str(i + 1)):
            _fail("Skill shortcut %d is not visible above HUD" % (i + 1))
            return
        if i > 0 and (not skill.disabled or skill.icon != null):
            _fail("Uninstalled skill displays an icon or remains clickable")
            return
    var width := get_root().get_visible_rect().size.x
    if life.position.x >= width * 0.5 or mana.position.x <= width * 0.5:
        _fail("Life/mana orbs do not occupy opposite sides")
        return
    if not flasks[0].text.begins_with("Q") or not flasks[1].text.begins_with("E"):
        _fail("Flask labels collide with skill keys 4 and 5")
        return

    var state: Dictionary = game.call("debug_resource_state")
    if float(state.get("max_mana", 0.0)) < 100.0 or float(state.get("mana_regen", 0.0)) <= 0.0:
        _fail("Mana regeneration unavailable")
        return
    game.call("debug_set_mana", 100.0)
    var before_skill := float((game.call("debug_resource_state") as Dictionary).get("mana", 0.0))
    _press_key(game, KEY_1)
    await process_frame
    var after_skill := float((game.call("debug_resource_state") as Dictionary).get("mana", 0.0))
    if after_skill >= before_skill or float((game.call("debug_skill_cooldowns") as Array)[0]) <= 0.0:
        _fail("Hotkey 1 failed to cast socketed fireball or spend mana")
        return
    var charges_before: Array = (game.call("debug_resource_state") as Dictionary).get("flask_charges", [])
    _press_key(game, KEY_4)
    _press_key(game, KEY_5)
    var charges_after: Array = (game.call("debug_resource_state") as Dictionary).get("flask_charges", [])
    if charges_before != charges_after:
        _fail("Empty skill keys 4/5 incorrectly consumed flasks")
        return
    if float((game.call("debug_skill_cooldowns") as Array)[3]) > 0.0 or float((game.call("debug_skill_cooldowns") as Array)[4]) > 0.0:
        _fail("Empty skill keys unexpectedly started cooldowns")
        return

    game.call("debug_set_mana", 20.0)
    var mana_before := float((game.call("debug_resource_state") as Dictionary).get("mana", 0.0))
    _press_key(game, KEY_E)
    var mana_after := float((game.call("debug_resource_state") as Dictionary).get("mana", 0.0))
    if mana_after <= mana_before or int(((game.call("debug_resource_state") as Dictionary).get("flask_charges", []) as Array)[1]) != int(charges_before[1]) - 1:
        _fail("E did not use the mana flask")
        return
    game.call("debug_set_hp", 40.0)
    var hp_before := float((game.call("debug_resource_state") as Dictionary).get("hp", 0.0))
    _press_key(game, KEY_Q)
    var hp_after := float((game.call("debug_resource_state") as Dictionary).get("hp", 0.0))
    if hp_after <= hp_before or not flasks[0].text.contains("生命藥水") or not flasks[1].text.contains("魔力藥水"):
        _fail("Q did not use life flask or potion labels regressed")
        return
    print("RIFTFORGED_HUD_SMOKE_OK orbs/left-basic/gem-only-1-to-5/Q-E-flasks ready")
    quit(0)
