extends "res://scripts/picture_equipment_ui.gd"
class_name RiftEquipmentInteractionUI

# Decorate the existing unified 12x5 view without creating another inventory.
# Inventory model stays owned by the game; this UI only holds deep-copied views.
var _selected_uid := 0
var _tooltip: Panel
var _tooltip_label: Label
var _touch_inspection := false
var _hover_uid := 0
var _drag_forwarders := 0

func setup(font: FontFile) -> void:
    super.setup(font)
    _tooltip = Panel.new()
    _tooltip.name = "ItemInspection"
    _tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _tooltip.z_index = 80
    _tooltip.add_theme_stylebox_override("panel", _frame(Color(0.025, 0.029, 0.042, 0.98), Color(0.79, 0.61, 0.34)))
    root.add_child(_tooltip)
    _tooltip_label = Label.new()
    _tooltip_label.name = "ItemInspectionText"
    _tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _tooltip_label.add_theme_font_size_override("font_size", 11)
    _tooltip_label.add_theme_color_override("font_color", Color(0.96, 0.92, 0.82))
    _tooltip.add_child(_tooltip_label)
    _tooltip.hide()

func close() -> void:
    _selected_kind = ""
    _selected_index = -1
    _selected_uid = 0
    _touch_inspection = false
    _hide_inspection()
    super.close()

func _item_at(kind: String, index: int) -> Dictionary:
    if kind == "weapon" and index >= 0 and index < _weapons.size() and index != _weapon_index:
        return _weapons[index]
    if kind == "armor" and index >= 0 and index < _bag.size():
        return _bag[index]
    return {}

func _restore_selection() -> void:
    if _selected_uid <= 0 or _selected_kind.is_empty():
        _selected_kind = ""
        _selected_index = -1
        return
    var collection: Array[Dictionary] = _weapons if _selected_kind == "weapon" else _bag
    for index in range(collection.size()):
        if _selected_kind == "weapon" and index == _weapon_index:
            continue
        if int(collection[index].get("instance_uid", 0)) == _selected_uid:
            _selected_index = index
            return
    _selected_kind = ""
    _selected_index = -1
    _selected_uid = 0
    _touch_inspection = false
    _hide_inspection()

func _render() -> void:
    _restore_selection()
    super._render()
    if gear_list == null or bag_list == null:
        return
    _drag_forwarders = 0
    var board := gear_list.get_node_or_null("EquipmentBoard") as GridContainer
    if board != null:
        for slot in ["weapon", "頭部", "身體", "腿部", "鞋子"]:
            var tile := board.get_node_or_null("Equipped_" + slot) as Button
            if tile == null:
                continue
            # The old tile ALWAYS opened the socket editor. Replace that
            # callback: a selected matching bag item must equip instead.
            for connection in tile.pressed.get_connections():
                tile.pressed.disconnect(connection["callable"])
            tile.pressed.connect(_equipment_pressed.bind(slot))
            tile.set_drag_forwarding(Callable(), _can_drop.bind(slot), _drop_on_slot.bind(slot))
            tile.text = ""
            tile.tooltip_text = ""
            var tag := Label.new()
            tag.name = "SlotTag"
            tag.text = "武器" if slot == "weapon" else slot
            tag.position = Vector2(3, 2)
            tag.size = Vector2(tile.custom_minimum_size.x - 6.0, 17)
            tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
            tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
            tag.add_theme_font_size_override("font_size", 10)
            tag.add_theme_color_override("font_color", Color(0.94, 0.83, 0.59))
            tile.add_child(tag)
            var item: Dictionary = _weapons[_weapon_index] if slot == "weapon" and _weapon_index >= 0 and _weapon_index < _weapons.size() else _equipped.get(slot, {})
            _center_sockets(tile, item)
            _drag_forwarders += 1
    var grid := bag_list.get_node_or_null("UnifiedItemGrid") as Control
    if grid != null:
        for placement in _last_pack.get("placements", []):
            var kind := String(placement.get("kind", ""))
            var index := int(placement.get("index", -1))
            var card := grid.get_node_or_null(("Weapon_" if kind == "weapon" else "ArmorItem_") + str(index)) as Button
            var item := _item_at(kind, index)
            if card == null or item.is_empty():
                continue
            card.text = ""  # Names and stats never compete with sockets.
            card.tooltip_text = ""  # The full inspection panel replaces Godot's tooltip.
            card.set_drag_forwarding(_begin_drag.bind(kind, index, card), Callable(), Callable())
            card.mouse_entered.connect(_bag_hover.bind(kind, index, card))
            card.mouse_exited.connect(_bag_exit.bind(kind, index))
            _center_sockets(card, item)
            _drag_forwarders += 1
    var details := bag_list.get_node_or_null("SelectedItemDetails") as Label
    if details != null:
        details.text = "點選裝備查看完整資料，再點上方對應欄位裝備；PC 可直接拖曳。"
    var equip := bag_list.get_node_or_null("EquipSelected") as Button
    if equip != null:
        equip.text = "裝備選取物品" if _selected_uid > 0 else "先點選背包中的裝備"
        equip.disabled = _selected_uid <= 0

func _select_item(kind: String, index: int) -> void:
    var item := _item_at(kind, index)
    if item.is_empty():
        return
    _selected_kind = kind
    _selected_index = index
    _selected_uid = int(item.get("instance_uid", 0))
    _touch_inspection = true
    _render()
    var card := _card_at(kind, _selected_index)
    _show_inspection(item, card)

func _equip_selected() -> void:
    _equip_from_selection("", false)

func _equipment_pressed(slot: String) -> void:
    if _selected_uid > 0:
        _equip_from_selection(slot, true)
    else:
        edit_requested.emit(slot)

func _equip_from_selection(slot: String, strict_slot: bool) -> void:
    _restore_selection()
    var item := _item_at(_selected_kind, _selected_index)
    if item.is_empty() or _selected_uid <= 0:
        return
    if strict_slot and not _matches_slot(_selected_kind, item, slot):
        summary.text = "請將裝備放到對應欄位：%s。" % String(item.get("slot", "武器"))
        return
    var old_uid := _selected_uid
    var index := _selected_index
    if _selected_kind == "weapon":
        weapon_equip_requested.emit(index)
    else:
        equip_requested.emit(index)
    # Game signals are synchronous: only clear selection if the live model
    # really moved this particular physical item into the equipment slot.
    var equipped := false
    if _selected_kind == "weapon":
        equipped = _weapon_index >= 0 and _weapon_index < _weapons.size() and int(_weapons[_weapon_index].get("instance_uid", 0)) == old_uid
    else:
        var slot_name := RiftArmorEquipment.canonical_slot(String(item.get("slot", "")))
        var gear: Dictionary = _equipped.get(slot_name, {})
        equipped = int(gear.get("instance_uid", 0)) == old_uid
    if equipped:
        _selected_uid = 0
        _selected_kind = ""
        _selected_index = -1
        _touch_inspection = false
        _hide_inspection()
    _render()

func _matches_slot(kind: String, item: Dictionary, slot: String) -> bool:
    if kind == "weapon":
        return slot == "weapon" and String(item.get("slot", "")) == "武器"
    return RiftArmorEquipment.canonical_slot(String(item.get("slot", ""))) == slot

func _drag_payload(kind: String, index: int) -> Dictionary:
    var item := _item_at(kind, index)
    if item.is_empty():
        return {}
    return {"kind":kind, "index":index, "instance_uid":int(item.get("instance_uid", 0))}

func _begin_drag(_position: Vector2, kind: String, index: int, source: Control) -> Variant:
    var data := _drag_payload(kind, index)
    if data.is_empty() or DisplayServer.is_touchscreen_available():
        return null
    var item := _item_at(kind, index)
    var preview := Panel.new()
    preview.size = Vector2(150, 48)
    preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
    preview.add_theme_stylebox_override("panel", _frame(Color(0.06, 0.065, 0.09, 0.92), _rarity(String(item.get("rarity", "普通")))))
    var label := Label.new()
    label.text = String(item.get("name", "裝備"))
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.size = preview.size
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    preview.add_child(label)
    source.set_drag_preview(preview)
    _hide_inspection()
    return data

func _can_drop(_position: Vector2, data: Variant, slot: String) -> bool:
    if not data is Dictionary:
        return false
    var payload := data as Dictionary
    var kind := String(payload.get("kind", ""))
    var index := int(payload.get("index", -1))
    var item := _item_at(kind, index)
    return not item.is_empty() and int(item.get("instance_uid", 0)) > 0 and int(item.get("instance_uid", 0)) == int(payload.get("instance_uid", -1)) and _matches_slot(kind, item, slot)

func _drop_on_slot(position: Vector2, data: Variant, slot: String) -> void:
    if not _can_drop(position, data, slot):
        return
    var payload := data as Dictionary
    var kind := String(payload["kind"])
    var index := int(payload["index"])
    _selected_kind = kind
    _selected_index = index
    _selected_uid = int(payload["instance_uid"])
    _equip_from_selection(slot, true)

func _card_at(kind: String, index: int) -> Control:
    var grid := bag_list.get_node_or_null("UnifiedItemGrid") if bag_list != null else null
    if grid == null:
        return null
    return grid.get_node_or_null(("Weapon_" if kind == "weapon" else "ArmorItem_") + str(index)) as Control

func _bag_hover(kind: String, index: int, card: Control) -> void:
    var item := _item_at(kind, index)
    if item.is_empty():
        return
    _hover_uid = int(item.get("instance_uid", 0))
    _show_inspection(item, card)

func _bag_exit(kind: String, index: int) -> void:
    var item := _item_at(kind, index)
    if _hover_uid == int(item.get("instance_uid", -1)):
        _hover_uid = 0
    if not _touch_inspection or not DisplayServer.is_touchscreen_available():
        _hide_inspection()

func _show_inspection(item: Dictionary, anchor: Control) -> void:
    if _tooltip == null or _tooltip_label == null or not is_open():
        return
    var content := _description(item)
    _tooltip_label.text = content
    var screen := get_viewport().get_visible_rect().size
    var width := minf(320.0, maxf(170.0, screen.x - 20.0))
    var height := minf(screen.y - 20.0, maxf(114.0, 24.0 + float(content.split("\n").size()) * 17.0))
    _tooltip.size = Vector2(width, height)
    _tooltip_label.position = Vector2(9, 8)
    _tooltip_label.size = Vector2(width - 18.0, height - 15.0)
    var rect := anchor.get_global_rect() if anchor != null and is_instance_valid(anchor) else Rect2(screen * 0.5, Vector2.ZERO)
    var position := Vector2(rect.end.x + 8.0, rect.position.y)
    if screen.x < 700.0 or DisplayServer.is_touchscreen_available():
        position = Vector2((screen.x - width) * 0.5, screen.y - height - 8.0)
    elif position.x + width > screen.x - 8.0:
        position.x = rect.position.x - width - 8.0
    position.x = clampf(position.x, 8.0, maxf(8.0, screen.x - width - 8.0))
    position.y = clampf(position.y, 8.0, maxf(8.0, screen.y - height - 8.0))
    _tooltip.position = position
    _tooltip.show()

func _hide_inspection() -> void:
    if _tooltip != null:
        _tooltip.hide()

func _description(item: Dictionary) -> String:
    var type_name := String(item.get("slot", "裝備"))
    if type_name == "武器":
        match String(item.get("weapon_type", "")):
            "bow": type_name = "弓"
            "blade": type_name = "短刃"
            "focus": type_name = "法器"
    var lines: Array[String] = [String(item.get("name", "裝備")), "%s · %s" % [type_name, String(item.get("rarity", "普通"))]]
    if item.has("damage"):
        lines.append("傷害：%.1f" % float(item["damage"]))
    if item.has("cooldown"):
        lines.append("攻擊間隔：%.2f 秒" % float(item["cooldown"]))
    if item.has("range"):
        lines.append("射程：%.1f" % float(item["range"]))
    if item.has("crit_chance"):
        lines.append("暴擊率：%.1f%%" % float(item["crit_chance"]))
    if item.has("armor"):
        lines.append("護甲：%.1f" % float(item["armor"]))
    for key in ["prefix", "suffix"]:
        var affix: Dictionary = item.get(key, {})
        if not affix.is_empty():
            lines.append("%s：%s +%s" % ["前綴" if key == "prefix" else "後綴", String(affix.get("stat", "")), str(affix.get("value", ""))])
    for key in ["effect", "description"]:
        if item.has(key) and not String(item[key]).is_empty():
            lines.append(String(item[key]))
    var sockets: Array = item.get("sockets", [])
    var colors := {"red":"紅", "green":"綠", "blue":"藍"}
    lines.append("孔洞：%d / %d" % [sockets.size(), int(item.get("max_sockets", 6 if String(item.get("slot", "")) == "武器" else sockets.size()))])
    for i in range(sockets.size()):
        var socket: Dictionary = sockets[i]
        var gem: Dictionary = socket.get("gem", {})
        var gem_label := "空孔" if gem.is_empty() else "%s UID:%s 精煉+%d" % [String(gem.get("name", "寶石")), str(gem.get("uid", "?")), int(gem.get("refine", 0))]
        lines.append("%d. %s孔 · %s" % [i + 1, String(colors.get(String(socket.get("color", "")), "未知")), gem_label])
    var links: Array = item.get("links", [])
    var connected: Array[String] = []
    for i in range(mini(links.size(), sockets.size() - 1)):
        if bool(links[i]):
            connected.append("%d—%d" % [i + 1, i + 2])
    lines.append("連線：" + ("、".join(connected) if not connected.is_empty() else "無"))
    return "\n".join(lines)

func _center_sockets(card: Control, item: Dictionary) -> void:
    var sockets: Array = item.get("sockets", [])
    var count := sockets.size()
    if count == 0:
        return
    var bounds := card.size
    if bounds.x < 1.0 or bounds.y < 1.0:
        bounds = card.custom_minimum_size
    var columns := 1 if bounds.x < 37.0 or count == 1 else 2
    var rows := ceili(float(count) / float(columns))
    var gap_x := minf(31.0, maxf(12.0, bounds.x - 20.0))
    var gap_y := minf(28.0, maxf(8.0, (bounds.y - 22.0) / float(maxi(1, rows - 1))))
    var center := bounds * 0.5
    var points: Array[Vector2] = []
    for i in range(count):
        var row := i / columns
        var col := i % columns
        if columns == 2 and row % 2 == 1:
            col = 1 - col
        var row_count := mini(columns, count - row * columns)
        var x := center.x if row_count == 1 else center.x + (float(col) - 0.5) * gap_x
        var y := center.y + (float(row) - float(rows - 1) * 0.5) * gap_y
        points.append(Vector2(x, y))
        var dot := card.get_node_or_null("Socket_%d" % i) as Panel
        if dot != null:
            dot.position = points[i] - dot.size * 0.5
    var links: Array = item.get("links", [])
    for i in range(mini(links.size(), count - 1)):
        var connector := card.get_node_or_null("Link_%d" % i) as ColorRect
        if connector == null or not bool(links[i]):
            continue
        var first := points[i]
        var second := points[i + 1]
        var angle := (second - first).angle()
        connector.position = first + Vector2(0.0, -2.0).rotated(angle)
        connector.rotation = angle
        connector.size = Vector2(first.distance_to(second), 4.0)

func debug_interaction_state() -> Dictionary:
    var board := gear_list.get_node_or_null("EquipmentBoard") if gear_list != null else null
    var grid := bag_list.get_node_or_null("UnifiedItemGrid") if bag_list != null else null
    var cards := 0
    if grid != null:
        for placement in _last_pack.get("placements", []):
            if _card_at(String(placement["kind"]), int(placement["index"])) != null:
                cards += 1
    return {"selected_uid":_selected_uid, "selected_kind":_selected_kind, "selected_index":_selected_index, "cards":cards, "forwarders":_drag_forwarders, "tooltip_ready":_tooltip != null, "tooltip_visible":_tooltip != null and _tooltip.visible, "equip_slots":board.get_child_count() if board != null else 0, "grid_ready":grid != null}
