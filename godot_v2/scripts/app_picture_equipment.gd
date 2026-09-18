extends "res://scripts/app_unified_inventory.gd"

const PictureUI = preload("res://scripts/equipment_interaction_ui.gd")
var _next_equipment_uid := 1000000

func _ready() -> void:
    super._ready()
    if armor_ui == null:
        return
    var first_layout := armor_ui
    remove_child(first_layout)
    first_layout.queue_free()
    armor_ui = PictureUI.new() as RiftEquipmentInteractionUI
    armor_ui.name = "ArmorEquipment"
    add_child(armor_ui)
    armor_ui.setup(ui_font)
    armor_ui.edit_requested.connect(_open_equipment_sockets)
    armor_ui.equip_requested.connect(_equip_armor)
    (armor_ui as RiftEquipmentInteractionUI).weapon_equip_requested.connect(_equip_weapon_index)
    armor_ui.closed.connect(_on_equipment_closed)
    _refresh_gameplay_ui()

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
