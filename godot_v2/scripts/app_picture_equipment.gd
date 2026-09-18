extends "res://scripts/app_unified_inventory.gd"

const PictureUI = preload("res://scripts/picture_equipment_ui.gd")

func _ready() -> void:
    super._ready()
    if armor_ui == null:
        return
    var first_layout := armor_ui
    remove_child(first_layout)
    first_layout.queue_free()
    armor_ui = PictureUI.new() as RiftPictureEquipmentUI
    armor_ui.name = "ArmorEquipment"
    add_child(armor_ui)
    armor_ui.setup(ui_font)
    armor_ui.edit_requested.connect(_open_equipment_sockets)
    armor_ui.equip_requested.connect(_equip_armor)
    (armor_ui as RiftPictureEquipmentUI).weapon_equip_requested.connect(_equip_weapon_index)
    armor_ui.closed.connect(_on_equipment_closed)
    _refresh_gameplay_ui()
