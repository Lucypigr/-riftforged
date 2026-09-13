extends Control
class_name RiftResourceOrb

var _liquid: ColorRect
var _value_label: Label
var _caption_label: Label
var _material: ShaderMaterial
var _current := 0.0
var _maximum := 1.0

func setup(font: FontFile, caption: String, liquid_color: Color) -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE

    _liquid = ColorRect.new()
    _liquid.name = "Liquid"
    _liquid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _liquid.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_liquid)

    var shader := Shader.new()
    shader.code = """
shader_type canvas_item;
uniform float fill_ratio : hint_range(0.0, 1.0) = 1.0;
uniform vec4 liquid_color : source_color = vec4(0.70, 0.08, 0.10, 1.0);
uniform vec4 empty_color : source_color = vec4(0.035, 0.045, 0.065, 1.0);
uniform vec4 rim_color : source_color = vec4(0.30, 0.24, 0.18, 1.0);

void fragment() {
    vec2 p = UV * 2.0 - vec2(1.0);
    float d = length(p);
    if (d > 1.0) {
        COLOR = vec4(0.0);
        return;
    }
    float filled = step(1.0 - fill_ratio, UV.y);
    vec4 base = mix(empty_color, liquid_color, filled);
    float vertical_shade = mix(1.14, 0.70, UV.y);
    base.rgb *= vertical_shade;
    float rim = smoothstep(0.80, 0.98, d);
    base = mix(base, rim_color, rim * 0.90);
    float inner_ring = smoothstep(0.73, 0.79, d) * (1.0 - smoothstep(0.79, 0.85, d));
    base.rgb += vec3(inner_ring * 0.12);
    float gloss = smoothstep(0.30, 0.0, distance(UV, vec2(0.34, 0.28))) * 0.32;
    base.rgb += vec3(gloss);
    base.a = 0.98;
    COLOR = base;
}
"""
    _material = ShaderMaterial.new()
    _material.shader = shader
    _material.set_shader_parameter("liquid_color", liquid_color)
    _material.set_shader_parameter("empty_color", Color(0.025, 0.032, 0.045, 1.0))
    _material.set_shader_parameter("rim_color", Color(0.30, 0.23, 0.14, 1.0))
    _liquid.material = _material

    _caption_label = Label.new()
    _caption_label.name = "Caption"
    _caption_label.text = caption
    _caption_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _caption_label.offset_top = 24
    _caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _caption_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
    _caption_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _caption_label.add_theme_font_override("font", font)
    _caption_label.add_theme_font_size_override("font_size", 13)
    _caption_label.add_theme_color_override("font_color", Color(0.92, 0.84, 0.70))
    add_child(_caption_label)

    _value_label = Label.new()
    _value_label.name = "Value"
    _value_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _value_label.offset_top = 42
    _value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _value_label.add_theme_font_override("font", font)
    _value_label.add_theme_font_size_override("font_size", 15)
    _value_label.add_theme_color_override("font_color", Color.WHITE)
    _value_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.90))
    _value_label.add_theme_constant_override("shadow_offset_x", 1)
    _value_label.add_theme_constant_override("shadow_offset_y", 2)
    add_child(_value_label)

    set_value(1.0, 1.0)

func set_value(current: float, maximum: float) -> void:
    _maximum = maxf(maximum, 0.001)
    _current = clampf(current, 0.0, _maximum)
    if _material != null:
        _material.set_shader_parameter("fill_ratio", _current / _maximum)
    if _value_label != null:
        _value_label.text = "%d / %d" % [int(round(_current)), int(round(_maximum))]

func ratio() -> float:
    return _current / _maximum
