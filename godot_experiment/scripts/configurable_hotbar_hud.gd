extends "res://scripts/v5_hud.gd"
class_name RiftConfigurableHotbarHUD

# The large thumb button is slot 5, not an independent sixth attack action.
func setup(font: FontFile) -> void:
    super.setup(font)
    for connection in attack_button.pressed.get_connections():
        attack_button.pressed.disconnect(connection["callable"])
    attack_button.pressed.connect(func(): skill_requested.emit(4))
    attack_button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
    _render_primary()

func _primary_on_touch() -> bool:
    return not desktop_mode or _mobile_landscape() or _test_touch_mode

func _layout_mobile_portrait(size: Vector2) -> void:
    super._layout_mobile_portrait(size)
    # Ancestor setup lays out three buttons before adding buttons 4 and 5.
    if attack_button == null or joystick_back == null or skill_buttons.size() < 5:
        return
    var small := clampf(size.x * 0.145, 44.0, 60.0)
    var gap := clampf(size.x * 0.018, 6.0, 9.0)
    var x := maxf(joystick_back.position.x + joystick_back.size.x + 7.0, attack_button.position.x - small * 2.0 - gap - 7.0)
    var y := maxf(110.0, attack_button.position.y - small * 2.0 - gap - 20.0)
    for i in range(4):
        skill_buttons[i].size = Vector2.ONE * small
        skill_buttons[i].position = Vector2(x + float(i % 2) * (small + gap), y + float(i / 2) * (small + gap))
        skill_buttons[i].add_theme_font_size_override("font_size", 11)
    action_dock.position = Vector2(x - 6.0, y - 6.0)
    action_dock.size = Vector2(2.0 * small + gap + 12.0, 2.0 * small + gap + 12.0)
    _render_primary()

func _layout_desktop(size: Vector2) -> void:
    super._layout_desktop(size)
    if basic_attack_slot != null:
        basic_attack_slot.hide()
    _render_primary()

func set_hotbar_gems(gems: Array[Dictionary]) -> void:
    # Older code requires a gem key even on empty slots. Hide the internal
    # placeholder from all button enablement/mana logic.
    var visible_entries: Array[Dictionary] = []
    for entry in gems:
        visible_entries.append({} if String(entry.get("kind", "")) == "empty" else entry)
    super.set_hotbar_gems(visible_entries)
    _render_primary()

func set_skill_cooldowns(cooldowns: Array[float]) -> void:
    super.set_skill_cooldowns(cooldowns)
    _render_primary()

func set_mana_state(mana: float) -> void:
    super.set_mana_state(mana)
    _render_primary()

func set_controls_locked(locked: bool) -> void:
    super.set_controls_locked(locked)
    _render_primary()

func _render_primary() -> void:
    if attack_button == null or skill_buttons.size() < 5:
        return
    var touch := _primary_on_touch()
    var entry: Dictionary = _hotbar[4] if _hotbar.size() > 4 else {}
    var basic := String(entry.get("kind", "")) == "basic"
    var gem: Dictionary = entry.get("gem", {})
    var active := not entry.is_empty()
    var name := "普攻" if basic else String(gem.get("name", "空欄"))
    skill_buttons[4].icon = BASIC_ICON if basic else skill_buttons[4].icon
    skill_buttons[4].text = "5\n%s" % name
    skill_buttons[4].tooltip_text = name
    # Always keep both representations in sync, even while the desktop
    # version is hidden. Rotation then cannot revive a stale attack label.
    attack_button.icon = BASIC_ICON if basic else skill_buttons[4].icon
    attack_button.expand_icon = true
    attack_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
    attack_button.text = "5\n%s" % name
    attack_button.tooltip_text = name
    attack_button.disabled = _controls_locked or not active or skill_buttons[4].disabled
    attack_button.modulate = skill_buttons[4].modulate
    skill_buttons[4].visible = not touch
    attack_button.visible = touch

func debug_primary_slot() -> Dictionary:
    return {"primary_visible":attack_button.visible, "slot_five_visible":skill_buttons[4].visible, "primary_text":attack_button.text, "primary_disabled":attack_button.disabled, "primary_position":attack_button.position, "primary_size":attack_button.size}
