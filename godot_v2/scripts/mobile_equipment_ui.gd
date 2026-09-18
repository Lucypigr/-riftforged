extends "res://scripts/equipment_interaction_ui.gd"
class_name RiftMobileEquipmentUI

# The desktop mouse drag is intentionally unchanged. Native screen touches use
# a separate gesture recognizer: tap selects, hold inspects, movement drags.
const HOLD_MS := 440
const DRAG_DISTANCE := 19.0
var _finger := -1
var _touch_origin := Vector2.ZERO
var _touch_position := Vector2.ZERO
var _touch_started := 0
var _touch_payload: Dictionary = {}
var _touch_dragging := false
var _hold_visible := false
var _suppress_tap_uid := 0
var _drag_ghost: Panel
var _drag_ghost_label: Label
var _simulate_touch_landscape := false # Regression tests only.

func setup(font: FontFile) -> void:
    super.setup(font)
    _drag_ghost = Panel.new()
    _drag_ghost.name = "TouchDragPreview"
    _drag_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _drag_ghost.z_index = 90
    _drag_ghost.size = Vector2(170, 62)
    _drag_ghost.add_theme_stylebox_override("panel", _frame(Color(0.075, 0.075, 0.10, 0.91), Color(0.95, 0.73, 0.34)))
    root.add_child(_drag_ghost)
    _drag_ghost_label = Label.new()
    _drag_ghost_label.name = "DragName"
    _drag_ghost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _drag_ghost_label.position = Vector2(8, 6)
    _drag_ghost_label.size = Vector2(154, 48)
    _drag_ghost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _drag_ghost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _drag_ghost.add_child(_drag_ghost_label)
    _drag_ghost.hide()
    set_process(true)

func _is_touch_landscape() -> bool:
    var size := get_viewport().get_visible_rect().size
    return size.x > size.y and (_simulate_touch_landscape or DisplayServer.is_touchscreen_available() or OS.has_feature("web_ios") or OS.has_feature("web_android") or OS.has_feature("ios") or OS.has_feature("android"))

func _layout() -> void:
    super._layout()
    if panel == null or not _is_touch_landscape():
        return
    var screen := get_viewport().get_visible_rect().size
    var width := minf(1240.0, screen.x - 12.0)
    var height := screen.y - 12.0
    panel.size = Vector2(width, height)
    panel.position = (screen - panel.size) * 0.5
    var title := panel.get_node("Title") as Label
    title.position = Vector2(16, 8)
    title.size = Vector2(width - 112, 47)
    title.add_theme_font_size_override("font_size", 20)
    var exit := panel.get_node("Close") as Button
    exit.position = Vector2(width - 86, 6)
    exit.size = Vector2(76, 66)
    exit.add_theme_font_size_override("font_size", 24)
    summary.position = Vector2(16, 49)
    summary.size = Vector2(width - 110, 30)
    summary.add_theme_font_size_override("font_size", 13)
    var gear_scroll := panel.get_node("GearScroll") as ScrollContainer
    var bag_scroll := panel.get_node("BagScroll") as ScrollContainer
    var left_width := maxf(285.0, minf(465.0, width * 0.36))
    gear_scroll.position = Vector2(12, 82)
    gear_scroll.size = Vector2(left_width, height - 91.0)
    bag_scroll.position = Vector2(gear_scroll.position.x + left_width + 12.0, 82)
    bag_scroll.size = Vector2(width - bag_scroll.position.x - 12.0, height - 91.0)
    bag_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    gear_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    gear_list.custom_minimum_size.x = left_width - 18.0
    _grid_cell = maxf(58.0, minf(72.0, floorf((bag_scroll.size.x - 26.0) / float(Bag.WIDTH))))
    bag_list.custom_minimum_size.x = maxf(bag_scroll.size.x - 16.0, float(Bag.WIDTH) * _grid_cell + 8.0)
    _render()
    _enlarge_landscape_targets()

func _render() -> void:
    super._render()
    if _is_touch_landscape():
        _enlarge_landscape_targets()

func _enlarge_landscape_targets() -> void:
    if gear_list == null or bag_list == null:
        return
    var board := gear_list.get_node_or_null("EquipmentBoard") as GridContainer
    if board != null:
        var tile_width := floorf(maxf(82.0, (gear_list.custom_minimum_size.x - 17.0) / 3.0))
        for tile in board.get_children():
            if tile is Button:
                (tile as Button).custom_minimum_size = Vector2(tile_width, 112)
                (tile as Button).size = Vector2(tile_width, 112)
                var tag := tile.get_node_or_null("SlotTag") as Label
                if tag != null:
                    tag.size.x = tile_width - 6.0
                    tag.add_theme_font_size_override("font_size", 16)
                var gear: Dictionary = {}
                var slot := String(tile.name).trim_prefix("Equipped_")
                if slot == "weapon" and _weapon_index >= 0 and _weapon_index < _weapons.size():
                    gear = _weapons[_weapon_index]
                elif _equipped.has(slot):
                    gear = _equipped[slot]
                _center_sockets(tile as Control, gear)
            else:
                (tile as Control).custom_minimum_size.y = 112.0
    var equip := bag_list.get_node_or_null("EquipSelected") as Button
    if equip != null:
        equip.custom_minimum_size.y = 68.0
        equip.add_theme_font_size_override("font_size", 20)
    var details := bag_list.get_node_or_null("SelectedItemDetails") as Label
    if details != null:
        details.add_theme_font_size_override("font_size", 15)
        details.text = "點選選取 → 點左側欄位裝備；拖曳可直接換裝；長按查看屬性。"
    var grid := bag_list.get_node_or_null("UnifiedItemGrid") as Control
    if grid != null:
        for placement in _last_pack.get("placements", []):
            var card := _card_at(String(placement["kind"]), int(placement["index"])) as Button
            if card == null:
                continue
            card.add_theme_font_size_override("font_size", 16)
            card.mouse_filter = Control.MOUSE_FILTER_STOP

func _bag_hover(kind: String, index: int, card: Control) -> void:
    # Emulated touch-mouse hover must not display info before the long press.
    if _finger >= 0 or DisplayServer.is_touchscreen_available():
        return
    super._bag_hover(kind, index, card)

func _select_item(kind: String, index: int) -> void:
    var item := _item_at(kind, index)
    if int(item.get("instance_uid", 0)) == _suppress_tap_uid and _suppress_tap_uid > 0:
        _suppress_tap_uid = 0
        return
    super._select_item(kind, index)

func _process(_delta: float) -> void:
    if _finger < 0 or _touch_dragging or _hold_visible or not is_open():
        return
    if Time.get_ticks_msec() - _touch_started < HOLD_MS:
        return
    var item := _resolve_touch_item()
    if item.is_empty():
        return
    _hold_visible = true
    _show_inspection(item, _card_at(String(_touch_payload["kind"]), int(_touch_payload["index"])))

func _input(event: InputEvent) -> void:
    if not is_open():
        return
    if event is InputEventScreenTouch:
        var touch := event as InputEventScreenTouch
        if touch.pressed:
            if _finger >= 0:
                return
            var payload := _card_under_point(touch.position)
            if payload.is_empty():
                return
            _finger = touch.index
            _touch_origin = touch.position
            _touch_position = touch.position
            _touch_started = Time.get_ticks_msec()
            _touch_payload = payload
            _touch_dragging = false
            _hold_visible = false
            _suppress_tap_uid = 0
        elif touch.index == _finger:
            var uid := int(_touch_payload.get("instance_uid", 0))
            if _touch_dragging:
                _suppress_tap_uid = uid
                var slot := _slot_under_point(touch.position)
                if not slot.is_empty() and _can_drop(Vector2.ZERO, _touch_payload, slot):
                    _drop_on_slot(Vector2.ZERO, _touch_payload, slot)
                get_viewport().set_input_as_handled()
            elif _hold_visible:
                _suppress_tap_uid = uid
                _hide_inspection()
                get_viewport().set_input_as_handled()
            _reset_touch()
    elif event is InputEventScreenDrag:
        var drag := event as InputEventScreenDrag
        if drag.index != _finger:
            return
        _touch_position = drag.position
        if not _touch_dragging and drag.position.distance_to(_touch_origin) >= DRAG_DISTANCE:
            _touch_dragging = true
            _hold_visible = false
            _hide_inspection()
            var item := _resolve_touch_item()
            if item.is_empty():
                _reset_touch()
                return
            _drag_ghost_label.text = String(item.get("name", "裝備"))
            _drag_ghost.show()
        if _touch_dragging:
            var bounds := get_viewport().get_visible_rect().size
            _drag_ghost.position = Vector2(clampf(drag.position.x + 16.0, 0.0, maxf(0.0, bounds.x - _drag_ghost.size.x)), clampf(drag.position.y - 77.0, 0.0, maxf(0.0, bounds.y - _drag_ghost.size.y)))
            get_viewport().set_input_as_handled()

func _card_under_point(point: Vector2) -> Dictionary:
    var scroll := panel.get_node_or_null("BagScroll") as ScrollContainer
    if scroll == null or not scroll.get_global_rect().has_point(point):
        return {}
    for placement in _last_pack.get("placements", []):
        var kind := String(placement["kind"])
        var index := int(placement["index"])
        var card := _card_at(kind, index)
        if card != null and card.get_global_rect().has_point(point):
            return _drag_payload(kind, index)
    return {}

func _slot_under_point(point: Vector2) -> String:
    var scroll := panel.get_node_or_null("GearScroll") as ScrollContainer
    if scroll == null or not scroll.get_global_rect().has_point(point):
        return ""
    var board := gear_list.get_node_or_null("EquipmentBoard") as GridContainer
    if board == null:
        return ""
    for slot in ["weapon", "頭部", "身體", "腿部", "鞋子"]:
        var tile := board.get_node_or_null("Equipped_" + slot) as Button
        if tile != null and tile.get_global_rect().has_point(point):
            return slot
    return ""

func _resolve_touch_item() -> Dictionary:
    var kind := String(_touch_payload.get("kind", ""))
    var index := int(_touch_payload.get("index", -1))
    var item := _item_at(kind, index)
    if int(item.get("instance_uid", 0)) != int(_touch_payload.get("instance_uid", -1)):
        return {}
    return item

func _reset_touch() -> void:
    _finger = -1
    _touch_payload.clear()
    _touch_dragging = false
    _hold_visible = false
    if _drag_ghost != null:
        _drag_ghost.hide()

func close() -> void:
    _reset_touch()
    _suppress_tap_uid = 0
    super.close()

func debug_mobile_interaction() -> Dictionary:
    return {"landscape":_is_touch_landscape(), "finger":_finger, "dragging":_touch_dragging, "holding":_hold_visible, "ghost_visible":_drag_ghost != null and _drag_ghost.visible, "grid_cell":_grid_cell, "panel":panel.size if panel != null else Vector2.ZERO, "selected_uid":_selected_uid}
