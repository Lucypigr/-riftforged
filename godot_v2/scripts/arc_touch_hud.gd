extends "res://scripts/landscape_fit_hud.gd"
class_name RiftArcTouchHUD

# The big circle is configurable hotbar slot five, never a sixth attack.
# Move the joystick's reference when a thumb outruns its short throw, so a
# reversal responds around the CURRENT thumb rather than the original pad.
const STICK_DEAD_ZONE := 3.0
var _stick_home := Vector2.ZERO
var _stick_active := false

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        var touch := event as InputEventScreenTouch
        if touch.pressed and joystick_touch_id == -1 and joystick_back != null and joystick_back.visible:
            if touch.position.distance_to(joystick_center) <= joystick_back.size.x * 0.5 + TOUCH_STICK_PADDING:
                _stick_home = joystick_center
                _stick_active = true
        elif not touch.pressed and touch.index == joystick_touch_id:
            super._input(event)
            _restore_stick_home()
            return
    super._input(event)

func _restore_stick_home() -> void:
    if _stick_active and joystick_back != null:
        joystick_center = _stick_home
        joystick_back.position = _stick_home - joystick_back.size * 0.5
        _set_knob(Vector2.ZERO)
    _stick_active = false

func reset_joystick() -> void:
    super.reset_joystick()
    _restore_stick_home()

func _update_joystick(screen_position: Vector2) -> void:
    if joystick_back == null:
        return
    var throw_radius := clampf(joystick_back.size.x * 0.24, 21.0, 29.0)
    var delta := screen_position - joystick_center
    if _stick_active and delta.length() > throw_radius:
        var desired := screen_position - delta.normalized() * throw_radius
        var bounds := get_viewport().get_visible_rect().size
        var radius := joystick_back.size.x * 0.5
        joystick_center = Vector2(
            clampf(desired.x, radius + 8.0, maxf(radius + 8.0, bounds.x * 0.40)),
            clampf(desired.y, radius + 8.0, maxf(radius + 8.0, bounds.y - radius - 8.0))
        )
        joystick_back.position = joystick_center - joystick_back.size * 0.5
        delta = screen_position - joystick_center
    var distance := delta.length()
    if distance <= STICK_DEAD_ZONE:
        movement = Vector2.ZERO
    else:
        var strength := clampf((distance - STICK_DEAD_ZONE) / (throw_radius - STICK_DEAD_ZONE), 0.0, 1.0)
        movement = delta.normalized() * sqrt(strength)
    movement_changed.emit(movement)
    _set_knob(movement)

func _circle_style(background: Color, edge: Color, diameter: float) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = background
    style.border_color = edge
    style.set_border_width_all(3)
    style.set_corner_radius_all(roundi(diameter * 0.5))
    style.set_content_margin_all(0.0)
    return style

func _paint_circles() -> void:
    if not (_mobile_landscape() or not desktop_mode or _test_touch_mode) or skill_buttons.size() < 5 or attack_button == null:
        return
    # Remove the rectangular panel; the actual Button circles remain live.
    if action_dock != null:
        action_dock.hide()
        action_dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
    for i in range(4):
        var button := skill_buttons[i]
        var diameter := minf(button.size.x, button.size.y)
        button.clip_text = true
        button.text = str(i + 1)
        button.expand_icon = true
        button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
        button.add_theme_font_size_override("font_size", 13)
        button.add_theme_stylebox_override("normal", _circle_style(Color(0.065, 0.09, 0.13, 0.93), Color(0.40, 0.76, 0.96), diameter))
        button.add_theme_stylebox_override("pressed", _circle_style(Color(0.13, 0.35, 0.55), Color(0.81, 0.96, 1.0), diameter))
        button.add_theme_stylebox_override("disabled", _circle_style(Color(0.04, 0.055, 0.07, 0.72), Color(0.19, 0.24, 0.30), diameter))
        # Empty actions are buttons too: tapping opens the hotbar editor.
        if i < _hotbar.size() and _hotbar[i].is_empty() and not _controls_locked:
            button.disabled = false
            button.tooltip_text = "空欄：點擊配置技能"
    attack_button.clip_text = true
    attack_button.add_theme_stylebox_override("normal", _circle_style(Color(0.08, 0.18, 0.35, 0.98), Color(0.57, 0.84, 1.0), attack_button.size.x))
    attack_button.add_theme_stylebox_override("pressed", _circle_style(Color(0.19, 0.42, 0.65), Color(0.91, 0.99, 1.0), attack_button.size.x))
    attack_button.add_theme_stylebox_override("disabled", _circle_style(Color(0.06, 0.075, 0.10), Color(0.28, 0.31, 0.36), attack_button.size.x))

func _layout_desktop(size: Vector2) -> void:
    super._layout_desktop(size)
    if not (_mobile_landscape() or _test_touch_mode) or skill_buttons.size() < 5:
        return
    var small := clampf(size.y * 0.17, 64.0, 72.0)
    var big := clampf(size.y * 0.27, 96.0, 140.0)
    var pad := clampf(size.x * 0.024, 16.0, 29.0)
    var bottom := clampf(size.y * 0.042, 12.0, 27.0)
    attack_button.size = Vector2.ONE * big
    attack_button.position = Vector2(size.x - pad - big, size.y - bottom - big)
    var center := attack_button.position + attack_button.size * 0.5
    # Distinct hit areas arranged in an arc, following the supplied sketch.
    var offsets := [Vector2(-1.30, -2.65), Vector2(-2.48, -1.65), Vector2(-3.66, -0.65), Vector2(-2.51, 0.35)]
    for i in range(4):
        var button := skill_buttons[i]
        button.custom_minimum_size = Vector2.ZERO
        button.size = Vector2.ONE * small
        var target: Vector2 = center + (offsets[i] as Vector2) * small - Vector2.ONE * small * 0.5
        button.position = Vector2(clampf(target.x, 4.0, size.x - small - 4.0), clampf(target.y, 4.0, size.y - small - 4.0))
        button.show()
    mana_orb.position.x = size.x * 0.59
    _paint_circles()

func _layout_mobile_portrait(size: Vector2) -> void:
    super._layout_mobile_portrait(size)
    if skill_buttons.size() >= 5:
        _paint_circles()

func set_hotbar_gems(gems: Array[Dictionary]) -> void:
    super.set_hotbar_gems(gems)
    _paint_circles()

func set_skill_cooldowns(cooldowns: Array[float]) -> void:
    super.set_skill_cooldowns(cooldowns)
    _paint_circles()

func set_mana_state(mana: float) -> void:
    super.set_mana_state(mana)
    _paint_circles()
