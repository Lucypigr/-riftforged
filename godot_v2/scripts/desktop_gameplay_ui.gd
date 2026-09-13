extends "res://scripts/gameplay_ui.gd"
class_name RiftDesktopGameplayUI

signal fullscreen_requested

var fullscreen_button: Button
var desktop_mode := false

func setup(font: FontFile) -> void:
    super.setup(font)
    fullscreen_button = Button.new()
    fullscreen_button.name = "FullscreenButton"
    fullscreen_button.text = "全螢幕"
    fullscreen_button.focus_mode = Control.FOCUS_NONE
    fullscreen_button.add_theme_font_size_override("font_size", 15)
    fullscreen_button.add_theme_stylebox_override("normal", _round_style(Color(0.07, 0.09, 0.13, 0.94), 14))
    fullscreen_button.add_theme_stylebox_override("pressed", _round_style(Color(0.18, 0.24, 0.34, 0.98), 14))
    fullscreen_button.pressed.connect(func(): fullscreen_requested.emit())
    root_control.add_child(fullscreen_button)
    _layout()

func set_desktop_mode(enabled: bool) -> void:
    desktop_mode = enabled
    _layout()

func _layout() -> void:
    super._layout()
    if root_control == null or equipment_button == null:
        return

    if fullscreen_button != null:
        fullscreen_button.visible = desktop_mode
    if not desktop_mode:
        if joystick_back != null:
            joystick_back.visible = true
        if attack_button != null:
            attack_button.visible = true
        return

    var size := get_viewport().get_visible_rect().size
    if joystick_back != null:
        joystick_back.visible = false
    if attack_button != null:
        attack_button.visible = false

    title_label.position = Vector2(24, 16)
    title_label.size = Vector2(330, 32)
    title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

    status_label.position = Vector2(24, 50)
    status_label.size = Vector2(300, 24)
    status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

    hp_bar.position = Vector2(24, 80)
    hp_bar.size = Vector2(300, 16)

    weapon_status.position = Vector2(352, 20)
    weapon_status.size = Vector2(maxf(280.0, size.x - 720.0), 26)
    weapon_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

    hint_label.position = Vector2(352, 52)
    hint_label.size = Vector2(maxf(300.0, size.x - 720.0), 34)
    hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

    gem_button.size = Vector2(82, 42)
    gem_button.position = Vector2(size.x - 96, 16)

    equipment_button.size = Vector2(82, 42)
    equipment_button.position = Vector2(size.x - 188, 16)

    if fullscreen_button != null:
        fullscreen_button.size = Vector2(104, 42)
        fullscreen_button.position = Vector2(size.x - 302, 16)

    var skill_size := Vector2(88, 72)
    var gap := 12.0
    var total_width := skill_size.x * 3.0 + gap * 2.0
    var start_x := (size.x - total_width) * 0.5
    var skill_y := size.y - 92
    for i in range(skill_buttons.size()):
        skill_buttons[i].size = skill_size
        skill_buttons[i].position = Vector2(start_x + float(i) * (skill_size.x + gap), skill_y)

    var panel_width := minf(430.0, size.x * 0.42)
    var panel_height := minf(500.0, size.y - 116.0)
    equipment_panel.size = Vector2(panel_width, panel_height)
    equipment_panel.position = Vector2(size.x - panel_width - 24.0, 76.0)

    if gem_panel != null:
        var gem_width := minf(410.0, size.x * 0.40)
        var gem_height := minf(520.0, size.y - 116.0)
        gem_panel.size = Vector2(gem_width, gem_height)
        gem_panel.position = Vector2(size.x - gem_width - 24.0, 76.0)
