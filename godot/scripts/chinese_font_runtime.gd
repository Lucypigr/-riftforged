extends Node

# Shared Traditional Chinese UI theme. The real TrueType font is generated
# before Godot import/export; no browser/system CJK fallback or bitmap atlas.
# Load the raw TTF directly so the Web build does not depend on Godot's import
# database recognizing a file that was generated during the current CI run.

const THEME_PATH := "res://themes/rift_ui_theme.tres"
const FONT_PATH := "res://fonts/NotoSansTC-Riftforged.ttf"

var ui_theme: Theme
var ui_font: FontFile

func _ready() -> void:
    ui_font = _build_font()
    ui_theme = load(THEME_PATH) as Theme
    if ui_font == null or ui_theme == null:
        push_error("Unable to load Traditional Chinese UI font/theme")
        return
    ui_theme.default_font = ui_font
    get_tree().node_added.connect(_on_node_added)
    call_deferred("_apply_current_scene")

func _build_font() -> FontFile:
    var font := FontFile.new()
    var err := font.load_dynamic_font(FONT_PATH)
    if err != OK:
        push_error("Unable to load native TTF at %s (error %d)" % [FONT_PATH, err])
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
    if ui_font == null or ui_theme == null:
        return
    if node is Control:
        (node as Control).theme = ui_theme
    elif node is Label3D:
        (node as Label3D).font = ui_font

func debug_font_has_char(code: int) -> bool:
    if ui_font == null:
        ui_font = _build_font()
    return ui_font != null and ui_font.has_char(code)
