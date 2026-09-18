extends "res://scripts/poe_inventory_ui.gd"
class_name RiftUnifiedInventoryHUD

signal unified_requested
signal unified_close_requested

func _toggle_equipment_panel() -> void:
    if equipment_panel == null:
        return
    if equipment_panel.visible:
        equipment_panel.visible = false
        unified_close_requested.emit()
        return
    # Keep the old weapon widgets mounted behind the full-screen unified layer
    # for compatibility with existing scenes and test callbacks. Players only
    # see the new character/combined-bag panel.
    super._toggle_equipment_panel()
    unified_requested.emit()
    equipment_panel.visible = true
