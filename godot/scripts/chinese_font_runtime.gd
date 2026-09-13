extends Node

# Stable Traditional Chinese bitmap font for Godot Web/iPhone Safari.
# The atlas is bundled with the project, so the Web build never depends on a
# browser/system CJK font. Text is rendered normally by Godot and is not
# periodically rewritten, which removes the visible flicker from the old fix.

const FONT_SIZE := 24
const FONT_KEY := Vector2i(24, 0)
const CELL_SIZE := Vector2i(30, 34)
const BASELINE := 27.0
const ATLAS_PATH := "res://fonts/rift_ui_tc.png"

const GLYPHS := {
    32:[0,0,15],42:[30,0,28],45:[60,0,28],47:[90,0,28],48:[120,0,28],49:[150,0,28],50:[180,0,28],51:[210,0,28],52:[240,0,28],53:[270,0,28],54:[300,0,28],55:[330,0,28],56:[360,0,28],57:[390,0,28],183:[420,0,28],9670:[450,0,28],9671:[480,0,28],9675:[0,34,28],12290:[30,34,28],19978:[60,34,28],19979:[90,34,28],20027:[120,34,28],20280:[150,34,28],20320:[180,34,28],20491:[210,34,28],20808:[240,34,28],20877:[270,34,28],20998:[300,34,28],21161:[330,34,28],21205:[360,34,28],21253:[390,34,28],21270:[420,34,28],21462:[450,34,28],21482:[480,34,28],21491:[0,68,28],21516:[30,68,28],21534:[60,68,28],21629:[90,68,28],22235:[120,68,28],22312:[150,68,28],22810:[180,68,28],23380:[210,68,28],23433:[240,68,28],23542:[270,68,28],23556:[300,68,28],23700:[330,68,28],24038:[360,68,28],24050:[390,68,28],24310:[420,68,28],24375:[450,68,28],24444:[480,68,28],24460:[0,102,28],24618:[30,102,28],25237:[60,102,28],25342:[90,102,28],25463:[120,102,28],25481:[150,102,28],25802:[180,102,28],25915:[210,102,28],26178:[240,102,28],26283:[270,102,28],26371:[300,102,28],26377:[330,102,28],26410:[360,102,28],27085:[390,102,28],27231:[420,102,28],27492:[450,102,28],27578:[480,102,28],27794:[0,136,28],27934:[30,136,28],28779:[60,136,28],29151:[90,136,28],29190:[120,136,28],29289:[150,136,28],29467:[180,136,28],29560:[210,136,28],29575:[240,136,28],29983:[270,136,28],30142:[300,136,28],30690:[330,136,28],30707:[360,136,28],31227:[390,136,28],31354:[420,136,28],31359:[450,136,28],32005:[480,136,28],32068:[0,170,28],32160:[30,170,28],32203:[60,170,28],32218:[90,170,28],32736:[120,170,28],32972:[150,170,28],33521:[180,170,28],33729:[210,170,28],33853:[240,170,28],33980:[270,170,28],34253:[300,170,28],34987:[330,170,28],35010:[360,170,28],35037:[390,170,28],36493:[420,170,28],36628:[450,170,28],36805:[480,170,28],36879:[0,204,28],36899:[30,204,28],37325:[60,204,28],37782:[90,204,28],38553:[120,204,28],38651:[150,204,28],38684:[180,204,28],40670:[210,204,28],65292:[240,204,28],65306:[270,204,28],65307:[300,204,28]
}

var ui_font: FontFile

func _ready() -> void:
    if not OS.has_feature("web"):
        return
    ui_font = _build_font()
    if ui_font == null:
        push_error("Unable to build bundled Traditional Chinese UI font")
        return
    get_tree().node_added.connect(_on_node_added)
    call_deferred("_apply_current_scene")

func _build_font() -> FontFile:
    var texture := load(ATLAS_PATH) as Texture2D
    if texture == null:
        return null
    var image := texture.get_image()
    if image == null or image.is_empty():
        return null

    var font := FontFile.new()
    font.allow_system_fallback = false
    font.set_texture_image(0, FONT_KEY, 0, image)
    font.set_cache_ascent(0, FONT_SIZE, BASELINE)
    font.set_cache_descent(0, FONT_SIZE, float(CELL_SIZE.y) - BASELINE)
    font.set_cache_scale(0, FONT_SIZE, 1.0)

    for code_variant in GLYPHS.keys():
        var code := int(code_variant)
        var data: Array = GLYPHS[code_variant]
        font.set_glyph_size(0, FONT_KEY, code, Vector2(CELL_SIZE.x, CELL_SIZE.y))
        font.set_glyph_texture_idx(0, FONT_KEY, code, 0)
        font.set_glyph_uv_rect(0, FONT_KEY, code, Rect2(float(data[0]), float(data[1]), float(CELL_SIZE.x), float(CELL_SIZE.y)))
        font.set_glyph_offset(0, FONT_KEY, code, Vector2(0.0, -BASELINE))
        font.set_glyph_advance(0, FONT_SIZE, code, Vector2(float(data[2]), 0.0))
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
