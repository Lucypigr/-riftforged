extends Node

# Stable Traditional Chinese bitmap font for Godot Web/iPhone Safari.
# The project ships a tiny BMFont atlas containing only the glyphs currently
# used by the prototype. Because Godot owns the glyph mapping and texture,
# Safari does not need a system CJK fallback. Nothing rewrites label text on a
# timer, so dynamic HP/loot labels stay stable instead of flashing.

const FONT_PATH := "res://fonts/rift_ui_tc.fnt"

var ui_font: FontFile

func _ready() -> void:
    if not OS.has_feature("web"):
        return
    ui_font = _build_font()
    if ui_font == null:
        push_error("Unable to load bundled Traditional Chinese UI font")
        return
    get_tree().node_added.connect(_on_node_added)
    call_deferred("_apply_current_scene")

func _build_font() -> FontFile:
    var font := FontFile.new()
    var err := font.load_bitmap_font(FONT_PATH)
    if err != OK:
        return null
    font.allow_system_fallback = false
    return font

func _apply_current_scene() -> void:
    var scene := get_tree().current_scene
    if scene != null:
        _walk(scene)

func _walk(node: Node) -> void:
    _apply_node(node)
    for child in node.get_children():
        _walk(child)

func _on_node_added(node: Node) -> void:
    _apply_node(node)

func _apply_node(node: Node) -> void:
    if ui_font == null:
        return
    if node is Control:
        (node as Control).add_theme_font_override("font", ui_font)
    elif node is Label3D:
        (node as Label3D).font = ui_font

func debug_font_has_char(code: int) -> bool:
    if ui_font == null:
        ui_font = _build_font()
    return ui_font != null and ui_font.has_char(code)
