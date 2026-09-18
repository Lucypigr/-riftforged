extends "res://scripts/unified_equipment_ui.gd"
class_name RiftPictureEquipmentUI

# Reference composition: character equipment on top, 12x5 grid underneath.
# Scrollable sections preserve the same physical inventory on narrow phones.
func _layout() -> void:
    super._layout()
    if panel == null:
        return
    var screen := get_viewport().get_visible_rect().size
    var compact := screen.x < 700.0
    var width := minf(690.0, screen.x - 12.0)
    var height := minf(705.0, screen.y - 12.0)
    panel.size = Vector2(width, height)
    panel.position = (screen - panel.size) * 0.5
    var heading := panel.get_node("Title") as Label
    heading.position = Vector2(13, 8)
    heading.size = Vector2(width - 64, 29)
    heading.add_theme_font_size_override("font_size", 15 if compact else 19)
    var close_button := panel.get_node("Close") as Button
    close_button.position = Vector2(width - 46, 7)
    close_button.size = Vector2(36, 34)
    summary.position = Vector2(13, 39)
    summary.size = Vector2(width - 26, 23)
    var gear_scroll := panel.get_node("GearScroll") as ScrollContainer
    var bag_scroll := panel.get_node("BagScroll") as ScrollContainer
    var gear_height := minf(327.0, (height - 81.0) * 0.53)
    gear_scroll.size = Vector2(minf(465.0, width - 22.0), gear_height)
    gear_scroll.position = Vector2((width - gear_scroll.size.x) * 0.5, 68)
    bag_scroll.position = Vector2(11, gear_scroll.position.y + gear_height + 6)
    bag_scroll.size = Vector2(width - 22.0, height - bag_scroll.position.y - 8.0)
    gear_list.custom_minimum_size.x = gear_scroll.size.x - 15.0
    bag_list.custom_minimum_size.x = bag_scroll.size.x - 15.0
    _grid_cell = floorf(minf(47.0, (bag_scroll.size.x - 28.0) / float(Bag.WIDTH)))
    _render()
