extends "res://scripts/gameplay_ui.gd"
class_name RiftDesktopGameplayUI

signal fullscreen_requested
signal flask_requested(slot: int)

const ResourceOrbScript = preload("res://scripts/resource_orb.gd")

var fullscreen_button: Button
var desktop_mode := false
var bottom_hud: Panel
var action_dock: Panel
var life_orb: RiftResourceOrb
var mana_orb: RiftResourceOrb
var basic_attack_slot: Panel
var flask_buttons: Array[Button] = []
var _flask_charges: Array[int] = [3, 3]

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
    _build_arpg_hud(font)
    _layout()

func _build_arpg_hud(font: FontFile) -> void:
    bottom_hud = Panel.new()
    bottom_hud.name = "BottomHudFrame"
    bottom_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
    bottom_hud.z_index = -20
    var hud_style := _round_style(Color(0.025, 0.028, 0.038, 0.95), 18)
    hud_style.border_color = Color(0.40, 0.31, 0.18, 0.82)
    hud_style.border_width_top = 2
    bottom_hud.add_theme_stylebox_override("panel", hud_style)
    root_control.add_child(bottom_hud)
    root_control.move_child(bottom_hud, 0)

    action_dock = Panel.new()
    action_dock.name = "ActionDock"
    action_dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
    action_dock.z_index = -10
    var dock_style := _round_style(Color(0.045, 0.048, 0.060, 0.98), 14)
    dock_style.border_color = Color(0.46, 0.34, 0.18, 0.88)
    dock_style.border_width_left = 2
    dock_style.border_width_top = 2
    dock_style.border_width_right = 2
    dock_style.border_width_bottom = 2
    action_dock.add_theme_stylebox_override("panel", dock_style)
    root_control.add_child(action_dock)

    # The skill buttons are created by the base gameplay UI before the dock.
    # Give them an explicit foreground layer so the dock can never cover them.
    for skill in skill_buttons:
        skill.z_index = 5
        skill.add_theme_color_override("font_color", Color(0.94, 0.90, 0.82))
        skill.add_theme_color_override("font_hover_color", Color.WHITE)
        skill.add_theme_color_override("font_pressed_color", Color.WHITE)
        skill.add_theme_color_override("font_disabled_color", Color(0.62, 0.64, 0.70))

    life_orb = ResourceOrbScript.new() as RiftResourceOrb
    life_orb.name = "LifeOrb"
    life_orb.z_index = 5
    root_control.add_child(life_orb)
    life_orb.setup(font, "生命", Color(0.90, 0.035, 0.055, 1.0))

    mana_orb = ResourceOrbScript.new() as RiftResourceOrb
    mana_orb.name = "ManaOrb"
    mana_orb.z_index = 5
    root_control.add_child(mana_orb)
    mana_orb.setup(font, "魔力", Color(0.035, 0.24, 0.96, 1.0))

    basic_attack_slot = Panel.new()
    basic_attack_slot.name = "BasicAttackSlot"
    basic_attack_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
    basic_attack_slot.z_index = 5
    basic_attack_slot.add_theme_stylebox_override("panel", _round_style(Color(0.18, 0.12, 0.07, 0.96), 12))
    root_control.add_child(basic_attack_slot)
    var attack_label := Label.new()
    attack_label.name = "Label"
    attack_label.text = "左鍵\n基本攻擊"
    attack_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    attack_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    attack_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    attack_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    attack_label.add_theme_font_size_override("font_size", 14)
    attack_label.add_theme_color_override("font_color", Color(0.96, 0.82, 0.56))
    basic_attack_slot.add_child(attack_label)

    var flask_defs := [
        {"name": "生命藥水", "key": "4", "color": Color(0.36, 0.07, 0.08, 0.96)},
        {"name": "魔力藥水", "key": "5", "color": Color(0.05, 0.12, 0.34, 0.96)},
    ]
    for i in range(flask_defs.size()):
        var data: Dictionary = flask_defs[i]
        var flask := Button.new()
        flask.name = "FlaskButton%d" % i
        flask.z_index = 5
        flask.focus_mode = Control.FOCUS_NONE
        flask.add_theme_font_size_override("font_size", 12)
        flask.add_theme_stylebox_override("normal", _round_style(data["color"] as Color, 12))
        flask.add_theme_stylebox_override("pressed", _round_style(Color(0.52, 0.40, 0.20, 0.98), 12))
        flask.pressed.connect(_request_flask.bind(i))
        root_control.add_child(flask)
        flask_buttons.append(flask)
    set_flask_charges(_flask_charges)

func _request_flask(slot: int) -> void:
    flask_requested.emit(slot)

func set_desktop_mode(enabled: bool) -> void:
    desktop_mode = enabled
    _layout()

func _layout() -> void:
    super._layout()
    if root_control == null or equipment_button == null:
        return

    if fullscreen_button != null:
        fullscreen_button.visible = desktop_mode
    if bottom_hud != null:
        bottom_hud.visible = desktop_mode
    if action_dock != null:
        action_dock.visible = desktop_mode
    if life_orb != null:
        life_orb.visible = desktop_mode
    if mana_orb != null:
        mana_orb.visible = desktop_mode
    if basic_attack_slot != null:
        basic_attack_slot.visible = desktop_mode
    for flask in flask_buttons:
        flask.visible = desktop_mode

    if not desktop_mode:
        if joystick_back != null:
            joystick_back.visible = true
        if attack_button != null:
            attack_button.visible = true
        if status_label != null:
            status_label.visible = true
        if hp_bar != null:
            hp_bar.visible = true
        return

    var size := get_viewport().get_visible_rect().size
    if joystick_back != null:
        joystick_back.visible = false
    if attack_button != null:
        attack_button.visible = false
    if status_label != null:
        status_label.visible = false
    if hp_bar != null:
        hp_bar.visible = false

    title_label.position = Vector2(24, 16)
    title_label.size = Vector2(330, 32)
    title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

    weapon_status.position = Vector2(24, 48)
    weapon_status.size = Vector2(minf(520.0, size.x * 0.42), 26)
    weapon_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

    hint_label.position = Vector2(24, 76)
    hint_label.size = Vector2(minf(620.0, size.x * 0.50), 34)
    hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

    gem_button.size = Vector2(82, 42)
    gem_button.position = Vector2(size.x - 96, 16)

    equipment_button.size = Vector2(82, 42)
    equipment_button.position = Vector2(size.x - 188, 16)

    if fullscreen_button != null:
        fullscreen_button.size = Vector2(104, 42)
        fullscreen_button.position = Vector2(size.x - 302, 16)

    var hud_height := 154.0
    bottom_hud.position = Vector2(0, size.y - hud_height)
    bottom_hud.size = Vector2(size.x, hud_height)

    var orb_size := Vector2(138, 138)
    life_orb.size = orb_size
    life_orb.position = Vector2(20, size.y - 145)
    mana_orb.size = orb_size
    mana_orb.position = Vector2(size.x - orb_size.x - 20, size.y - 145)

    var dock_width := minf(560.0, size.x - 430.0)
    action_dock.size = Vector2(dock_width, 108)
    action_dock.position = Vector2((size.x - dock_width) * 0.5, size.y - 116)

    var slot_size := Vector2(80, 78)
    var gap := 10.0
    var total_width := slot_size.x * 4.0 + gap * 3.0
    var start_x := (size.x - total_width) * 0.5
    var slot_y := size.y - 101
    basic_attack_slot.size = slot_size
    basic_attack_slot.position = Vector2(start_x, slot_y)
    for i in range(skill_buttons.size()):
        skill_buttons[i].visible = true
        skill_buttons[i].z_index = 5
        skill_buttons[i].size = slot_size
        skill_buttons[i].position = Vector2(start_x + float(i + 1) * (slot_size.x + gap), slot_y)
        skill_buttons[i].add_theme_stylebox_override("normal", _round_style(Color(0.085, 0.095, 0.135, 0.98), 12))
        skill_buttons[i].add_theme_stylebox_override("hover", _round_style(Color(0.14, 0.17, 0.25, 0.99), 12))
        skill_buttons[i].add_theme_stylebox_override("pressed", _round_style(Color(0.24, 0.30, 0.48, 0.98), 12))
        skill_buttons[i].add_theme_stylebox_override("disabled", _round_style(Color(0.055, 0.060, 0.080, 0.96), 12))

    var flask_size := Vector2(70, 66)
    var flask_x: float = life_orb.position.x + orb_size.x + 18.0
    var flask_y: float = size.y - 86.0
    for i in range(flask_buttons.size()):
        flask_buttons[i].size = flask_size
        flask_buttons[i].position = Vector2(flask_x + float(i) * (flask_size.x + 8.0), flask_y)

    var panel_width := minf(430.0, size.x * 0.42)
    var panel_height := minf(500.0, size.y - 190.0)
    equipment_panel.size = Vector2(panel_width, panel_height)
    equipment_panel.position = Vector2(size.x - panel_width - 24.0, 76.0)

    if gem_panel != null:
        var gem_width := minf(410.0, size.x * 0.40)
        var gem_height := minf(520.0, size.y - 190.0)
        gem_panel.size = Vector2(gem_width, gem_height)
        gem_panel.position = Vector2(size.x - gem_width - 24.0, 76.0)

func set_hp(current: float, maximum: float) -> void:
    super.set_hp(current, maximum)
    if life_orb != null:
        life_orb.set_value(current, maximum)

func set_mana(current: float, maximum: float) -> void:
    if mana_orb != null:
        mana_orb.set_value(current, maximum)

func set_flask_charges(charges: Array[int]) -> void:
    _flask_charges = charges.duplicate()
    var labels := ["生命藥水", "魔力藥水"]
    var keys := ["4", "5"]
    for i in range(mini(flask_buttons.size(), _flask_charges.size())):
        flask_buttons[i].text = "%s\n%s ×%d" % [keys[i], labels[i], _flask_charges[i]]
        flask_buttons[i].disabled = _flask_charges[i] <= 0
