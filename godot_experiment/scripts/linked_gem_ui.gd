extends CanvasLayer
class_name RiftLinkedGemUI

signal gem_requested(index: int)
signal socket_requested(index: int)
signal currency_requested(kind: String)
signal aura_requested
signal closed

var root: Control
var panel: Panel
var board: Control
var stash_list: VBoxContainer
var currency_grid: GridContainer
var description: Label
var selection_text: Label
var aura_button: Button
var _weapon: Dictionary = {}
var _stash: Array[Dictionary] = []
var _currency: Dictionary = {}
var _selected := -1
var _aura_on := false
var _message := ""

func setup(font: FontFile) -> void:
    layer = 15
    root = Control.new()
    root.name = "LinkedGemRoot"
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_STOP
    root.theme = RiftFontService.build_theme(font)
    add_child(root)

    var backdrop := ColorRect.new()
    backdrop.name = "Backdrop"
    backdrop.color = Color(0.005, 0.010, 0.017, 0.87)
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
    root.add_child(backdrop)

    panel = Panel.new()
    panel.name = "LinkedGemPanel"
    panel.add_theme_stylebox_override("panel", _style(Color(0.055, 0.069, 0.085, 0.99), Color(0.66, 0.49, 0.25), 2, 16))
    root.add_child(panel)

    var close_button := Button.new()
    close_button.name = "Close"
    close_button.text = "✕ 關閉"
    close_button.size = Vector2(92, 39)
    close_button.position = Vector2(0, 5)
    close_button.add_theme_stylebox_override("normal", _style(Color(0.27, 0.13, 0.12), Color(0.53, 0.32, 0.26), 1, 8))
    close_button.pressed.connect(func(): close())
    panel.add_child(close_button)

    var scroll := ScrollContainer.new()
    scroll.name = "Scroll"
    scroll.position = Vector2(16, 48)
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    panel.add_child(scroll)
    var content := VBoxContainer.new()
    content.name = "Content"
    content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content.add_theme_constant_override("separation", 9)
    scroll.add_child(content)

    var title := Label.new()
    title.text = "✦ 裝備孔洞 · 連線寶石"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 23)
    title.add_theme_color_override("font_color", Color(0.95, 0.78, 0.48))
    content.add_child(title)

    var hint := Label.new()
    hint.text = "點背包寶石 → 點同色孔安裝；直接點已插的孔可拔下。未開出的孔不顯示。"
    hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    hint.add_theme_font_size_override("font_size", 13)
    hint.add_theme_color_override("font_color", Color(0.74, 0.82, 0.83))
    content.add_child(hint)

    var weapon_title := Label.new()
    weapon_title.name = "WeaponTitle"
    weapon_title.text = "裝備"
    weapon_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    weapon_title.add_theme_font_size_override("font_size", 18)
    weapon_title.add_theme_color_override("font_color", Color(0.96, 0.84, 0.60))
    content.add_child(weapon_title)

    board = Control.new()
    board.name = "SocketBoard"
    board.custom_minimum_size = Vector2(302, 185)
    board.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    content.add_child(board)

    selection_text = Label.new()
    selection_text.name = "Selection"
    selection_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    selection_text.add_theme_font_size_override("font_size", 14)
    selection_text.add_theme_color_override("font_color", Color(1.0, 0.85, 0.53))
    content.add_child(selection_text)

    description = Label.new()
    description.name = "SkillDescription"
    description.custom_minimum_size.y = 61
    description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    description.add_theme_font_size_override("font_size", 14)
    content.add_child(description)

    var currency_title := Label.new()
    currency_title.text = "通貨工坊 · 消耗通貨修改目前武器"
    currency_title.add_theme_font_size_override("font_size", 17)
    currency_title.add_theme_color_override("font_color", Color(0.91, 0.74, 0.47))
    content.add_child(currency_title)
    currency_grid = GridContainer.new()
    currency_grid.name = "CurrencyGrid"
    currency_grid.columns = 2
    currency_grid.add_theme_constant_override("h_separation", 7)
    currency_grid.add_theme_constant_override("v_separation", 7)
    content.add_child(currency_grid)

    aura_button = Button.new()
    aura_button.name = "AuraToggle"
    aura_button.custom_minimum_size.y = 42
    aura_button.pressed.connect(func(): aura_requested.emit())
    content.add_child(aura_button)

    var stash_title := Label.new()
    stash_title.text = "寶石背包 · 所有寶石統一存放"
    stash_title.add_theme_font_size_override("font_size", 18)
    stash_title.add_theme_color_override("font_color", Color(0.93, 0.78, 0.50))
    content.add_child(stash_title)
    stash_list = VBoxContainer.new()
    stash_list.name = "GemInventory"
    stash_list.add_theme_constant_override("separation", 5)
    content.add_child(stash_list)

    get_viewport().size_changed.connect(_layout)
    _layout()
    root.visible = false

func _layout() -> void:
    if panel == null:
        return
    var viewport_size := get_viewport().get_visible_rect().size
    var width := minf(740.0, viewport_size.x - 16.0)
    var height := minf(670.0, viewport_size.y - 22.0)
    panel.size = Vector2(width, height)
    panel.position = (viewport_size - panel.size) * 0.5
    var close_button := panel.get_node_or_null("Close") as Button
    if close_button != null:
        close_button.position.x = width - 101.0
    var scroll := panel.get_node_or_null("Scroll") as ScrollContainer
    if scroll != null:
        scroll.size = Vector2(width - 32.0, height - 61.0)
        var content := scroll.get_node_or_null("Content") as VBoxContainer
        if content != null:
            content.custom_minimum_size.x = width - 55.0

func open() -> void:
    root.visible = true
    _render()

func close() -> void:
    root.visible = false
    closed.emit()

func is_open() -> bool:
    return root != null and root.visible

func set_data(weapon: Dictionary, stash: Array[Dictionary], currency: Dictionary, selected: int, aura_on: bool, message: String) -> void:
    _weapon = weapon.duplicate(true)
    _stash = stash.duplicate(true)
    _currency = currency.duplicate(true)
    _selected = selected
    _aura_on = aura_on
    _message = message
    if is_open():
        _render()

func _render() -> void:
    if panel == null:
        return
    var title := panel.get_node_or_null("Scroll/Content/WeaponTitle") as Label
    if title != null:
        title.text = "%s｜%d 孔" % [String(_weapon.get("name", "武器")), (_weapon.get("sockets", []) as Array).size()]
    _draw_sockets()
    selection_text.text = _message if not _message.is_empty() else ("已選：%s → 點擊同色孔" % String(_stash[_selected].get("name", "")) if _selected >= 0 and _selected < _stash.size() else "點選寶石可查看技能資訊與選擇安裝")
    _draw_skill_info()
    _draw_currency()
    aura_button.disabled = not RiftLinkedGemSystem.has_aura(_weapon)
    aura_button.text = "湛藍疾行光環：%s（移速 +20%% / 傷害 -15%%）" % ("已啟動 · 點擊關閉" if _aura_on else "已關閉 · 點擊啟動")
    for node in stash_list.get_children():
        node.queue_free()
    if _stash.is_empty():
        var empty := Label.new()
        empty.text = "背包沒有寶石。擊敗怪物後撿取地面發光寶石。"
        stash_list.add_child(empty)
    for i in range(_stash.size()):
        var gem: Dictionary = _stash[i]
        var info := RiftLinkedGemSystem.data(gem)
        var button := Button.new()
        button.name = "Gem_%d" % i
        button.text = "%s %s｜Lv.%d｜精煉 +%d" % ["▶" if i == _selected else "◆", String(gem["name"]), int(gem.get("level", 1)), int(gem.get("refine", 0))]
        button.custom_minimum_size.y = 42
        button.alignment = HORIZONTAL_ALIGNMENT_LEFT
        button.add_theme_color_override("font_color", _color(String(gem.get("color", "red"))))
        button.add_theme_stylebox_override("normal", _style(Color(0.16, 0.19, 0.23) if i == _selected else Color(0.09, 0.12, 0.16), _color(String(gem["color"])), 2 if i == _selected else 1, 7))
        button.tooltip_text = String(info.get("text", ""))
        button.pressed.connect(func(index: int = i): gem_requested.emit(index))
        stash_list.add_child(button)

func _draw_sockets() -> void:
    for node in board.get_children():
        node.queue_free()
    var sockets: Array = _weapon.get("sockets", [])
    var links: Array = _weapon.get("links", [])
    var positions := [Vector2(30, 20), Vector2(116, 20), Vector2(202, 20), Vector2(202, 107), Vector2(116, 107), Vector2(30, 107)]
    for i in range(mini(links.size(), sockets.size() - 1)):
        if not bool(links[i]):
            continue
        var start: Vector2 = positions[i] + Vector2(29, 29)
        var finish: Vector2 = positions[i + 1] + Vector2(29, 29)
        var bar := ColorRect.new()
        bar.color = Color(0.88, 0.72, 0.41)
        bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
        if absf(start.x - finish.x) < 1.0:
            bar.position = Vector2(start.x - 3, minf(start.y, finish.y))
            bar.size = Vector2(6, absf(start.y - finish.y))
        else:
            bar.position = Vector2(minf(start.x, finish.x), start.y - 3)
            bar.size = Vector2(absf(start.x - finish.x), 6)
        board.add_child(bar)
    for i in range(sockets.size()):
        var socket: Dictionary = sockets[i]
        var gem: Dictionary = socket.get("gem", {})
        var socket_color := _color(String(socket.get("color", "red")))
        var button := Button.new()
        button.name = "Socket_%d" % i
        button.position = positions[i]
        button.size = Vector2(58, 58)
        button.text = "◆" if not gem.is_empty() else "◇"
        button.add_theme_font_size_override("font_size", 29)
        button.add_theme_color_override("font_color", socket_color)
        button.add_theme_stylebox_override("normal", _style(Color(0.12, 0.15, 0.20), socket_color, 3, 30))
        button.add_theme_stylebox_override("hover", _style(Color(0.23, 0.28, 0.30), Color.WHITE, 3, 30))
        button.tooltip_text = "%s孔｜%s" % [String(socket.get("color", "")), String(gem.get("name", "空孔 · 點擊安裝"))]
        button.pressed.connect(func(index: int = i): socket_requested.emit(index))
        board.add_child(button)
        var label := Label.new()
        label.position = positions[i] + Vector2(-10, 59)
        label.size = Vector2(78, 21)
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        label.add_theme_font_size_override("font_size", 11)
        label.add_theme_color_override("font_color", socket_color)
        label.text = "%d %s" % [i + 1, String(gem.get("name", "空孔"))]
        label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        board.add_child(label)

func _draw_skill_info() -> void:
    var active_index := RiftLinkedGemSystem.active_socket(_weapon)
    if _selected >= 0 and _selected < _stash.size():
        var selected_gem: Dictionary = _stash[_selected]
        var data := RiftLinkedGemSystem.data(selected_gem)
        description.text = "%s｜標籤 %s\n%s" % [String(selected_gem["name"]), ", ".join(PackedStringArray(data.get("tags", []))), String(data.get("text", ""))]
        return
    if active_index < 0:
        description.text = "尚未安裝攻擊技能寶石。裝備上至少需要一顆攻擊技能寶石。"
        return
    var sockets: Array = _weapon.get("sockets", [])
    var active: Dictionary = sockets[active_index].get("gem", {})
    var supports := RiftLinkedGemSystem.support_ids(_weapon, active_index)
    description.text = "%s｜實際單發傷害 %.1f｜精煉 +%d\n有效連線：%s。無連線或不相容的輔助寶石不生效。" % [String(active["name"]), RiftLinkedGemSystem.skill_damage(_weapon, active_index), int(active.get("refine", 0)), "、".join(PackedStringArray(supports)) if not supports.is_empty() else "無"]

func _draw_currency() -> void:
    for node in currency_grid.get_children():
        node.queue_free()
    for entry in [{"id":"jeweller", "name":"開孔"}, {"id":"fusing", "name":"重連"}, {"id":"chromatic", "name":"洗色"}, {"id":"refine", "name":"精煉選取寶石"}]:
        var key := String(entry["id"])
        var button := Button.new()
        button.name = "Currency_%s" % key
        button.text = "%s × %d" % [String(entry["name"]), int(_currency.get(key, 0))]
        button.custom_minimum_size = Vector2(130, 40)
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.disabled = int(_currency.get(key, 0)) <= 0
        button.add_theme_stylebox_override("normal", _style(Color(0.15, 0.14, 0.11), Color(0.59, 0.46, 0.24), 1, 7))
        button.pressed.connect(func(kind: String = key): currency_requested.emit(kind))
        currency_grid.add_child(button)

func _color(id: String) -> Color:
    match id:
        "red": return Color(1.0, 0.36, 0.32)
        "green": return Color(0.43, 0.94, 0.48)
        "blue": return Color(0.38, 0.70, 1.0)
    return Color.WHITE

func _style(bg: Color, border: Color, thickness: int, radius: int) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = bg
    style.border_color = border
    style.set_border_width_all(thickness)
    style.set_corner_radius_all(radius)
    style.content_margin_left = 6
    style.content_margin_right = 6
    return style
