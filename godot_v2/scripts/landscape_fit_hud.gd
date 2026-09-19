extends "res://scripts/skill_aim_hud.gd"
class_name RiftLandscapeFitHUD

# The original landscape layout assumed a 720px-high desktop canvas. On iOS
# Safari the dynamic browser toolbar can leave a much shorter visible canvas.
# Keep the four secondary skills and slot-five primary in one bottom-right
# cluster, entirely inside the CURRENT viewport rather than a cached size.
func _layout_desktop(size: Vector2) -> void:
    super._layout_desktop(size)
    if not (_mobile_landscape() or _test_touch_mode):
        return
    if attack_button == null or joystick_back == null or skill_buttons.size() < 5:
        return
    var scale := minf(clampf(size.y / 720.0, 0.62, 1.16), clampf(size.x / 1280.0, 0.66, 1.20))
    var safe_x := clampf(size.x * 0.025, 18.0, 32.0)
    var safe_bottom := clampf(size.y * 0.045, 18.0, 30.0)
    var bottom := size.y - safe_bottom
    var primary := clampf(116.0 * scale, 74.0, 135.0)
    var small := clampf(69.0 * scale, 44.0, 80.0)
    var gap := clampf(11.0 * scale, 7.0, 13.0)
    var cluster_gap := clampf(18.0 * scale, 12.0, 20.0)
    attack_button.size = Vector2.ONE * primary
    attack_button.position = Vector2(size.x - safe_x - primary, bottom - primary)
    attack_button.add_theme_font_size_override("font_size", roundi(clampf(21.0 * scale, 12.0, 23.0)))
    var skills_x := attack_button.position.x - 2.0 * small - gap - cluster_gap
    var skills_y := attack_button.position.y - 2.0 * small - gap - cluster_gap
    for i in range(4):
        var button := skill_buttons[i]
        var column := i % 2
        var row := floori(float(i) / 2.0)
        button.size = Vector2.ONE * small
        button.position = Vector2(skills_x + float(column) * (small + gap), skills_y + float(row) * (small + gap))
        button.add_theme_font_size_override("font_size", roundi(clampf(12.0 * scale, 10.0, 14.0)))
        button.show()
    action_dock.position = Vector2(skills_x - 8.0 * scale, skills_y - 8.0 * scale)
    action_dock.size = Vector2(2.0 * small + gap + 16.0 * scale, 2.0 * small + gap + 16.0 * scale)
    var stick := clampf(133.0 * scale, 86.0, 151.0)
    joystick_back.size = Vector2.ONE * stick
    joystick_back.position = Vector2(safe_x, bottom - stick)
    joystick_back.show()
    joystick_center = joystick_back.position + joystick_back.size * 0.5
    _set_knob(movement)
    var flask_size := clampf(72.0 * scale, 43.0, 79.0)
    for i in range(flask_buttons.size()):
        flask_buttons[i].size = Vector2.ONE * flask_size
        flask_buttons[i].position = Vector2(size.x * 0.43 + float(i) * (flask_size + 9.0 * scale), bottom - flask_size)
        flask_buttons[i].show()
    var orb := clampf(76.0 * scale, 44.0, 88.0)
    life_orb.size = Vector2.ONE * orb
    mana_orb.size = Vector2.ONE * orb
    life_orb.position = Vector2(size.x * 0.27, bottom - orb)
    mana_orb.position = Vector2(size.x * 0.64, bottom - orb)
    var bag_width := clampf(145.0 * scale, 92.0, 166.0)
    var bag_height := clampf(66.0 * scale, 43.0, 72.0)
    equipment_button.text = "背包"
    equipment_button.size = Vector2(bag_width, bag_height)
    equipment_button.position = Vector2(size.x - safe_x - bag_width, 12.0)
    gem_button.hide()
    if fullscreen_button != null:
        fullscreen_button.hide()
    if basic_attack_slot != null:
        basic_attack_slot.hide()
    # Do not waste the bottom of a short mobile screen on a desktop-only bar.
    bottom_hud.hide()
    _apply_skill_frame_styles(true)
    _render_primary()
