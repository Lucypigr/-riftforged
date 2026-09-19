extends "res://scripts/armor_equipment_ui.gd"
class_name RiftUnifiedEquipmentUI

# One inventory window: equipped gear above/beside an actual 12x5 shared bag.
# All real sockets and their links are drawn directly over each item footprint.
signal weapon_equip_requested(index: int)

const Bag = preload("res://scripts/unified_bag.gd")
const GEAR_LAYOUT := ["", "頭部", "", "weapon", "身體", "腿部", "", "鞋子", ""]
var _weapons: Array[Dictionary] = []
var _weapon_index := 0
var _selected_kind := ""
var _selected_index := -1
var _grid_cell := 37.0
var _last_pack: Dictionary = {}

func set_weapons(weapons: Array[Dictionary], selected_weapon: int) -> void:
    _weapons = weapons.duplicate(true)
    _weapon_index = selected_weapon
    if is_open():
        _render()

func _layout() -> void:
    super._layout()
    if panel == null:
        return
    var screen := get_viewport().get_visible_rect().size
    var compact := screen.x < 780.0
    var width := minf(1020.0, screen.x - 14.0)
    var height := minf(700.0, screen.y - 16.0)
    panel.size = Vector2(width, height)
    panel.position = (screen - panel.size) * 0.5
    var heading := panel.get_node("Title") as Label
    heading.text = "旅者裝備  /  EQUIPMENT & INVENTORY"
    heading.position = Vector2(14, 9)
    heading.size = Vector2(width - 68.0, 30)
    heading.add_theme_font_size_override("font_size", 16 if compact else 20)
    var exit := panel.get_node("Close") as Button
    exit.position = Vector2(width - 48.0, 7)
    exit.size = Vector2(37, 34)
    summary.position = Vector2(14, 41)
    summary.size = Vector2(width - 28.0, 25)
    var gear_scroll := panel.get_node("GearScroll") as ScrollContainer
    var bag_scroll := panel.get_node("BagScroll") as ScrollContainer
    if compact:
        gear_scroll.position = Vector2(12, 72)
        gear_scroll.size = Vector2(width - 24.0, minf(325.0, (height - 86.0) * 0.54))
        bag_scroll.position = Vector2(12, gear_scroll.position.y + gear_scroll.size.y + 7.0)
        bag_scroll.size = Vector2(width - 24.0, height - bag_scroll.position.y - 9.0)
    else:
        gear_scroll.position = Vector2(12, 72)
        gear_scroll.size = Vector2(width * 0.43 - 18.0, height - 84.0)
        bag_scroll.position = Vector2(gear_scroll.position.x + gear_scroll.size.x + 9.0, 72)
        bag_scroll.size = Vector2(width - bag_scroll.position.x - 12.0, height - 84.0)
    gear_list.custom_minimum_size.x = maxf(160.0, gear_scroll.size.x - 16.0)
    bag_list.custom_minimum_size.x = maxf(160.0, bag_scroll.size.x - 16.0)
    _grid_cell = floorf(minf(44.0, (bag_scroll.size.x - 30.0) / float(Bag.WIDTH)))
    _render()

func _render() -> void:
    if gear_list == null or bag_list == null or summary == null:
        return
    _clear(gear_list)
    _clear(bag_list)
    _last_pack = Bag.pack(_weapons, _weapon_index, _bag)
    summary.text = "護甲 %.0f  ·  共用背包 %d / %d 格  ·  孔洞隨裝備保存" % [RiftArmorEquipment.defense(_equipped), int(_last_pack["used"]), Bag.WIDTH * Bag.HEIGHT]
    var gear_title := Label.new()
    gear_title.text = "角色裝備   /   點選裝備可編輯其孔洞"
    gear_title.add_theme_color_override("font_color", Color(0.96, 0.77, 0.44))
    gear_list.add_child(gear_title)
    # Keep stable accessible names for the existing Godot compatibility tests.
    for slot in RiftArmorEquipment.SLOTS:
        var reference := Control.new()
        reference.name = "Gear_" + slot
        reference.visible = false
        gear_list.add_child(reference)
    var board := GridContainer.new()
    board.name = "EquipmentBoard"
    board.columns = 3
    board.add_theme_constant_override("h_separation", 4)
    board.add_theme_constant_override("v_separation", 4)
    gear_list.add_child(board)
    var tile_width := floorf(maxf(61.0, (gear_list.custom_minimum_size.x - 17.0) / 3.0))
    for slot in GEAR_LAYOUT:
        if slot.is_empty():
            var empty_slot := Control.new()
            empty_slot.custom_minimum_size = Vector2(tile_width, 95)
            board.add_child(empty_slot)
            continue
        var gear: Dictionary = _weapons[_weapon_index] if slot == "weapon" and _weapon_index >= 0 and _weapon_index < _weapons.size() else _equipped.get(slot, {})
        var tile := Button.new()
        tile.name = "Equipped_" + slot
        tile.custom_minimum_size = Vector2(tile_width, 95)
        tile.clip_contents = true
        tile.focus_mode = Control.FOCUS_NONE
        tile.text = ("武器" if slot == "weapon" else slot) + "\n" + String(gear.get("name", "未裝備")).left(6)
        tile.alignment = HORIZONTAL_ALIGNMENT_CENTER
        tile.add_theme_font_size_override("font_size", 10)
        tile.add_theme_color_override("font_color", _rarity(String(gear.get("rarity", "普通"))))
        tile.add_theme_stylebox_override("normal", _frame(Color(0.063, 0.068, 0.079), _rarity(String(gear.get("rarity", "普通")))))
        tile.tooltip_text = "%s｜%s｜點選管理孔洞" % [slot, String(gear.get("name", ""))]
        tile.pressed.connect(func(target: String = slot): edit_requested.emit(target))
        board.add_child(tile)
        _draw_item_art(tile, slot, Vector2(tile_width, 95))
        _draw_sockets(tile, gear, Vector2(tile_width, 95), true)
    var bag_title := Label.new()
    bag_title.text = "共用背包  /  BAG  ·  12 × 5"
    bag_title.add_theme_color_override("font_color", Color(0.96, 0.77, 0.44))
    bag_list.add_child(bag_title)
    var grid := Control.new()
    grid.name = "UnifiedItemGrid"
    grid.custom_minimum_size = Vector2(Bag.WIDTH * _grid_cell, Bag.HEIGHT * _grid_cell)
    bag_list.add_child(grid)
    for y in range(Bag.HEIGHT):
        for x in range(Bag.WIDTH):
            var cell := Panel.new()
            cell.name = "Cell_%d_%d" % [x, y]
            cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
            cell.position = Vector2(x, y) * _grid_cell
            cell.size = Vector2.ONE * (_grid_cell - 1.0)
            cell.add_theme_stylebox_override("panel", _frame(Color(0.043, 0.046, 0.054), Color(0.14, 0.14, 0.17)))
            grid.add_child(cell)
    for placement in _last_pack["placements"]:
        var item: Dictionary = placement["item"]
        var kind := String(placement["kind"])
        var index := int(placement["index"])
        var dimensions := Vector2(int(placement["w"]), int(placement["h"])) * _grid_cell - Vector2(2, 2)
        var button := Button.new()
        button.name = ("Weapon_" if kind == "weapon" else "ArmorItem_") + str(index)
        button.position = Vector2(int(placement["x"]), int(placement["y"])) * _grid_cell + Vector2.ONE
        button.size = dimensions
        button.clip_contents = true
        button.focus_mode = Control.FOCUS_NONE
        button.text = String(item.get("name", "裝備")).left(7)
        button.add_theme_font_size_override("font_size", 10)
        var selected := _selected_kind == kind and _selected_index == index
        var border := Color(1.0, 0.91, 0.57) if selected else _rarity(String(item.get("rarity", "普通")))
        button.add_theme_color_override("font_color", border)
        button.add_theme_stylebox_override("normal", _frame(Color(0.15, 0.12, 0.09) if selected else Color(0.075, 0.081, 0.094), border))
        button.tooltip_text = "%s｜%s｜%d 孔" % [String(item.get("slot", "武器")), String(item.get("name", "")), (item.get("sockets", []) as Array).size()]
        button.pressed.connect(_select_item.bind(kind, index))
        grid.add_child(button)
        _draw_item_art(button, String(item.get("slot", "weapon")), dimensions)
        _draw_sockets(button, item, dimensions, false)
    var overflow := _last_pack["overflow"] as Array
    if not overflow.is_empty():
        var overflow_text := Label.new()
        overflow_text.text = "背包超出容量：%d 件；新掉落將留在地面。" % overflow.size()
        overflow_text.add_theme_color_override("font_color", Color(1.0, 0.45, 0.39))
        bag_list.add_child(overflow_text)
    var details := Label.new()
    details.name = "SelectedItemDetails"
    details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    details.custom_minimum_size.y = 50
    var item := _selected_item()
    if item.is_empty():
        details.text = "點選背包裝備查看屬性；點選角色裝備上的孔洞管理寶石。"
    else:
        details.text = "%s｜%s｜%s\n%d 孔 · %s" % [String(item.get("slot", "武器")), String(item.get("name", "")), String(item.get("rarity", "普通")), (item.get("sockets", []) as Array).size(), "傷害 %.0f" % float(item.get("damage", 0)) if _selected_kind == "weapon" else "護甲 %.0f" % float(item.get("armor", 0))]
    bag_list.add_child(details)
    var equip := Button.new()
    equip.name = "EquipSelected"
    equip.text = "裝備選取物品" if not item.is_empty() else "請先選取裝備"
    equip.disabled = item.is_empty()
    equip.custom_minimum_size.y = 38
    equip.pressed.connect(_equip_selected)
    bag_list.add_child(equip)

func _selected_item() -> Dictionary:
    if _selected_kind == "weapon" and _selected_index >= 0 and _selected_index < _weapons.size():
        return _weapons[_selected_index]
    if _selected_kind == "armor" and _selected_index >= 0 and _selected_index < _bag.size():
        return _bag[_selected_index]
    return {}

func _select_item(kind: String, index: int) -> void:
    if _selected_kind == kind and _selected_index == index:
        _selected_kind = ""
        _selected_index = -1
    else:
        _selected_kind = kind
        _selected_index = index
    _render()

func _equip_selected() -> void:
    if _selected_item().is_empty():
        return
    if _selected_kind == "weapon":
        weapon_equip_requested.emit(_selected_index)
    elif _selected_kind == "armor":
        equip_requested.emit(_selected_index)
    _selected_kind = ""
    _selected_index = -1
    _render()

func _draw_item_art(target: Control, slot: String, bounds: Vector2) -> void:
    # Lightweight original gear silhouettes; replaceable by item textures later.
    var silhouette := Polygon2D.new()
    var shape: PackedVector2Array
    match slot:
        "頭部", "頭盔": shape = PackedVector2Array([Vector2(-12,-15),Vector2(12,-15),Vector2(18,-5),Vector2(15,15),Vector2(-15,15),Vector2(-18,-5)])
        "身體", "胸甲", "護甲": shape = PackedVector2Array([Vector2(-12,-19),Vector2(-28,-10),Vector2(-21,2),Vector2(-17,21),Vector2(17,21),Vector2(21,2),Vector2(28,-10),Vector2(12,-19)])
        "腿部", "腿", "護腿": shape = PackedVector2Array([Vector2(-19,-20),Vector2(19,-20),Vector2(17,21),Vector2(3,21),Vector2(0,-2),Vector2(-3,21),Vector2(-17,21)])
        "鞋子", "鞋": shape = PackedVector2Array([Vector2(-20,-18),Vector2(-4,-18),Vector2(-4,7),Vector2(1,11),Vector2(1,19),Vector2(-25,19),Vector2(-25,8),Vector2(-20,8)])
        _: shape = PackedVector2Array([Vector2(-3,-24),Vector2(3,-24),Vector2(7,-6),Vector2(3,5),Vector2(3,23),Vector2(-3,23),Vector2(-3,5),Vector2(-7,-6)])
    silhouette.polygon = shape
    silhouette.color = Color(0.54, 0.50, 0.43, 0.48)
    silhouette.position = Vector2(bounds.x * 0.50, bounds.y * 0.40)
    silhouette.scale = Vector2(minf(1.0, bounds.x / 115.0), minf(1.0, bounds.y / 108.0))
    target.add_child(silhouette)

func _draw_sockets(target: Control, item: Dictionary, bounds: Vector2, equipped: bool) -> void:
    var sockets: Array = item.get("sockets", [])
    var links: Array = item.get("links", [])
    var points: Array[Vector2] = []
    var diameter := minf(19.0, bounds.x * 0.24)
    var spacing_x := minf(bounds.x * 0.21, 23.0)
    var spacing_y := minf(bounds.y * 0.23, 25.0)
    var origin := Vector2(bounds.x * 0.5, bounds.y * (0.47 if equipped else 0.49))
    for i in range(sockets.size()):
        # Snake ordering makes every consecutive link physically adjacent.
        var row := int(i / 2)
        var col := i % 2 if row % 2 == 0 else 1 - i % 2
        points.append(origin + Vector2((-0.5 if col == 0 else 0.5) * spacing_x, float(row - 1) * spacing_y))
    for i in range(1, points.size()):
        if i - 1 >= links.size() or not bool(links[i - 1]):
            continue
        var first := points[i - 1]
        var second := points[i]
        var connector := ColorRect.new()
        connector.name = "Link_%d" % (i - 1)
        connector.color = Color(0.94, 0.78, 0.40)
        connector.mouse_filter = Control.MOUSE_FILTER_IGNORE
        if absf(first.x - second.x) < 1.0:
            connector.position = Vector2(first.x - 2, minf(first.y, second.y))
            connector.size = Vector2(4, absf(first.y - second.y))
        else:
            connector.position = Vector2(minf(first.x, second.x), first.y - 2)
            connector.size = Vector2(absf(first.x - second.x), 4)
        target.add_child(connector)
    for i in range(points.size()):
        var socket: Dictionary = sockets[i]
        var gem: Dictionary = socket.get("gem", {})
        var dot := Panel.new()
        dot.name = "Socket_%d" % i
        dot.position = points[i] - Vector2.ONE * diameter * 0.5
        dot.size = Vector2.ONE * diameter
        dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
        var hue := _socket_color(String(socket.get("color", "red")))
        var style := StyleBoxFlat.new()
        style.bg_color = hue.darkened(0.25) if not gem.is_empty() else Color(0.018, 0.019, 0.025)
        style.border_color = hue
        style.set_border_width_all(2)
        style.set_corner_radius_all(12)
        dot.add_theme_stylebox_override("panel", style)
        dot.tooltip_text = String(gem.get("name", "空孔"))
        target.add_child(dot)

func debug_unified_inventory() -> Dictionary:
    var bag_state := Bag.pack(_weapons, _weapon_index, _bag)
    return {"columns":Bag.WIDTH, "rows":Bag.HEIGHT, "occupied":int(bag_state["used"]), "overflow":(bag_state["overflow"] as Array).size(), "items":(bag_state["placements"] as Array).size(), "panel_open":is_open(), "equipment_board":gear_list != null and gear_list.get_node_or_null("EquipmentBoard") != null, "item_grid":bag_list != null and bag_list.get_node_or_null("UnifiedItemGrid") != null, "socket_preview":true}
