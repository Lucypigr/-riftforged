extends "res://scripts/v4_hud.gd"
class_name RiftV5HUD

const GemRules = preload("res://scripts/linked_gem_system.gd")
const TOUCH_STICK_PADDING := 18.0

var _controls_locked := false
var _available_mana := 100.0
var _test_touch_mode := false

func setup(font: FontFile) -> void:
    super.setup(font)
    # The old gem button also opened an unrelated demo panel. The live game
    # connects its real gem action after UI.setup(), so remove demo callbacks.
    for connection in gem_button.pressed.get_connections():
        gem_button.pressed.disconnect(connection["callable"])
    attack_button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
    attack_button.text = "普攻"
    attack_button.add_theme_stylebox_override("normal", _forged_style(Color(0.48, 0.11, 0.12, 0.99), Color(0.98, 0.67, 0.32), 55, 3))
    attack_button.add_theme_stylebox_override("pressed", _forged_style(Color(0.87, 0.23, 0.17, 1.0), Color(1.0, 0.95, 0.63), 55, 4))
    attack_button.add_theme_stylebox_override("disabled", _forged_style(Color(0.12, 0.11, 0.12), Color(0.27, 0.23, 0.22), 55, 2))
    set_mana_state(_available_mana)
    _layout()

func _touch_runtime() -> bool:
    return _test_touch_mode or DisplayServer.is_touchscreen_available() or OS.has_feature("mobile") or OS.has_feature("ios") or OS.has_feature("android") or OS.has_feature("web_ios") or OS.has_feature("web_android")

func set_controls_locked(locked: bool) -> void:
    _controls_locked = locked
    reset_joystick()
    attack_button.disabled = locked
    for button in skill_buttons:
        button.disabled = locked
    for button in flask_buttons:
        button.disabled = locked
    if not locked:
        set_skill_cooldowns([])
        set_flask_charges(_flask_charges)

func reset_joystick() -> void:
    joystick_touch_id = -1
    movement = Vector2.ZERO
    movement_changed.emit(Vector2.ZERO)
    _set_knob(Vector2.ZERO)

func _input(event: InputEvent) -> void:
    # Do not use the legacy 'left 55% of the bottom half' hit test: it captures
    # inventory/flask taps and may mint a synthetic mouse held-attack on Web.
    if _controls_locked:
        if event is InputEventScreenTouch and not (event as InputEventScreenTouch).pressed:
            if (event as InputEventScreenTouch).index == joystick_touch_id:
                reset_joystick()
                get_viewport().set_input_as_handled()
        return
    if event is InputEventScreenTouch:
        var touch := event as InputEventScreenTouch
        if touch.pressed:
            if joystick_touch_id != -1 or joystick_back == null or not joystick_back.visible:
                return
            var radius := joystick_back.size.x * 0.5 + TOUCH_STICK_PADDING
            if touch.position.distance_to(joystick_center) <= radius:
                joystick_touch_id = touch.index
                _update_joystick(touch.position)
                get_viewport().set_input_as_handled()
        elif touch.index == joystick_touch_id:
            reset_joystick()
            get_viewport().set_input_as_handled()
    elif event is InputEventScreenDrag:
        var drag := event as InputEventScreenDrag
        if drag.index == joystick_touch_id and joystick_touch_id >= 0:
            _update_joystick(drag.position)
            get_viewport().set_input_as_handled()

func _layout_mobile_portrait(size: Vector2) -> void:
    super._layout_mobile_portrait(size)
    if joystick_back == null or attack_button == null:
        return
    var safe := 12.0
    var stick := clampf(size.x * 0.29, 99.0, 124.0)
    joystick_back.size = Vector2.ONE * stick
    joystick_back.position = Vector2(safe, size.y - stick - safe - 8.0)
    joystick_center = joystick_back.position + joystick_back.size * 0.5
    _set_knob(movement)
    var attack := clampf(size.x * 0.27, 88.0, 112.0)
    attack_button.size = Vector2.ONE * attack
    attack_button.position = Vector2(size.x - attack - safe, size.y - attack - safe - 8.0)
    attack_button.add_theme_font_size_override("font_size", 20)
    equipment_button.text = "背包"
    equipment_button.position = Vector2(size.x - 94.0, 12.0)
    equipment_button.size = Vector2(82.0, 42.0)
    gem_button.hide()
    var small := clampf(size.x * 0.142, 43.0, 59.0)
    var gap := clampf(size.x * 0.016, 5.0, 8.0)
    var right := size.x - 12.0
    var top_y := size.y - attack - 2.0 * small - gap - 31.0
    var row_width := small * 3.0 + gap * 2.0
    var start_x := right - row_width
    for i in range(skill_buttons.size()):
        var col := i if i < 3 else i - 3
        var row := 0 if i < 3 else 1
        var indent := 0.0 if row == 0 else (small + gap) * 0.45
        var button := skill_buttons[i]
        button.size = Vector2.ONE * small
        button.position = Vector2(start_x + indent + float(col) * (small + gap), top_y + float(row) * (small + gap))
        button.add_theme_font_size_override("font_size", 11)
    action_dock.position = Vector2(maxf(stick + 13.0, start_x - 7.0), top_y - 7.0)
    action_dock.size = Vector2(minf(size.x - action_dock.position.x - 6.0, row_width + 15.0), 2.0 * small + gap + 15.0)
    var flask_width := clampf(size.x * 0.125, 43.0, 54.0)
    var flask_y := size.y - flask_width - safe - 5.0
    var between := (attack_button.position.x - (joystick_back.position.x + stick))
    var flask_start := joystick_back.position.x + stick + maxf(3.0, (between - 2.0 * flask_width - 6.0) * 0.5)
    for i in range(flask_buttons.size()):
        var flask := flask_buttons[i]
        flask.show()
        flask.size = Vector2(flask_width, flask_width)
        flask.position = Vector2(flask_start + float(i) * (flask_width + 5.0), flask_y)
        flask.add_theme_font_size_override("font_size", 10)
    var orb_size := clampf(size.x * 0.12, 40.0, 49.0)
    life_orb.size = Vector2.ONE * orb_size
    mana_orb.size = Vector2.ONE * orb_size
    life_orb.position = Vector2(stick + safe + 1.0, size.y - attack - orb_size - 17.0)
    mana_orb.position = Vector2(life_orb.position.x + orb_size + 8.0, life_orb.position.y)
    bottom_hud.position = Vector2(0.0, size.y - attack - 2.0 * small - gap - 47.0)
    bottom_hud.size = Vector2(size.x, size.y - bottom_hud.position.y)
    _apply_skill_frame_styles(true)

func _layout_desktop(size: Vector2) -> void:
    super._layout_desktop(size)
    if not _mobile_landscape() and not _test_touch_mode:
        return
    var scale_factor := clampf(size.y / 720.0, 0.72, 1.30)
    var stick := 133.0 * scale_factor
    joystick_back.show()
    joystick_back.size = Vector2.ONE * stick
    joystick_back.position = Vector2(16.0, size.y - stick - 20.0)
    joystick_center = joystick_back.position + joystick_back.size * 0.5
    _set_knob(movement)
    var attack := 116.0 * scale_factor
    attack_button.show()
    attack_button.size = Vector2.ONE * attack
    attack_button.position = Vector2(size.x - attack - 22.0, size.y - attack - 24.0)
    attack_button.add_theme_font_size_override("font_size", 23)
    equipment_button.text = "背包"
    equipment_button.position = Vector2(size.x - 167.0, 12.0)
    equipment_button.size = Vector2(145.0, 66.0)
    gem_button.hide()
    if basic_attack_slot != null:
        basic_attack_slot.hide()
    var small := 69.0 * scale_factor
    var gap := 11.0 * scale_factor
    var origin_x := attack_button.position.x - 3.0 * (small + gap) - 15.0
    var origin_y := attack_button.position.y - small - 30.0 * scale_factor
    var offsets := [Vector2(0, 1), Vector2(1, 0), Vector2(2, 0), Vector2(1, 1), Vector2(2, 1)]
    for i in range(skill_buttons.size()):
        var offset: Vector2 = offsets[i]
        skill_buttons[i].size = Vector2.ONE * small
        skill_buttons[i].position = Vector2(origin_x + offset.x * (small + gap), origin_y + offset.y * (small + gap))
        skill_buttons[i].add_theme_font_size_override("font_size", 12)
    action_dock.position = Vector2(origin_x - 8.0, origin_y - 8.0)
    action_dock.size = Vector2(3.0 * small + 2.0 * gap + 16.0, 2.0 * small + gap + 16.0)
    for i in range(flask_buttons.size()):
        var flask := flask_buttons[i]
        flask.show()
        flask.size = Vector2(73.0 * scale_factor, 72.0 * scale_factor)
        flask.position = Vector2(size.x * 0.43 + float(i) * (80.0 * scale_factor), size.y - 84.0 * scale_factor)
    life_orb.size = Vector2.ONE * (76.0 * scale_factor)
    mana_orb.size = Vector2.ONE * (76.0 * scale_factor)
    life_orb.position = Vector2(size.x * 0.27, size.y - 83.0 * scale_factor)
    mana_orb.position = Vector2(size.x * 0.64, size.y - 83.0 * scale_factor)
    _apply_skill_frame_styles(true)

func set_hotbar_gems(gems: Array[Dictionary]) -> void:
    super.set_hotbar_gems(gems)
    set_mana_state(_available_mana)

func set_skill_cooldowns(cooldowns: Array[float]) -> void:
    super.set_skill_cooldowns(cooldowns)
    set_mana_state(_available_mana)

func set_mana_state(mana: float) -> void:
    _available_mana = mana
    for i in range(skill_buttons.size()):
        var enabled := i < _hotbar.size() and not _hotbar[i].is_empty()
        var needed := 0.0
        if enabled:
            var entry: Dictionary = _hotbar[i]
            var gear: Dictionary = entry.get("equipment", {})
            var socket_index := int(entry.get("socket_index", -1))
            if socket_index >= 0 and socket_index < (gear.get("sockets", []) as Array).size():
                needed = GemRules.skill_mana(gear, socket_index)
            else:
                needed = float((entry.get("info", {}) as Dictionary).get("mana", 0.0))
        var insufficient := enabled and mana + 0.001 < needed
        skill_buttons[i].disabled = _controls_locked or not enabled or insufficient
        skill_buttons[i].tooltip_text = "魔力不足：需要 %.0f" % needed if insufficient else (String((_hotbar[i].get("gem", {}) as Dictionary).get("name", "")) if enabled else "空技能欄")
        skill_buttons[i].modulate = Color(0.52, 0.56, 0.64) if insufficient else Color.WHITE

func debug_v5_controls() -> Dictionary:
    var placements: Array[Rect2] = []
    for button in skill_buttons:
        placements.append(Rect2(button.position, button.size))
    return {"joystick_touch_id":joystick_touch_id, "moving":movement, "locked":_controls_locked, "skills":placements, "attack":Rect2(attack_button.position, attack_button.size), "flasks_visible":flask_buttons[0].visible if not flask_buttons.is_empty() else false}
