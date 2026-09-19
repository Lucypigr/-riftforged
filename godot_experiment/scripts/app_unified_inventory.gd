extends "res://scripts/app_monster_art.gd"

const UnifiedHUD = preload("res://scripts/unified_inventory_hud.gd")
const UnifiedUI = preload("res://scripts/unified_equipment_ui.gd")
const Bag = preload("res://scripts/unified_bag.gd")
var _last_full_hint := 0

func _build_ui() -> void:
    ui = UnifiedHUD.new()
    ui.name = "MobileUI"
    add_child(ui)
    ui.setup(ui_font)
    ui.movement_changed.connect(func(value: Vector2): move_input = value)
    ui.attack_requested.connect(_attack)
    var hud := ui as RiftUnifiedInventoryHUD
    hud.skill_requested.connect(_use_skill)
    hud.weapon_equip_requested.connect(_equip_weapon_index)
    hud.fullscreen_requested.connect(_toggle_fullscreen)
    hud.set_desktop_mode(desktop_layout_enabled)
    ui.set_hp(player_hp, player_max_hp)
    _apply_runtime_hint()

func _ready() -> void:
    super._ready()
    if ui == null or armor_ui == null:
        return
    # Replace the old separate armor list, but retain the existing armor/gem
    # data and socket editing API. There is now one visible equipment window.
    var old_ui := armor_ui
    remove_child(old_ui)
    old_ui.queue_free()
    armor_ui = UnifiedUI.new() as RiftUnifiedEquipmentUI
    armor_ui.name = "ArmorEquipment"
    add_child(armor_ui)
    armor_ui.setup(ui_font)
    armor_ui.edit_requested.connect(_open_equipment_sockets)
    armor_ui.equip_requested.connect(_equip_armor)
    (armor_ui as RiftUnifiedEquipmentUI).weapon_equip_requested.connect(_equip_weapon_index)
    armor_ui.closed.connect(_on_equipment_closed)
    var hud := ui as RiftUnifiedInventoryHUD
    hud.unified_requested.connect(_open_armor_ui)
    hud.unified_close_requested.connect(_close_equipment_window)
    _refresh_gameplay_ui()

func _on_equipment_closed() -> void:
    var hud := ui as RiftUnifiedInventoryHUD
    if hud != null and hud.equipment_panel != null:
        hud.equipment_panel.visible = false

func _close_equipment_window() -> void:
    if armor_ui != null and armor_ui.is_open():
        armor_ui.close()

func _open_equipment_sockets(slot: String) -> void:
    if slot == "weapon":
        _open_gem_ui()
    else:
        super._open_equipment_sockets(slot)

func _refresh_gameplay_ui() -> void:
    super._refresh_gameplay_ui()
    if armor_ui is RiftUnifiedEquipmentUI:
        armor_ui.set_data(equipped_armor, armor_inventory)
        (armor_ui as RiftUnifiedEquipmentUI).set_weapons(weapon_inventory, _equipped_weapon_index)

func _equip_weapon_index(index: int) -> void:
    if index < 0 or index >= weapon_inventory.size():
        return
    var outcome := Bag.pack(weapon_inventory, index, armor_inventory)
    if not (outcome["overflow"] as Array).is_empty():
        ui.set_hint("背包空間不足，無法收回原武器；請先整理背包。")
        return
    super._equip_weapon_index(index)
    _refresh_gameplay_ui()

func _equip_armor(index: int) -> void:
    if index < 0 or index >= armor_inventory.size():
        return
    var new_bag := armor_inventory.duplicate(true)
    var target := new_bag[index] as Dictionary
    var slot := String(ArmorSystem.canonical_slot(String(target.get("slot", ""))))
    if slot.is_empty() or not equipped_armor.has(slot):
        return
    new_bag.remove_at(index)
    new_bag.append((equipped_armor[slot] as Dictionary).duplicate(true))
    if not (Bag.pack(weapon_inventory, _equipped_weapon_index, new_bag)["overflow"] as Array).is_empty():
        ui.set_hint("背包空間不足，無法收回原護具；換裝已取消。")
        return
    super._equip_armor(index)

func _can_store_equipment(item: Dictionary) -> bool:
    var slot := String(item.get("slot", ""))
    if slot != "武器" and ArmorSystem.canonical_slot(slot).is_empty():
        return true
    return Bag.fits_after_pickup(weapon_inventory, _equipped_weapon_index, armor_inventory, item)

func _pickup_item(item: Dictionary) -> void:
    if not _can_store_equipment(item):
        ui.set_hint("背包已滿：無法拾取 %s，裝備留在地面。" % String(item.get("name", "裝備")))
        return
    if String(item.get("slot", "")) == "武器":
        # A picked weapon goes into the physical bag; it never silently equips
        # and invalidates the capacity calculation or replaces socketed gems.
        var weapon := GemSystem.normalize_weapon_sockets(WeaponSkillSystem.normalize_weapon(item), false)
        weapon_inventory.append(weapon)
        picked_loot += 1
        ui.set_hint("拾取 %s：已放入共用背包。" % String(weapon.get("name", "武器")))
        _refresh_gameplay_ui()
        return
    super._pickup_item(item)
    _refresh_gameplay_ui()

func _update_loot() -> void:
    var now := Time.get_ticks_msec()
    if now - _last_loot_scan_ms < 80:
        return
    _last_loot_scan_ms = now
    for i in range(loot_drops.size() - 1, -1, -1):
        var entry: Dictionary = loot_drops[i]
        var node := entry.get("node") as Node3D
        if not is_instance_valid(node):
            loot_drops.remove_at(i)
            continue
        if player.global_position.distance_to(node.global_position) > LOOT_PICKUP_RANGE:
            continue
        var item: Dictionary = entry["item"]
        if not _can_store_equipment(item):
            if now - _last_full_hint > 1900:
                ui.set_hint("背包已滿，%s 會留在地上；請先整理空間。" % String(item.get("name", "裝備")))
                _last_full_hint = now
            continue
        _pickup_item(item)
        node.queue_free()
        loot_drops.remove_at(i)

func debug_unified_state() -> Dictionary:
    var result := Bag.pack(weapon_inventory, _equipped_weapon_index, armor_inventory)
    var view := {}
    if armor_ui is RiftUnifiedEquipmentUI:
        view = (armor_ui as RiftUnifiedEquipmentUI).debug_unified_inventory()
    return {"items":(result["placements"] as Array).size(), "overflow":(result["overflow"] as Array).size(), "occupied":int(result["used"]), "capacity":int(result["capacity"]), "weapons":weapon_inventory.size(), "armor":armor_inventory.size(), "view":view, "ground":loot_drops.size()}
