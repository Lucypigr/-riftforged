extends "res://scripts/desktop_gameplay_ui.gd"
class_name RiftPoEInventoryUI

# An original dark-fantasy inventory with item footprints, an equipped weapon
# panel, socket preview, rarity borders, inspection and explicit equip action.
signal socket_edit_requested

const COLS_DESKTOP := 8
const COLS_MOBILE := 5
const BAG_ROWS := 6

var _hotbar: Array[Dictionary] = []
var _items: Array[Dictionary] = []
var _equipped_index := 0
var _inspected_index := -1
var _page := 0
var _poe_root: Control
var _equipped_label: Label
var _equipped_stats: Label
var _socket_preview: Control
var _grid_area: Control
var _page_label: Label
var _details: Label
var _equip_selected: Button
var _previous: Button
var _next: Button
var _socket_edit: Button
var _title: Label
var _bag_title: Label
var _left_frame: Panel
var _right_frame: Panel
var _close_button: Button
var _cell_size := 49.0
var _columns := COLS_DESKTOP

func setup(font: FontFile) -> void:
    super.setup(font)
    for i in range(3, 5):
        var button := Button.new()
        button.name = "SkillButton%d" % i
        button.focus_mode = Control.FOCUS_NONE
        button.z_index = 5
        button.pressed.connect(_request_skill.bind(i))
        root_control.add_child(button)
        skill_buttons.append(button)
    _skill_names = ["", "", "", "", ""]
    _build_inventory()
    _layout()
    set_hotbar_gems([])
    set_flask_charges(_flask_charges)

func _build_inventory() -> void:
    var old_content := equipment_panel.get_node_or_null("Content") as Control
    if old_content != null:
        old_content.visible = false
    equipment_panel.add_theme_stylebox_override("panel", _forged_style(Color(0.021, 0.022, 0.028, 0.99), Color(0.63, 0.47, 0.26), 2, 2))
    _poe_root = Control.new()
    _poe_root.name = "PoEInventory"
    _poe_root.mouse_filter = Control.MOUSE_FILTER_STOP
    equipment_panel.add_child(_poe_root)

    _title = Label.new()
    _title.name = "InventoryTitle"
    _title.text = "旅者軍械庫  /  WEAPON INVENTORY"
    _title.add_theme_font_size_override("font_size", 19)
    _title.add_theme_color_override("font_color", Color(0.96, 0.78, 0.49))
    _poe_root.add_child(_title)
    _close_button = Button.new()
    _close_button.name = "CloseInventory"
    _close_button.text = "✕"
    _close_button.focus_mode = Control.FOCUS_NONE
    _close_button.pressed.connect(func(): equipment_panel.visible = false)
    _poe_root.add_child(_close_button)

    _left_frame = Panel.new()
    _left_frame.name = "EquippedWeapon"
    _left_frame.add_theme_stylebox_override("panel", _forged_style(Color(0.043, 0.048, 0.062), Color(0.48, 0.37, 0.22), 3, 1))
    _poe_root.add_child(_left_frame)
    _equipped_label = Label.new()
    _equipped_label.name = "EquippedName"
    _equipped_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _equipped_label.add_theme_font_size_override("font_size", 16)
    _equipped_label.add_theme_color_override("font_color", Color(0.96, 0.82, 0.54))
    _left_frame.add_child(_equipped_label)
    _equipped_stats = Label.new()
    _equipped_stats.name = "EquippedStats"
    _equipped_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _equipped_stats.add_theme_font_size_override("font_size", 12)
    _left_frame.add_child(_equipped_stats)
    _socket_preview = Control.new()
    _socket_preview.name = "EquippedSockets"
    _left_frame.add_child(_socket_preview)
    _socket_edit = Button.new()
    _socket_edit.name = "SocketEditButton"
    _socket_edit.text = "◆ 孔洞 / 寶石 / 通貨"
    _socket_edit.focus_mode = Control.FOCUS_NONE
    _socket_edit.add_theme_stylebox_override("normal", _forged_style(Color(0.13, 0.09, 0.042), Color(0.74, 0.55, 0.28), 4, 1))
    _socket_edit.pressed.connect(func(): socket_edit_requested.emit())
    _left_frame.add_child(_socket_edit)

    _right_frame = Panel.new()
    _right_frame.name = "Backpack"
    _right_frame.add_theme_stylebox_override("panel", _forged_style(Color(0.035, 0.036, 0.043), Color(0.36, 0.30, 0.22), 3, 1))
    _poe_root.add_child(_right_frame)
    _bag_title = Label.new()
    _bag_title.name = "BackpackTitle"
    _bag_title.text = "背包  /  BAG · 點選查看，按下裝備"
    _bag_title.add_theme_font_size_override("font_size", 14)
    _bag_title.add_theme_color_override("font_color", Color(0.88, 0.76, 0.56))
    _right_frame.add_child(_bag_title)
    _grid_area = Control.new()
    _grid_area.name = "ItemGrid"
    _right_frame.add_child(_grid_area)
    _previous = Button.new()
    _previous.name = "PreviousPage"
    _previous.text = "◀"
    _previous.pressed.connect(func(): _change_page(-1))
    _right_frame.add_child(_previous)
    _page_label = Label.new()
    _page_label.name = "PageText"
    _page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _page_label.add_theme_font_size_override("font_size", 12)
    _right_frame.add_child(_page_label)
    _next = Button.new()
    _next.name = "NextPage"
    _next.text = "▶"
    _next.pressed.connect(func(): _change_page(1))
    _right_frame.add_child(_next)
    _details = Label.new()
    _details.name = "WeaponDetails"
    _details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _details.add_theme_font_size_override("font_size", 12)
    _right_frame.add_child(_details)
    _equip_selected = Button.new()
    _equip_selected.name = "EquipSelected"
    _equip_selected.text = "裝備選取武器"
    _equip_selected.focus_mode = Control.FOCUS_NONE
    _equip_selected.add_theme_stylebox_override("normal", _forged_style(Color(0.14, 0.10, 0.045), Color(0.82, 0.58, 0.24), 4, 1))
    _equip_selected.pressed.connect(_equip_inspected)
    _right_frame.add_child(_equip_selected)

func _layout() -> void:
    super._layout()
    _layout_inventory()

func _apply_skill_frame_styles(mobile: bool) -> void:
    for i in range(skill_buttons.size()):
        var button := skill_buttons[i]
        var active := i < _hotbar.size() and not _hotbar[i].is_empty()
        button.visible = true
        button.z_index = 5
        button.add_theme_font_size_override("font_size", 12 if mobile else 13)
        button.add_theme_constant_override("icon_max_width", 26 if mobile else 34)
        button.add_theme_color_override("font_color", Color(0.98, 0.88, 0.69))
        button.add_theme_color_override("font_disabled_color", Color(0.43, 0.43, 0.45))
        button.add_theme_stylebox_override("normal", _forged_style(Color(0.08, 0.10, 0.12) if active else Color(0.026, 0.027, 0.033), Color(0.69, 0.48, 0.22) if active else Color(0.25, 0.25, 0.27), 5, 2))
        button.add_theme_stylebox_override("hover", _forged_style(Color(0.18, 0.15, 0.10), Color(0.94, 0.76, 0.37), 5, 2))
        button.add_theme_stylebox_override("pressed", _forged_style(Color(0.25, 0.17, 0.08), Color(1.0, 0.82, 0.45), 5, 2))
        button.add_theme_stylebox_override("disabled", _forged_style(Color(0.025, 0.026, 0.030), Color(0.21, 0.21, 0.24), 5, 1))

func _layout_desktop(size: Vector2) -> void:
    super._layout_desktop(size)
    if basic_attack_slot == null:
        return
    var gap := 7.0
    var basic_width := 100.0
    var skill_width := 84.0
    var total := basic_width + 5.0 * skill_width + 5.0 * gap
    var start := (size.x - total) * 0.5
    var y := size.y - 104.0
    basic_attack_slot.position = Vector2(start, y)
    basic_attack_slot.size = Vector2(basic_width, 78)
    basic_attack_icon.size = Vector2(50, 49)
    var basic_label := basic_attack_slot.get_node_or_null("Label") as Label
    if basic_label != null:
        basic_label.text = "左鍵 · 普攻"
        basic_label.position = Vector2(3, 54)
        basic_label.size = Vector2(basic_width - 6.0, 21)
    for i in range(skill_buttons.size()):
        skill_buttons[i].size = Vector2(skill_width, 78)
        skill_buttons[i].position = Vector2(start + basic_width + gap + float(i) * (skill_width + gap), y)
    action_dock.size = Vector2(total + 28.0, 116.0)
    action_dock.position = Vector2(start - 14.0, size.y - 126.0)

func _layout_mobile_portrait(size: Vector2) -> void:
    super._layout_mobile_portrait(size)
    var gap := 5.0
    var width := minf(62.0, (size.x - 36.0 - 4.0 * gap) / 5.0)
    var total := 5.0 * width + 4.0 * gap
    var x := (size.x - total) * 0.5
    var y := size.y - 239.0
    for i in range(skill_buttons.size()):
        skill_buttons[i].size = Vector2(width, 68)
        skill_buttons[i].position = Vector2(x + float(i) * (width + gap), y)
    action_dock.size = Vector2(total + 16.0, 82.0)
    action_dock.position = Vector2(x - 8.0, y - 7.0)

func set_hotbar_gems(gems: Array[Dictionary]) -> void:
    _hotbar = gems.duplicate(true)
    _skill_names.clear()
    for i in range(5):
        var entry: Dictionary = gems[i] if i < gems.size() else {}
        var gem: Dictionary = entry.get("gem", {})
        _skill_names.append(String(gem.get("name", "")))
        if i >= skill_buttons.size():
            continue
        var button := skill_buttons[i]
        var id := String(gem.get("id", ""))
        button.icon = null
        if id == "ember_bolt":
            button.icon = SKILL_ICONS[0]
        elif id == "crimson_burst":
            button.icon = SKILL_ICONS[1]
        elif id == "rift_trail" or id == "rift_dash" or id == "swift_aura":
            button.icon = SKILL_ICONS[2]
        button.expand_icon = id != ""
        button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
        button.tooltip_text = String(gem.get("name", "空技能欄：先在武器裝入主動寶石"))
    _apply_skill_frame_styles(not desktop_mode)

func set_skill_names(names: Array[String]) -> void:
    # The inherited demo still pushes three old names during refresh; the
    # active-gem hotbar replaces all five after the runtime gathers sockets.
    _skill_names = names.duplicate()

func set_skill_cooldowns(cooldowns: Array[float]) -> void:
    for i in range(skill_buttons.size()):
        var active := i < _hotbar.size() and not _hotbar[i].is_empty()
        var remaining := cooldowns[i] if i < cooldowns.size() else 0.0
        var button := skill_buttons[i]
        button.disabled = not active or remaining > 0.05
        button.text = "%d\n%s%s" % [i + 1, _skill_names[i] if active and i < _skill_names.size() else "", "\n%.1f" % remaining if active and remaining > 0.05 else ""]

func set_flask_charges(charges: Array[int]) -> void:
    _flask_charges = charges.duplicate()
    for i in range(mini(flask_buttons.size(), _flask_charges.size())):
        flask_buttons[i].text = "%s\n%s ×%d" % ["Q" if i == 0 else "E", "生命藥水" if i == 0 else "魔力藥水", _flask_charges[i]]
        flask_buttons[i].disabled = _flask_charges[i] <= 0

func set_equipped_weapon_index(index: int) -> void:
    _equipped_index = index

func set_weapon_inventory(items: Array[Dictionary], equipped_name: String) -> void:
    _items = items.duplicate(true)
    if _inspected_index >= _items.size() or _inspected_index == _equipped_index:
        _inspected_index = -1
    _render_inventory()

func _layout_inventory() -> void:
    if _poe_root == null or equipment_panel == null:
        return
    var size := get_viewport().get_visible_rect().size
    var mobile := not desktop_mode or size.x < 850.0
    var width := minf(790.0, size.x - 18.0)
    var height := minf(680.0 if mobile else 586.0, size.y - 88.0)
    equipment_panel.size = Vector2(width, height)
    equipment_panel.position = (size - equipment_panel.size) * 0.5
    _poe_root.position = Vector2.ZERO
    _poe_root.size = equipment_panel.size
    _title.position = Vector2(17, 12)
    _title.size = Vector2(width - 76.0, 28)
    _title.add_theme_font_size_override("font_size", 15 if mobile else 19)
    _close_button.position = Vector2(width - 52.0, 8)
    _close_button.size = Vector2(40, 34)
    _columns = COLS_MOBILE if mobile else COLS_DESKTOP
    if mobile:
        _left_frame.position = Vector2(10, 49)
        _left_frame.size = Vector2(width - 20.0, 137)
        _right_frame.position = Vector2(10, 193)
        _right_frame.size = Vector2(width - 20.0, height - 202.0)
    else:
        _left_frame.position = Vector2(11, 52)
        _left_frame.size = Vector2(245, height - 64.0)
        _right_frame.position = Vector2(264, 52)
        _right_frame.size = Vector2(width - 275.0, height - 64.0)
    _equipped_label.position = Vector2(12, 9)
    _equipped_label.size = Vector2(_left_frame.size.x - 24.0, 42 if mobile else 74)
    _equipped_stats.position = Vector2(12, 51 if mobile else 97)
    _equipped_stats.size = Vector2(_left_frame.size.x - 24.0, 30 if mobile else 104)
    _socket_preview.position = Vector2(12, 86 if mobile else 226)
    _socket_preview.size = Vector2(_left_frame.size.x - 24.0, 24)
    _socket_edit.position = Vector2(10, _left_frame.size.y - 41.0)
    _socket_edit.size = Vector2(_left_frame.size.x - 20.0, 32)
    _bag_title.position = Vector2(10, 8)
    _bag_title.size = Vector2(_right_frame.size.x - 20.0, 26)
    var available := _right_frame.size.x - 24.0
    _cell_size = floorf(minf(53.0, available / float(_columns)))
    _grid_area.size = Vector2(float(_columns) * _cell_size, float(BAG_ROWS) * _cell_size)
    _grid_area.position = Vector2((_right_frame.size.x - _grid_area.size.x) * 0.5, 38)
    var nav_y := _grid_area.position.y + _grid_area.size.y + 5.0
    _previous.position = Vector2(12, nav_y)
    _previous.size = Vector2(40, 30)
    _page_label.position = Vector2(56, nav_y + 4)
    _page_label.size = Vector2(_right_frame.size.x - 112, 22)
    _next.position = Vector2(_right_frame.size.x - 52, nav_y)
    _next.size = Vector2(40, 30)
    _details.position = Vector2(12, nav_y + 34)
    _details.size = Vector2(_right_frame.size.x - 24.0, maxf(30, _right_frame.size.y - (nav_y + 81)))
    _equip_selected.position = Vector2(12, _right_frame.size.y - 40)
    _equip_selected.size = Vector2(_right_frame.size.x - 24, 32)
    _render_inventory()

func _render_inventory() -> void:
    if _poe_root == null or _grid_area == null:
        return
    var equipped: Dictionary = _items[_equipped_index] if _equipped_index >= 0 and _equipped_index < _items.size() else {}
    _equipped_label.text = "裝備中  /  %s\n%s" % [String(equipped.get("rarity", "普通")), String(equipped.get("name", "無武器"))]
    _equipped_label.add_theme_color_override("font_color", _rarity(String(equipped.get("rarity", "普通"))))
    _equipped_stats.text = "傷害 %.0f  ·  攻速 %.2fs\n射程 %.1f  ·  開孔 %d / 6" % [float(equipped.get("damage", 0.0)), float(equipped.get("cooldown", 0.0)), float(equipped.get("range", 0.0)), (equipped.get("sockets", []) as Array).size()]
    _draw_preview(equipped)
    _render_grid()

func _draw_preview(weapon: Dictionary) -> void:
    for child in _socket_preview.get_children():
        _socket_preview.remove_child(child)
        child.queue_free()
    var sockets: Array = weapon.get("sockets", [])
    var links: Array = weapon.get("links", [])
    for i in range(sockets.size()):
        var x := float(i) * 30.0
        if i > 0 and i - 1 < links.size() and bool(links[i - 1]):
            var connector := ColorRect.new()
            connector.color = Color(0.77, 0.66, 0.39)
            connector.position = Vector2(x - 11, 10)
            connector.size = Vector2(12, 3)
            connector.mouse_filter = Control.MOUSE_FILTER_IGNORE
            _socket_preview.add_child(connector)
        var socket: Dictionary = sockets[i]
        var dot := Panel.new()
        dot.position = Vector2(x, 0)
        dot.size = Vector2(23, 23)
        var gem: Dictionary = socket.get("gem", {})
        dot.add_theme_stylebox_override("panel", _forged_style(Color(0.16, 0.17, 0.18) if gem.is_empty() else _socket_color(String(socket.get("color", "red"))).darkened(0.32), _socket_color(String(socket.get("color", "red"))), 12, 2))
        dot.tooltip_text = String(gem.get("name", "空孔"))
        _socket_preview.add_child(dot)

func _render_grid() -> void:
    for child in _grid_area.get_children():
        _grid_area.remove_child(child)
        child.queue_free()
    var pages := _pack_pages()
    _page = clampi(_page, 0, pages.size() - 1)
    var placements: Array = pages[_page]
    for y in range(BAG_ROWS):
        for x in range(_columns):
            var cell := Panel.new()
            cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
            cell.position = Vector2(float(x) * _cell_size, float(y) * _cell_size)
            cell.size = Vector2(_cell_size - 1, _cell_size - 1)
            cell.add_theme_stylebox_override("panel", _forged_style(Color(0.051, 0.053, 0.061), Color(0.16, 0.16, 0.18), 0, 1))
            _grid_area.add_child(cell)
    for placement in placements:
        var index := int(placement["index"])
        var item: Dictionary = _items[index]
        var selected := index == _inspected_index
        var button := Button.new()
        button.name = "Weapon_%d" % index
        button.position = Vector2(float(placement["x"]) * _cell_size + 1, float(placement["y"]) * _cell_size + 1)
        button.size = Vector2(float(placement["w"]) * _cell_size - 3, float(placement["h"]) * _cell_size - 3)
        button.text = "⚔\n%s\n%.0f 傷" % [String(item.get("name", "武器")), float(item.get("damage", 0.0))]
        button.add_theme_font_size_override("font_size", 11)
        button.add_theme_color_override("font_color", _rarity(String(item.get("rarity", "普通"))))
        button.add_theme_stylebox_override("normal", _forged_style(Color(0.19, 0.16, 0.11) if selected else Color(0.09, 0.10, 0.13), Color(0.98, 0.81, 0.44) if selected else _rarity(String(item.get("rarity", "普通"))), 2, 2))
        button.tooltip_text = "%s｜傷害 %.0f｜攻速 %.2fs｜點選查看" % [String(item.get("name", "")), float(item.get("damage", 0)), float(item.get("cooldown", 0))]
        button.pressed.connect(_inspect_weapon.bind(index))
        _grid_area.add_child(button)
    _page_label.text = "背包 %d / %d  ·  %d 件" % [_page + 1, pages.size(), maxi(0, _items.size() - 1)]
    _previous.disabled = _page == 0
    _next.disabled = _page >= pages.size() - 1
    if _inspected_index >= 0 and _inspected_index < _items.size() and _inspected_index != _equipped_index:
        var selected: Dictionary = _items[_inspected_index]
        _details.text = "%s  ·  %s\n傷害 %.0f / 攻速 %.2fs / 射程 %.1f / %d 孔" % [String(selected.get("rarity", "普通")), String(selected.get("name", "武器")), float(selected.get("damage", 0)), float(selected.get("cooldown", 0)), float(selected.get("range", 0)), (selected.get("sockets", []) as Array).size()]
        _details.add_theme_color_override("font_color", _rarity(String(selected.get("rarity", "普通"))))
    else:
        _details.text = "點選背包武器查看屬性。裝備後可編輯已開啟的孔洞與寶石。"
    _equip_selected.disabled = _inspected_index < 0 or _inspected_index == _equipped_index

func _pack_pages() -> Array:
    var pages: Array = []
    var placements: Array = []
    var occupied: Array = []
    occupied.resize(_columns * BAG_ROWS)
    occupied.fill(false)
    for index in range(_items.size()):
        if index == _equipped_index:
            continue
        var dims := _footprint(_items[index])
        var found := false
        for y in range(BAG_ROWS - dims.y + 1):
            for x in range(_columns - dims.x + 1):
                if _fits(occupied, x, y, dims.x, dims.y):
                    _occupy(occupied, x, y, dims.x, dims.y)
                    placements.append({"index": index, "x": x, "y": y, "w": dims.x, "h": dims.y})
                    found = true
                    break
            if found:
                break
        if not found:
            pages.append(placements)
            placements = []
            occupied = []
            occupied.resize(_columns * BAG_ROWS)
            occupied.fill(false)
            _occupy(occupied, 0, 0, dims.x, dims.y)
            placements.append({"index": index, "x": 0, "y": 0, "w": dims.x, "h": dims.y})
    pages.append(placements)
    return pages

func _footprint(item: Dictionary) -> Vector2i:
    match String(item.get("weapon_type", "")):
        "blade": return Vector2i(1, 3)
        "focus": return Vector2i(2, 2)
    return Vector2i(2, 3)

func _fits(occupied: Array, x: int, y: int, w: int, h: int) -> bool:
    for cy in range(y, y + h):
        for cx in range(x, x + w):
            if bool(occupied[cy * _columns + cx]):
                return false
    return true

func _occupy(occupied: Array, x: int, y: int, w: int, h: int) -> void:
    for cy in range(y, y + h):
        for cx in range(x, x + w):
            occupied[cy * _columns + cx] = true

func _inspect_weapon(index: int) -> void:
    if index < 0 or index >= _items.size() or index == _equipped_index:
        return
    _inspected_index = index
    _render_grid()

func _equip_inspected() -> void:
    if _inspected_index >= 0 and _inspected_index < _items.size() and _inspected_index != _equipped_index:
        weapon_equip_requested.emit(_inspected_index)
        _inspected_index = -1

func _change_page(offset: int) -> void:
    _page = maxi(0, _page + offset)
    _inspected_index = -1
    _render_grid()

func _toggle_equipment_panel() -> void:
    super._toggle_equipment_panel()
    if equipment_panel.visible:
        _render_inventory()

func _rarity(label: String) -> Color:
    match label:
        "傳說", "獨特": return Color(1.0, 0.59, 0.22)
        "史詩": return Color(0.84, 0.47, 1.0)
        "稀有": return Color(1.0, 0.87, 0.34)
        "精良", "魔法": return Color(0.46, 0.67, 1.0)
    return Color(0.90, 0.91, 0.92)

func _socket_color(id: String) -> Color:
    match id:
        "red": return Color(1.0, 0.36, 0.32)
        "green": return Color(0.42, 0.91, 0.46)
        "blue": return Color(0.37, 0.65, 1.0)
    return Color.WHITE

func debug_inventory_ui() -> Dictionary:
    var pages := _pack_pages()
    return {"columns": _columns, "rows": BAG_ROWS, "pages": pages.size(), "page": _page, "equipped_index": _equipped_index, "visible_items": (pages[_page] as Array).size(), "grid_ready": _grid_area != null, "skill_buttons": skill_buttons.size(), "active_skill_slots": _hotbar.size()}
