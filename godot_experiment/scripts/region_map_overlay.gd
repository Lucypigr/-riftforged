class_name RiftRegionMapOverlay
extends CanvasLayer

signal toggle_requested
signal close_requested

var _font: FontFile
var _region: RiftRegionMap
var _player: CharacterBody3D
var _launcher: Button
var _screen: Control
var _panel: Panel
var _map_area: Control
var _close_button: Button
var _player_marker: Label
var _open := false

func setup(font: FontFile, region: RiftRegionMap, player: CharacterBody3D) -> void:
    _font = font
    _region = region
    _player = player
    layer = 40
    process_mode = Node.PROCESS_MODE_ALWAYS

    _launcher = Button.new()
    _launcher.name = "RegionMapButton"
    _launcher.text = "地圖  M"
    _launcher.focus_mode = Control.FOCUS_NONE
    _launcher.theme = _theme()
    _launcher.add_theme_font_size_override("font_size", 14)
    _launcher.add_theme_stylebox_override("normal", _button_style(Color(0.032, 0.038, 0.050, 0.96), Color(0.46, 0.35, 0.19)))
    _launcher.add_theme_stylebox_override("hover", _button_style(Color(0.075, 0.070, 0.060, 0.99), Color(0.74, 0.55, 0.27)))
    _launcher.add_theme_stylebox_override("pressed", _button_style(Color(0.12, 0.10, 0.07, 1.0), Color(0.88, 0.68, 0.35)))
    _launcher.pressed.connect(func(): toggle_requested.emit())
    add_child(_launcher)

    _screen = Control.new()
    _screen.name = "RegionMapScreen"
    _screen.mouse_filter = Control.MOUSE_FILTER_STOP
    _screen.theme = _theme()
    _screen.visible = false
    add_child(_screen)

    var dim := ColorRect.new()
    dim.name = "Backdrop"
    dim.color = Color(0.006, 0.009, 0.014, 0.94)
    dim.mouse_filter = Control.MOUSE_FILTER_STOP
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _screen.add_child(dim)

    _panel = Panel.new()
    _panel.name = "MapFrame"
    _panel.add_theme_stylebox_override("panel", _panel_style())
    _screen.add_child(_panel)

    var title := Label.new()
    title.name = "Title"
    title.text = "破碎行軍地 · 全區域地圖"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 22)
    title.add_theme_color_override("font_color", Color(0.94, 0.84, 0.62))
    _panel.add_child(title)

    var subtitle := Label.new()
    subtitle.name = "Subtitle"
    subtitle.text = "南方營地 → 森林 → 遺跡 → 沼澤 → 峽谷 → 裂隙區"
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.add_theme_font_size_override("font_size", 13)
    subtitle.add_theme_color_override("font_color", Color(0.70, 0.73, 0.78))
    _panel.add_child(subtitle)

    _map_area = Control.new()
    _map_area.name = "MapArea"
    _map_area.clip_contents = true
    _map_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _panel.add_child(_map_area)

    var footer := Label.new()
    footer.name = "Footer"
    footer.text = "◆ 目前位置   ·   M / Esc 關閉地圖"
    footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    footer.add_theme_font_size_override("font_size", 13)
    footer.add_theme_color_override("font_color", Color(0.84, 0.82, 0.76))
    _panel.add_child(footer)

    _close_button = Button.new()
    _close_button.name = "CloseButton"
    _close_button.text = "關閉"
    _close_button.focus_mode = Control.FOCUS_NONE
    _close_button.add_theme_font_size_override("font_size", 14)
    _close_button.add_theme_stylebox_override("normal", _button_style(Color(0.08, 0.055, 0.045, 0.98), Color(0.56, 0.38, 0.21)))
    _close_button.add_theme_stylebox_override("hover", _button_style(Color(0.13, 0.08, 0.05, 1.0), Color(0.82, 0.58, 0.30)))
    _close_button.pressed.connect(func(): close_requested.emit())
    _panel.add_child(_close_button)

    get_viewport().size_changed.connect(_layout)
    _layout()

func set_open(value: bool) -> void:
    _open = value
    if _screen != null:
        _screen.visible = value
    if _launcher != null:
        _launcher.visible = not value
    if value:
        _layout()
        _rebuild_map()
        _update_player_marker()

func is_open() -> bool:
    return _open

func _process(_delta: float) -> void:
    if _open:
        _update_player_marker()

func _unhandled_input(event: InputEvent) -> void:
    if not _open:
        return
    if event is InputEventKey:
        var key := event as InputEventKey
        if key.pressed and not key.echo and (key.keycode == KEY_M or key.keycode == KEY_ESCAPE):
            close_requested.emit()
            get_viewport().set_input_as_handled()

func _layout() -> void:
    if _screen == null or _panel == null or _map_area == null:
        return
    var size := get_viewport().get_visible_rect().size
    _screen.position = Vector2.ZERO
    _screen.size = size

    _launcher.size = Vector2(86, 38)
    _launcher.position = Vector2(maxf(8.0, size.x - 98.0), 66.0)

    var panel_width := minf(560.0, maxf(300.0, size.x - 24.0))
    var panel_height := minf(760.0, maxf(460.0, size.y - 24.0))
    _panel.size = Vector2(panel_width, panel_height)
    _panel.position = Vector2((size.x - panel_width) * 0.5, (size.y - panel_height) * 0.5)

    var title := _panel.get_node("Title") as Label
    title.position = Vector2(18, 14)
    title.size = Vector2(panel_width - 36, 32)
    var subtitle := _panel.get_node("Subtitle") as Label
    subtitle.position = Vector2(18, 48)
    subtitle.size = Vector2(panel_width - 36, 24)

    _map_area.position = Vector2(28, 80)
    _map_area.size = Vector2(panel_width - 56, panel_height - 138)

    var footer := _panel.get_node("Footer") as Label
    footer.position = Vector2(18, panel_height - 48)
    footer.size = Vector2(panel_width - 112, 30)
    _close_button.size = Vector2(78, 32)
    _close_button.position = Vector2(panel_width - 92, panel_height - 50)

    if _open:
        _rebuild_map()

func _rebuild_map() -> void:
    if _map_area == null or _region == null or _map_area.size.x <= 1.0 or _map_area.size.y <= 1.0:
        return
    for child in _map_area.get_children():
        child.queue_free()

    var zones: Array[Dictionary] = _region.map_zones()
    var zone_colors := [
        Color(0.16, 0.12, 0.075, 0.32),
        Color(0.055, 0.16, 0.075, 0.30),
        Color(0.18, 0.15, 0.11, 0.30),
        Color(0.045, 0.14, 0.14, 0.30),
        Color(0.15, 0.12, 0.10, 0.30),
        Color(0.22, 0.045, 0.075, 0.30),
    ]
    for i in range(zones.size()):
        var zone: Dictionary = zones[i]
        var top := _map_point(Vector3(0, 0, float(zone["north"]))).y
        var bottom := _map_point(Vector3(0, 0, float(zone["south"]))).y
        var band := ColorRect.new()
        band.name = "ZoneBand_%d" % i
        band.color = zone_colors[i % zone_colors.size()]
        band.position = Vector2(0, top)
        band.size = Vector2(_map_area.size.x, maxf(2.0, bottom - top))
        band.mouse_filter = Control.MOUSE_FILTER_IGNORE
        _map_area.add_child(band)

        var zone_label := Label.new()
        zone_label.name = "ZoneLabel_%d" % i
        zone_label.text = String(zone["name"])
        zone_label.position = Vector2(8, top + 4)
        zone_label.size = Vector2(118, 24)
        zone_label.add_theme_font_size_override("font_size", 13)
        zone_label.add_theme_color_override("font_color", Color(0.88, 0.87, 0.80))
        zone_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        _map_area.add_child(zone_label)

    var road := Line2D.new()
    road.name = "MainRoad"
    road.width = 5.0
    road.default_color = Color(0.78, 0.60, 0.32, 0.95)
    road.antialiased = true
    var bounds := _region.map_bounds()
    var north := float(bounds["north"])
    var south := float(bounds["south"])
    var samples := 90
    for i in range(samples + 1):
        var t := float(i) / float(samples)
        var z := lerpf(north, south, t)
        road.add_point(_map_point(Vector3(_region.road_center_x(z), 0, z)))
    _map_area.add_child(road)

    for landmark in _region.map_landmarks():
        var world_position: Vector3 = landmark["position"]
        var marker := Label.new()
        marker.text = "◇ " + String(landmark["name"])
        marker.position = _map_point(world_position) + Vector2(7, -10)
        marker.size = Vector2(170, 22)
        marker.add_theme_font_size_override("font_size", 11)
        marker.add_theme_color_override("font_color", Color(0.90, 0.76, 0.44))
        marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
        _map_area.add_child(marker)

    _player_marker = Label.new()
    _player_marker.name = "PlayerMarker"
    _player_marker.text = "◆"
    _player_marker.size = Vector2(28, 28)
    _player_marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _player_marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _player_marker.add_theme_font_size_override("font_size", 22)
    _player_marker.add_theme_color_override("font_color", Color(1.0, 0.84, 0.20))
    _player_marker.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
    _player_marker.add_theme_constant_override("shadow_offset_x", 2)
    _player_marker.add_theme_constant_override("shadow_offset_y", 2)
    _player_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _map_area.add_child(_player_marker)

func _update_player_marker() -> void:
    if _player_marker == null or not is_instance_valid(_player_marker) or _player == null:
        return
    _player_marker.position = _map_point(_player.global_position) - _player_marker.size * 0.5

func _map_point(world_position: Vector3) -> Vector2:
    var bounds := _region.map_bounds()
    var half_width := float(bounds["half_width"])
    var north := float(bounds["north"])
    var south := float(bounds["south"])
    var u := inverse_lerp(-half_width, half_width, world_position.x)
    var v := inverse_lerp(north, south, world_position.z)
    return Vector2(clampf(u, 0.0, 1.0) * _map_area.size.x, clampf(v, 0.0, 1.0) * _map_area.size.y)

func _theme() -> Theme:
    var theme := Theme.new()
    theme.default_font = _font
    return theme

func _button_style(fill: Color, border: Color) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = fill
    style.border_color = border
    style.border_width_left = 2
    style.border_width_top = 2
    style.border_width_right = 2
    style.border_width_bottom = 2
    style.corner_radius_top_left = 8
    style.corner_radius_top_right = 8
    style.corner_radius_bottom_left = 8
    style.corner_radius_bottom_right = 8
    style.shadow_color = Color(0, 0, 0, 0.65)
    style.shadow_size = 5
    return style

func _panel_style() -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.016, 0.021, 0.029, 0.985)
    style.border_color = Color(0.42, 0.31, 0.17, 0.98)
    style.border_width_left = 2
    style.border_width_top = 2
    style.border_width_right = 2
    style.border_width_bottom = 2
    style.corner_radius_top_left = 14
    style.corner_radius_top_right = 14
    style.corner_radius_bottom_left = 14
    style.corner_radius_bottom_right = 14
    style.shadow_color = Color(0, 0, 0, 0.78)
    style.shadow_size = 14
    return style

func debug_state() -> Dictionary:
    return {
        "open": _open,
        "launcher": _launcher != null,
        "screen": _screen != null,
        "player_marker": _player_marker != null and is_instance_valid(_player_marker),
        "map_size": _map_area.size if _map_area != null else Vector2.ZERO,
    }
