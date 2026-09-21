extends "res://scripts/app_unified_inventory.gd"

const PictureUI = preload("res://scripts/mobile_equipment_ui.gd")
const TouchHUD = preload("res://scripts/mobile_landscape_hud.gd")
var _next_equipment_uid := 1000000

func _build_ui() -> void:
    ui = TouchHUD.new()
    ui.name = "MobileUI"
    add_child(ui)
    ui.setup(ui_font)
    ui.movement_changed.connect(func(value: Vector2): move_input = value)
    ui.attack_requested.connect(_attack)
    var hud := ui as RiftMobileLandscapeHUD
    hud.skill_requested.connect(_use_skill)
    hud.weapon_equip_requested.connect(_equip_weapon_index)
    hud.fullscreen_requested.connect(_toggle_fullscreen)
    hud.set_desktop_mode(desktop_layout_enabled)
    ui.set_hp(player_hp, player_max_hp)
    _apply_runtime_hint()

func _ready() -> void:
    super._ready()
    if armor_ui == null:
        return
    var first_layout := armor_ui
    remove_child(first_layout)
    first_layout.queue_free()
    armor_ui = PictureUI.new() as RiftMobileEquipmentUI
    armor_ui.name = "ArmorEquipment"
    add_child(armor_ui)
    armor_ui.setup(ui_font)
    armor_ui.edit_requested.connect(_open_equipment_sockets)
    armor_ui.equip_requested.connect(_equip_armor)
    (armor_ui as RiftMobileEquipmentUI).weapon_equip_requested.connect(_equip_weapon_index)
    armor_ui.closed.connect(_on_equipment_closed)
    _refresh_gameplay_ui()

func _apply_mobile_landscape_touch_overlay() -> void:
    super._apply_mobile_landscape_touch_overlay()
    if not mobile_landscape_enabled or ui == null:
        return
    var screen := get_viewport().get_visible_rect().size
    if ui.joystick_back != null:
        ui.joystick_back.size = Vector2(142, 142)
        ui.joystick_back.position = Vector2(16, maxf(105.0, screen.y - 288.0))
        ui.joystick_center = ui.joystick_back.position + ui.joystick_back.size * 0.5
        ui.call("_set_knob", ui.movement)
    if ui.attack_button != null:
        ui.attack_button.size = Vector2(142, 142)
        ui.attack_button.position = Vector2(screen.x - 158.0, maxf(110.0, screen.y - 290.0))
        ui.attack_button.add_theme_font_size_override("font_size", 23)

func _refresh_gameplay_ui() -> void:
    # Indices shift when a worn armor item is exchanged; a persistent physical
    # identity prevents a highlighted card from equipping a different item.
    _ensure_equipment_identity()
    super._refresh_gameplay_ui()

func _ensure_equipment_identity() -> void:
    var seen := {}
    for i in range(weapon_inventory.size()):
        var weapon := weapon_inventory[i].duplicate(true)
        var uid := int(weapon.get("instance_uid", 0))
        if uid <= 0 or seen.has(uid):
            _next_equipment_uid += 1
            uid = _next_equipment_uid
            weapon["instance_uid"] = uid
            weapon_inventory[i] = weapon
        seen[uid] = true
    for i in range(armor_inventory.size()):
        var armor := armor_inventory[i].duplicate(true)
        var uid := int(armor.get("instance_uid", 0))
        if uid <= 0 or seen.has(uid):
            _next_equipment_uid += 1
            uid = _next_equipment_uid
            armor["instance_uid"] = uid
            armor_inventory[i] = armor
        seen[uid] = true
    for slot in ArmorSystem.SLOTS:
        if not equipped_armor.has(slot):
            continue
        var gear: Dictionary = (equipped_armor[slot] as Dictionary).duplicate(true)
        var uid := int(gear.get("instance_uid", 0))
        if uid <= 0 or seen.has(uid):
            _next_equipment_uid += 1
            uid = _next_equipment_uid
            gear["instance_uid"] = uid
            equipped_armor[slot] = gear
        seen[uid] = true
    if _equipped_weapon_index >= 0 and _equipped_weapon_index < weapon_inventory.size():
        equipped_weapon["instance_uid"] = int(weapon_inventory[_equipped_weapon_index].get("instance_uid", 0))
