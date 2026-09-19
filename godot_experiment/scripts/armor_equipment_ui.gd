extends CanvasLayer
class_name RiftArmorEquipmentUI

signal edit_requested(slot: String)
signal equip_requested(index: int)
signal closed

var root: Control
var panel: Panel
var gear_list: VBoxContainer
var bag_list: VBoxContainer
var summary: Label
var _equipped: Dictionary = {}
var _bag: Array[Dictionary] = []

func setup(font: FontFile) -> void:
    layer = 16
    root = Control.new()
    root.name = "ArmorRoot"
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_STOP
    root.theme = RiftFontService.build_theme(font)
    add_child(root)
    var backdrop := ColorRect.new()
    backdrop.name = "Backdrop"
    backdrop.color = Color(0.006, 0.008, 0.012, 0.88)
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
    root.add_child(backdrop)
    panel = Panel.new()
    panel.name = "ArmorPanel"
    panel.add_theme_stylebox_override("panel", _frame(Color(0.031, 0.032, 0.039), Color(0.73, 0.53, 0.27)))
    root.add_child(panel)
    var title := Label.new()
    title.name = "Title"
    title.text = "裝備欄  /  CHARACTER EQUIPMENT"
    title.add_theme_font_size_override("font_size", 20)
    title.add_theme_color_override("font_color", Color(0.96, 0.80, 0.49))
    panel.add_child(title)
    var close_button := Button.new()
    close_button.name = "Close"
    close_button.text = "✕"
    close_button.pressed.connect(close)
    panel.add_child(close_button)
    summary = Label.new()
    summary.name = "Summary"
    summary.add_theme_color_override("font_color", Color(0.82, 0.85, 0.82))
    summary.add_theme_font_size_override("font_size", 13)
    panel.add_child(summary)
    var gear_scroll := ScrollContainer.new()
    gear_scroll.name = "GearScroll"
    gear_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    panel.add_child(gear_scroll)
    gear_list = VBoxContainer.new()
    gear_list.name = "GearList"
    gear_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    gear_list.add_theme_constant_override("separation", 7)
    gear_scroll.add_child(gear_list)
    var bag_scroll := ScrollContainer.new()
    bag_scroll.name = "BagScroll"
    bag_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    panel.add_child(bag_scroll)
    bag_list = VBoxContainer.new()
    bag_list.name = "BagList"
    bag_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    bag_list.add_theme_constant_override("separation", 6)
    bag_scroll.add_child(bag_list)
    get_viewport().size_changed.connect(_layout)
    _layout()
    root.visible = false

func _frame(bg: Color, border: Color) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = bg
    style.border_color = border
    style.set_border_width_all(2)
    style.set_corner_radius_all(5)
    style.set_content_margin_all(5)
    return style

func _layout() -> void:
    if panel == null:
        return
    var size := get_viewport().get_visible_rect().size
    var mobile := size.x < 760
    var width := minf(750.0, size.x - 16.0)
    var height := minf(650.0, size.y - 18.0)
    panel.size = Vector2(width, height)
    panel.position = (size - panel.size) * 0.5
    var title := panel.get_node("Title") as Label
    title.position = Vector2(13, 9)
    title.size = Vector2(width - 66, 30)
    title.add_theme_font_size_override("font_size", 16 if mobile else 20)
    var close_button := panel.get_node("Close") as Button
    close_button.position = Vector2(width - 49, 7)
    close_button.size = Vector2(39, 36)
    summary.position = Vector2(14, 43)
    summary.size = Vector2(width - 28, 25)
    var gear_scroll := panel.get_node("GearScroll") as ScrollContainer
    var bag_scroll := panel.get_node("BagScroll") as ScrollContainer
    if mobile:
        gear_scroll.position = Vector2(12, 76)
        gear_scroll.size = Vector2(width - 24, minf(285.0, (height - 85.0) * 0.48))
        bag_scroll.position = Vector2(12, gear_scroll.position.y + gear_scroll.size.y + 10.0)
        bag_scroll.size = Vector2(width - 24, height - bag_scroll.position.y - 9.0)
    else:
        gear_scroll.position = Vector2(12, 76)
        gear_scroll.size = Vector2((width - 35) * 0.53, height - 86)
        bag_scroll.position = Vector2(gear_scroll.position.x + gear_scroll.size.x + 11.0, 76)
        bag_scroll.size = Vector2(width - bag_scroll.position.x - 12, height - 86)
    gear_list.custom_minimum_size.x = gear_scroll.size.x - 17
    bag_list.custom_minimum_size.x = bag_scroll.size.x - 17
    _render()

func open() -> void:
    root.visible = true
    _render()

func close() -> void:
    if root != null:
        root.visible = false
    closed.emit()

func is_open() -> bool:
    return root != null and root.visible

func set_data(equipped: Dictionary, bag: Array[Dictionary]) -> void:
    _equipped = equipped.duplicate(true)
    _bag = bag.duplicate(true)
    if is_open():
        _render()

func _clear(list: Control) -> void:
    for node in list.get_children():
        list.remove_child(node)
        node.queue_free()

func _render() -> void:
    if gear_list == null or bag_list == null or summary == null:
        return
    _clear(gear_list)
    _clear(bag_list)
    summary.text = "總護甲 %.0f  ·  頭／身／腿／鞋各自開孔、連線與放置寶石" % RiftArmorEquipment.defense(_equipped)
    var equipment_title := Label.new()
    equipment_title.text = "已裝備   EQUIPPED"
    equipment_title.add_theme_color_override("font_color", Color(0.97, 0.77, 0.43))
    gear_list.add_child(equipment_title)
    for slot in RiftArmorEquipment.SLOTS:
        var item: Dictionary = _equipped.get(slot, {})
        var row := VBoxContainer.new()
        row.name = "Gear_" + slot
        row.add_theme_stylebox_override("panel", _frame(Color(0.06, 0.063, 0.073), Color(0.47, 0.35, 0.22)))
        gear_list.add_child(row)
        var name_label := Label.new()
        name_label.text = "%s｜%s  護甲 %.0f" % [slot, String(item.get("name", "未裝備")), float(item.get("armor", 0.0))]
        name_label.add_theme_color_override("font_color", _rarity(String(item.get("rarity", "普通"))))
        name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        row.add_child(name_label)
        var controls := HBoxContainer.new()
        controls.add_theme_constant_override("separation", 5)
        row.add_child(controls)
        var sockets: Array = item.get("sockets", [])
        var links: Array = item.get("links", [])
        for i in range(sockets.size()):
            var socket: Dictionary = sockets[i]
            if i > 0 and i - 1 < links.size() and bool(links[i - 1]):
                var connection := Label.new()
                connection.text = "—"
                connection.add_theme_color_override("font_color", Color(0.88, 0.72, 0.39))
                controls.add_child(connection)
            var gem: Dictionary = socket.get("gem", {})
            var dot := Label.new()
            dot.text = "●" if not gem.is_empty() else "○"
            dot.tooltip_text = String(gem.get("name", "空孔"))
            dot.add_theme_color_override("font_color", _socket_color(String(socket.get("color", "red"))))
            controls.add_child(dot)
        var edit := Button.new()
        edit.name = "Edit_" + slot
        edit.text = "◆ 編輯%s孔洞與寶石  (%d / %d)" % [slot, sockets.size(), int(item.get("max_sockets", 4))]
        edit.custom_minimum_size.y = 38
        edit.pressed.connect(func(target: String = slot): edit_requested.emit(target))
        row.add_child(edit)
    var inventory_title := Label.new()
    inventory_title.text = "護具背包  /  ARMOR BAG · %d 件" % _bag.size()
    inventory_title.add_theme_color_override("font_color", Color(0.97, 0.77, 0.43))
    bag_list.add_child(inventory_title)
    if _bag.is_empty():
        var empty := Label.new()
        empty.text = "擊敗怪物並走近地面裝備，即可撿到頭盔、胸甲、護腿與鞋子。"
        empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        bag_list.add_child(empty)
    for i in range(_bag.size()):
        var item: Dictionary = _bag[i]
        var button := Button.new()
        button.name = "ArmorItem_%d" % i
        button.custom_minimum_size.y = 66
        button.alignment = HORIZONTAL_ALIGNMENT_LEFT
        button.text = "%s｜%s\n護甲 %.0f · %d 孔 · 點擊裝備" % [String(item.get("slot", "")), String(item.get("name", "護具")), float(item.get("armor", 0)), (item.get("sockets", []) as Array).size()]
        button.add_theme_color_override("font_color", _rarity(String(item.get("rarity", "普通"))))
        button.add_theme_stylebox_override("normal", _frame(Color(0.064, 0.069, 0.081), _rarity(String(item.get("rarity", "普通")))))
        button.pressed.connect(func(index: int = i): equip_requested.emit(index))
        bag_list.add_child(button)

func _rarity(rarity: String) -> Color:
    match rarity:
        "稀有": return Color(1.0, 0.85, 0.34)
        "魔法", "精良": return Color(0.46, 0.68, 1.0)
        "史詩": return Color(0.88, 0.52, 1.0)
        "傳說": return Color(1.0, 0.60, 0.25)
    return Color(0.91, 0.91, 0.89)

func _socket_color(color: String) -> Color:
    match color:
        "red": return Color(1.0, 0.36, 0.32)
        "green": return Color(0.42, 0.92, 0.46)
        "blue": return Color(0.39, 0.67, 1.0)
    return Color.WHITE
