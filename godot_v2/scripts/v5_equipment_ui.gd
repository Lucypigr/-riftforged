extends "res://scripts/mobile_equipment_ui.gd"
class_name RiftV5EquipmentUI

signal gem_tab_requested
signal gear_tab_requested

var _gem_page := false
var _tab_gear: Button
var _tab_gems: Button
var _gem_editor: RiftV5GemUI

func setup(font: FontFile) -> void:
    super.setup(font)
    _tab_gear = Button.new()
    _tab_gear.name = "GearTab"
    _tab_gear.text = "裝備與背包"
    _tab_gear.focus_mode = Control.FOCUS_NONE
    _tab_gear.pressed.connect(func(): gear_tab_requested.emit())
    panel.add_child(_tab_gear)
    _tab_gems = Button.new()
    _tab_gems.name = "GemTab"
    _tab_gems.text = "寶石／孔洞"
    _tab_gems.focus_mode = Control.FOCUS_NONE
    _tab_gems.pressed.connect(func(): gem_tab_requested.emit())
    panel.add_child(_tab_gems)
    _layout()

func bind_gem_editor(editor: RiftV5GemUI) -> void:
    _gem_editor = editor
    _gem_editor.embed(panel)
    _apply_page()

func show_gem_page(enabled: bool) -> void:
    _gem_page = enabled
    _apply_page()

func _apply_page() -> void:
    if panel == null or _tab_gear == null or _tab_gems == null:
        return
    var gear_scroll := panel.get_node_or_null("GearScroll") as ScrollContainer
    var bag_scroll := panel.get_node_or_null("BagScroll") as ScrollContainer
    if gear_scroll != null:
        gear_scroll.visible = not _gem_page
    if bag_scroll != null:
        bag_scroll.visible = not _gem_page
    if summary != null:
        summary.hide()
    _tab_gear.disabled = not _gem_page
    _tab_gems.disabled = _gem_page
    _tab_gems.text = "寶石／孔洞" if not _gem_page else "正在編輯寶石"
    if _gem_editor != null:
        _gem_editor._layout()
        if not _gem_page and _gem_editor.is_open():
            _gem_editor.close()

func _layout() -> void:
    super._layout()
    if panel == null or _tab_gear == null or _tab_gems == null:
        return
    var screen := get_viewport().get_visible_rect().size
    var desktop := screen.x >= 820.0 and not _is_touch_landscape()
    if desktop:
        var width := minf(1100.0, screen.x - 20.0)
        var height := minf(720.0, screen.y - 20.0)
        panel.size = Vector2(width, height)
        panel.position = (screen - panel.size) * 0.5
        var heading := panel.get_node("Title") as Label
        heading.size.x = width - 82.0
        var exit := panel.get_node("Close") as Button
        exit.position = Vector2(width - 54.0, 7.0)
        exit.size = Vector2(44.0, 39.0)
        var gear_scroll := panel.get_node("GearScroll") as ScrollContainer
        var bag_scroll := panel.get_node("BagScroll") as ScrollContainer
        gear_scroll.position = Vector2(12.0, 82.0)
        gear_scroll.size = Vector2(floorf(width * 0.38), height - 92.0)
        bag_scroll.position = Vector2(gear_scroll.position.x + gear_scroll.size.x + 10.0, 82.0)
        bag_scroll.size = Vector2(width - bag_scroll.position.x - 12.0, height - 92.0)
        gear_list.custom_minimum_size.x = gear_scroll.size.x - 17.0
        bag_list.custom_minimum_size.x = bag_scroll.size.x - 17.0
        _grid_cell = floorf(minf(47.0, (bag_scroll.size.x - 28.0) / float(Bag.WIDTH)))
        _render()
    elif not _is_touch_landscape():
        var gear_scroll := panel.get_node("GearScroll") as ScrollContainer
        var bag_scroll := panel.get_node("BagScroll") as ScrollContainer
        gear_scroll.position.y = 82.0
        gear_scroll.size.y = maxf(95.0, gear_scroll.size.y - 14.0)
        bag_scroll.position.y = gear_scroll.position.y + gear_scroll.size.y + 6.0
        bag_scroll.size.y = maxf(95.0, panel.size.y - bag_scroll.position.y - 9.0)
    _tab_gear.position = Vector2(12.0, 44.0)
    _tab_gear.size = Vector2(minf(146.0, (panel.size.x - 34.0) * 0.50), 32.0)
    _tab_gems.position = Vector2(_tab_gear.position.x + _tab_gear.size.x + 7.0, 44.0)
    _tab_gems.size = _tab_gear.size
    _apply_page()

func _render() -> void:
    super._render()
    if bag_list == null:
        return
    var edit := Button.new()
    edit.name = "EditSelectedSockets"
    edit.text = "◆ 編輯選取裝備的孔洞與寶石"
    edit.custom_minimum_size.y = 48.0
    edit.disabled = selected_edit_target().is_empty()
    edit.focus_mode = Control.FOCUS_NONE
    edit.pressed.connect(func(): edit_requested.emit("selected"))
    bag_list.add_child(edit)
    if _tab_gear != null:
        _apply_page()

func selected_edit_target() -> Dictionary:
    _restore_selection()
    var item := _item_at(_selected_kind, _selected_index)
    if item.is_empty() or _selected_uid <= 0:
        return {}
    return {"kind":_selected_kind, "uid":_selected_uid, "name":String(item.get("name", "裝備"))}

func _description(item: Dictionary) -> String:
    return String(item.get("name", "裝備"))

func _show_inspection(item: Dictionary, anchor: Control) -> void:
    if _tooltip == null or _tooltip_label == null or not is_open():
        return
    _tooltip_label.text = _description(item)
    var screen := get_viewport().get_visible_rect().size
    var width := minf(252.0, maxf(100.0, screen.x - 16.0))
    var height := 46.0
    _tooltip.size = Vector2(width, height)
    _tooltip_label.position = Vector2(8.0, 5.0)
    _tooltip_label.size = Vector2(width - 16.0, height - 10.0)
    _tooltip_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    var card := anchor.get_global_rect() if anchor != null and is_instance_valid(anchor) else Rect2(screen * 0.5, Vector2.ZERO)
    var pos := Vector2(card.end.x + 8.0, card.position.y)
    if screen.x < 700.0 or DisplayServer.is_touchscreen_available():
        pos = Vector2(card.position.x, card.position.y - height - 9.0)
        if pos.y < 8.0:
            pos.y = card.end.y + 9.0
    elif pos.x + width > screen.x - 8.0:
        pos.x = card.position.x - width - 8.0
    pos.x = clampf(pos.x, 8.0, maxf(8.0, screen.x - width - 8.0))
    pos.y = clampf(pos.y, 8.0, maxf(8.0, screen.y - height - 8.0))
    _tooltip.position = pos - panel.global_position
    _tooltip.show()

func _select_item(kind: String, index: int) -> void:
    super._select_item(kind, index)
    # Selection is not inspection; only hover or a completed touch hold shows it.
    _touch_inspection = false
    _hide_inspection()

func _equipment_pressed(slot: String) -> void:
    _hide_inspection()
    super._equipment_pressed(slot)

func _input(event: InputEvent) -> void:
    if is_open() and event is InputEventScreenTouch:
        var touch := event as InputEventScreenTouch
        if touch.pressed and _hold_visible and _card_under_point(touch.position).is_empty():
            _hold_visible = false
            _hide_inspection()
    super._input(event)

func close() -> void:
    if _gem_editor != null and _gem_editor.is_open():
        _gem_editor.close()
    _gem_page = false
    super.close()
    _apply_page()

func debug_v5_inventory() -> Dictionary:
    return {"gear_tab":_tab_gear != null, "gem_tab":_tab_gems != null, "gem_embedded":_gem_editor != null and _gem_editor.panel.get_parent() == panel, "gem_page":_gem_page, "selected":selected_edit_target(), "tooltip_text":_tooltip_label.text if _tooltip_label != null else "", "tooltip_visible":_tooltip != null and _tooltip.visible}
