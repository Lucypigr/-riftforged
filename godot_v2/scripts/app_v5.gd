extends "res://scripts/app_v4_integrity.gd"

const V5HUDScript = preload("res://scripts/v5_hud.gd")
const V5GearScript = preload("res://scripts/v5_equipment_ui.gd")
const V5GemScript = preload("res://scripts/v5_gem_ui.gd")

# Only the input/UI shell changes. All real equipment, gem, loot, currency,
# combat, boss and V4 progression state remains in the existing ancestors.
var _v5_target_kind := ""
var _v5_target_uid := 0
var _v5_force_mobile := false # Used exclusively by headless touch regression.

func _build_ui() -> void:
    ui = V5HUDScript.new()
    ui.name = "MobileUI"
    add_child(ui)
    ui.setup(ui_font)
    ui.movement_changed.connect(func(value: Vector2): move_input = value)
    ui.attack_requested.connect(_attack)
    var hud := ui as RiftV5HUD
    hud.skill_requested.connect(_use_skill)
    hud.weapon_equip_requested.connect(_equip_weapon_index)
    hud.fullscreen_requested.connect(_toggle_fullscreen)
    hud.set_desktop_mode(desktop_layout_enabled)
    ui.set_hp(player_hp, player_max_hp)
    _apply_runtime_hint()

func _ready() -> void:
    super._ready()
    if ui == null or armor_ui == null or gem_ui == null:
        return
    # Replace presentation objects only. Their arrays are snapshots of the
    # actual state, not new inventories or duplicated items.
    var obsolete_gems := gem_ui
    remove_child(obsolete_gems)
    obsolete_gems.queue_free()
    gem_ui = V5GemScript.new() as RiftLinkedGemUI
    gem_ui.name = "LinkedGemInventory"
    add_child(gem_ui)
    gem_ui.setup(ui_font)
    gem_ui.gem_requested.connect(_select_gem)
    gem_ui.socket_requested.connect(_use_socket)
    gem_ui.currency_requested.connect(_use_currency)
    gem_ui.aura_requested.connect(_toggle_aura)
    (gem_ui as RiftV5GemUI).set_action_interval(Callable(self, "_action_seconds"))
    gem_ui.closed.connect(_on_v5_gem_closed)

    var obsolete_gear := armor_ui
    remove_child(obsolete_gear)
    obsolete_gear.queue_free()
    armor_ui = V5GearScript.new() as RiftArmorEquipmentUI
    armor_ui.name = "ArmorEquipment"
    add_child(armor_ui)
    armor_ui.setup(ui_font)
    armor_ui.edit_requested.connect(_open_equipment_sockets)
    armor_ui.equip_requested.connect(_equip_armor)
    (armor_ui as RiftV5EquipmentUI).weapon_equip_requested.connect(_equip_weapon_index)
    armor_ui.closed.connect(_on_equipment_closed)
    (armor_ui as RiftV5EquipmentUI).gem_tab_requested.connect(_open_gem_ui)
    (armor_ui as RiftV5EquipmentUI).gear_tab_requested.connect(_open_armor_ui)
    (armor_ui as RiftV5EquipmentUI).bind_gem_editor(gem_ui as RiftV5GemUI)
    _refresh_gameplay_ui()
    _refresh_gem_ui()
    (ui as RiftV5HUD).set_mana_state(player_mana)
    _reset_v5_controls()

func _mobile_controls() -> bool:
    return _v5_force_mobile or _is_mobile_runtime() or DisplayServer.is_touchscreen_available()

func _inventory_open() -> bool:
    return armor_ui != null and armor_ui.is_open() or gem_ui != null and gem_ui.is_open() or _is_region_map_open() or ui is RiftGameplayUI and (ui as RiftGameplayUI).equipment_panel != null and (ui as RiftGameplayUI).equipment_panel.visible

func _reset_v5_controls() -> void:
    move_input = Vector2.ZERO
    mouse_fire_held = false
    if ui is RiftV5HUD:
        (ui as RiftV5HUD).reset_joystick()
    if player != null:
        player.velocity = Vector3.ZERO

func _set_v5_locked(locked: bool) -> void:
    mouse_fire_held = false
    if ui is RiftV5HUD and (ui as RiftV5HUD)._controls_locked != locked:
        (ui as RiftV5HUD).set_controls_locked(locked)
    if locked:
        move_input = Vector2.ZERO
        if player != null:
            player.velocity = Vector3.ZERO

func _input(event: InputEvent) -> void:
    # Touch ID ownership is decided only by RiftV5HUD (precise joystick hit
    # region). This gate also prevents synthetic touch-mouse attacks from
    # reaching gameplay through the world input path.
    if _mobile_controls() and event is InputEventMouseButton:
        mouse_fire_held = false
    if _inventory_open() and event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
        _set_v5_locked(true)

func _unhandled_input(event: InputEvent) -> void:
    if _mobile_controls() and (event is InputEventMouseButton or event is InputEventMouseMotion):
        mouse_fire_held = false
        get_viewport().set_input_as_handled()
        return
    if _inventory_open() and event is InputEventMouseButton:
        mouse_fire_held = false
        get_viewport().set_input_as_handled()
        return
    super._unhandled_input(event)

func _physics_process(delta: float) -> void:
    var modal := _inventory_open()
    _set_v5_locked(modal)
    if modal:
        return
    if _mobile_controls():
        mouse_fire_held = false
    super._physics_process(delta)

func _attack() -> void:
    if _inventory_open():
        return
    # Called by an explicit button press; world-generated mouse events are
    # handled separately, and can never set a held fire state on touch devices.
    super._attack()

func _refresh_resource_hud() -> void:
    super._refresh_resource_hud()
    if ui is RiftV5HUD:
        (ui as RiftV5HUD).set_mana_state(player_mana)

func _apply_mobile_landscape_touch_overlay() -> void:
    super._apply_mobile_landscape_touch_overlay()
    if not mobile_landscape_enabled or ui == null:
        return
    var hud := ui as RiftV5HUD
    if hud == null:
        return
    var size := get_viewport().get_visible_rect().size
    var scale_factor := clampf(size.y / 720.0, 0.72, 1.30)
    var stick := 133.0 * scale_factor
    hud.joystick_back.size = Vector2.ONE * stick
    hud.joystick_back.position = Vector2(16.0, size.y - stick - 20.0)
    hud.joystick_center = hud.joystick_back.position + hud.joystick_back.size * 0.5
    hud.call("_set_knob", hud.movement)
    var attack := 116.0 * scale_factor
    hud.attack_button.size = Vector2.ONE * attack
    hud.attack_button.position = Vector2(size.x - attack - 22.0, size.y - attack - 24.0)
    hud.attack_button.add_theme_font_size_override("font_size", 23)

func _open_armor_ui() -> void:
    _reset_v5_controls()
    _set_v5_locked(true)
    if gem_ui != null and gem_ui.is_open():
        gem_ui.close()
    _v5_target_kind = ""
    _v5_target_uid = 0
    _editing_slot = "weapon"
    super._open_armor_ui()
    if armor_ui is RiftV5EquipmentUI:
        (armor_ui as RiftV5EquipmentUI).show_gem_page(false)

func _open_gem_ui() -> void:
    _v5_target_kind = ""
    _v5_target_uid = 0
    _editing_slot = "weapon"
    _show_v5_gems()

func _open_equipment_sockets(slot: String) -> void:
    _v5_target_kind = ""
    _v5_target_uid = 0
    if slot == "selected" and armor_ui is RiftV5EquipmentUI:
        var target := (armor_ui as RiftV5EquipmentUI).selected_edit_target()
        if target.is_empty():
            return
        _v5_target_kind = String(target["kind"])
        _v5_target_uid = int(target["uid"])
        _editing_slot = "selected"
    elif slot == "weapon" or equipped_armor.has(slot):
        _editing_slot = slot
    else:
        return
    _show_v5_gems()

func _show_v5_gems() -> void:
    if not armor_ui is RiftV5EquipmentUI or not gem_ui is RiftV5GemUI:
        return
    _reset_v5_controls()
    _set_v5_locked(true)
    if not armor_ui.is_open():
        # The actual combined inventory remains the sole fullscreen modal.
        var hud := ui as RiftGameplayUI
        if hud != null and hud.equipment_panel != null:
            hud.equipment_panel.hide()
        armor_ui.set_data(equipped_armor, armor_inventory)
        (armor_ui as RiftV5EquipmentUI).set_weapons(weapon_inventory, _equipped_weapon_index)
        armor_ui.open()
    _selected_gem = -1
    _refresh_gem_ui()
    (armor_ui as RiftV5EquipmentUI).show_gem_page(true)
    gem_ui.open()

func _on_v5_gem_closed() -> void:
    if armor_ui is RiftV5EquipmentUI and armor_ui.is_open():
        (armor_ui as RiftV5EquipmentUI).show_gem_page(false)
    _v5_target_kind = ""
    _v5_target_uid = 0
    _editing_slot = "weapon"
    _reset_v5_controls()

func _on_equipment_closed() -> void:
    if gem_ui != null and gem_ui.is_open():
        gem_ui.close()
    _reset_v5_controls()
    _set_v5_locked(false)
    super._on_equipment_closed()

func _get_weapon() -> Dictionary:
    if _editing_slot == "selected" and _v5_target_uid > 0:
        if _v5_target_kind == "weapon":
            for i in range(weapon_inventory.size()):
                if i != _equipped_weapon_index and int(weapon_inventory[i].get("instance_uid", 0)) == _v5_target_uid:
                    return GemSystem.normalize_weapon_sockets(weapon_inventory[i], false)
        elif _v5_target_kind == "armor":
            for item in armor_inventory:
                if int(item.get("instance_uid", 0)) == _v5_target_uid:
                    var armor := ArmorSystem.normalize(item)
                    armor["damage"] = float(equipped_weapon.get("damage", 0.0))
                    return armor
        return {}
    return super._get_weapon()

func _save_weapon(item: Dictionary) -> void:
    if _editing_slot == "selected" and _v5_target_uid > 0:
        if _v5_target_kind == "weapon":
            for i in range(weapon_inventory.size()):
                if i != _equipped_weapon_index and int(weapon_inventory[i].get("instance_uid", 0)) == _v5_target_uid:
                    var weapon := GemSystem.normalize_weapon_sockets(item, false)
                    weapon["instance_uid"] = _v5_target_uid
                    weapon_inventory[i] = weapon.duplicate(true)
                    _refresh_gameplay_ui()
                    return
        elif _v5_target_kind == "armor":
            for i in range(armor_inventory.size()):
                if int(armor_inventory[i].get("instance_uid", 0)) == _v5_target_uid:
                    var armor := ArmorSystem.normalize(item)
                    armor.erase("damage")
                    armor["instance_uid"] = _v5_target_uid
                    armor_inventory[i] = armor.duplicate(true)
                    _refresh_gameplay_ui()
                    return
        return
    super._save_weapon(item)

func debug_v5_state() -> Dictionary:
    return {"mobile":_mobile_controls(), "fire_held":mouse_fire_held, "modal":_inventory_open(), "target_uid":_v5_target_uid, "target_kind":_v5_target_kind, "inventory":(armor_ui as RiftV5EquipmentUI).debug_v5_inventory() if armor_ui is RiftV5EquipmentUI else {}, "gem":(gem_ui as RiftV5GemUI).debug_embedded() if gem_ui is RiftV5GemUI else {}, "controls":(ui as RiftV5HUD).debug_v5_controls() if ui is RiftV5HUD else {}}
