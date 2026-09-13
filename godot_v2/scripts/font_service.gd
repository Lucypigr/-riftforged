extends RefCounted
class_name RiftFontService

const FONT_PATH := "res://fonts/NotoSansCJKtc-Regular.otf"

static func load_ui_font() -> FontFile:
    var font := FontFile.new()
    var err := font.load_dynamic_font(FONT_PATH)
    if err != OK:
        push_error("Riftforged v2: unable to load static Traditional Chinese OTF at %s (error %d)" % [FONT_PATH, err])
        return null
    font.allow_system_fallback = false
    return font

static func build_theme(font: FontFile) -> Theme:
    if font == null:
        return null
    var theme := Theme.new()
    theme.default_font = font
    theme.default_font_size = 17
    return theme
