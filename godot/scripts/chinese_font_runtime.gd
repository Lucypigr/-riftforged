extends Node

# Stable Traditional Chinese bitmap font for Godot Web/iPhone Safari.
# The glyph bitmap is embedded as a compact gzip-compressed 1-bit mask, so the
# Web build never depends on browser/system CJK fonts. Text is rendered normally
# by Godot and is never periodically rewritten, eliminating the old flicker.

const FONT_SIZE := 24
const FONT_KEY := Vector2i(24, 0)
const CELL_SIZE := Vector2i(30, 34)
const BASELINE := 27.0
const ATLAS_W := 512
const ATLAS_H := 256
const BITSET_BYTES := ATLAS_W * ATLAS_H / 8

const BITSET_GZIP_B64 := "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";

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
    var compressed := Marshalls.base64_to_raw(BITSET_GZIP_B64)
    var bits := compressed.decompress(BITSET_BYTES, FileAccess.COMPRESSION_GZIP)
    if bits.size() != BITSET_BYTES:
        return null

    var rgba := PackedByteArray()
    rgba.resize(ATLAS_W * ATLAS_H * 4)
    for pixel in range(ATLAS_W * ATLAS_H):
        var mask := 1 << (7 - (pixel & 7))
        if (bits[pixel >> 3] & mask) != 0:
            var offset := pixel * 4
            rgba[offset] = 255
            rgba[offset + 1] = 255
            rgba[offset + 2] = 255
            rgba[offset + 3] = 255

    var image := Image.create_from_data(ATLAS_W, ATLAS_H, false, Image.FORMAT_RGBA8, rgba)
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
