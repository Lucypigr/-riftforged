extends "res://scripts/unified_inventory_hud.gd"
class_name RiftMobileLandscapeHUD

# The desktop profile is 1280x720 logical pixels even on an 844px-wide phone.
# The regular 42px toolbar buttons become too small after canvas scaling.
func _layout_desktop(size: Vector2) -> void:
    super._layout_desktop(size)
    if not _mobile_landscape():
        return
    _layout_touch_landscape(size)

func _mobile_landscape() -> bool:
    var viewport_size := get_viewport().get_visible_rect().size
    return viewport_size.x > viewport_size.y and (DisplayServer.is_touchscreen_available() or OS.has_feature("web_ios") or OS.has_feature("web_android") or OS.has_feature("ios") or OS.has_feature("android"))

func _layout_touch_landscape(size: Vector2) -> void:
    # Use physical-friendly hit areas and a dedicated row, away from the
    # left joystick and the right basic-attack button.
    var toolbar_width := 150.0
    var toolbar_height := 75.0
    equipment_button.size = Vector2(toolbar_width, toolbar_height)
    equipment_button.position = Vector2(size.x - 326.0, 9.0)
    equipment_button.add_theme_font_size_override("font_size", 21)
    gem_button.size = Vector2(toolbar_width, toolbar_height)
    gem_button.position = Vector2(size.x - 166.0, 9.0)
    gem_button.add_theme_font_size_override("font_size", 21)
    if fullscreen_button != null:
        fullscreen_button.hide()
    if basic_attack_slot != null:
        basic_attack_slot.hide()
    var button_width := 111.0
    var button_height := 100.0
    var gap := 9.0
    var total := 5.0 * button_width + 4.0 * gap
    var start_x := maxf(155.0, (size.x - total) * 0.5 - 18.0)
    var row_y := size.y - 232.0
    for i in range(skill_buttons.size()):
        var skill := skill_buttons[i]
        skill.size = Vector2(button_width, button_height)
        skill.position = Vector2(start_x + float(i) * (button_width + gap), row_y)
        skill.add_theme_font_size_override("font_size", 17)
    if action_dock != null:
        action_dock.position = Vector2(start_x - 11.0, row_y - 10.0)
        action_dock.size = Vector2(total + 22.0, button_height + 20.0)
    for i in range(flask_buttons.size()):
        var flask := flask_buttons[i]
        flask.size = Vector2(88, 85)
        flask.position = Vector2(size.x - 280.0 + float(i) * 93.0, size.y - 104.0)
        flask.add_theme_font_size_override("font_size", 13)
    if hint_label != null:
        hint_label.size.x = maxf(300.0, size.x - 365.0)
    if weapon_status != null:
        weapon_status.size.x = maxf(300.0, size.x - 365.0)

func debug_touch_landscape_hud() -> Dictionary:
    return {"touch":_mobile_landscape(), "equipment_size":equipment_button.size if equipment_button != null else Vector2.ZERO, "gem_size":gem_button.size if gem_button != null else Vector2.ZERO, "skill_size":skill_buttons[0].size if not skill_buttons.is_empty() else Vector2.ZERO}
