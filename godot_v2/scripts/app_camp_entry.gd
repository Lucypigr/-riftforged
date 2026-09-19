extends "res://scripts/app_camp.gd"

# The camp HUD is a separate CanvasLayer rather than a child of MobileUI/Root.
# Without its own theme it falls back to Godot's default font, which cannot
# reliably render Traditional Chinese on Web and mobile. Always use the same
# imported FontFile as the rest of the game; never load an external TTF here.
func _build_camp_controls() -> void:
    super._build_camp_controls()
    if _camp_layer == null or ui_font == null:
        return
    var overlay := _camp_layer.get_node_or_null("CampOverlay") as Control
    if overlay == null:
        return
    overlay.theme = RiftFontService.build_theme(ui_font)
    _camp_caption.add_theme_font_override("font", ui_font)
    _camp_button.add_theme_font_override("font", ui_font)

# Pre-CAMP suites opt in to the REAL portal transition via an explicit CLI
# flag. Normal PC/Web/mobile startup supplies no flag and always begins in
# camp. CAMP-01 smoke deliberately runs with no fixture flag.
func _ready() -> void:
    super._ready()
    var legacy_fixture := OS.get_cmdline_user_args().has("--camp01-legacy-combat") or OS.get_cmdline_args().has("--camp01-legacy-combat")
    if legacy_fixture and player != null and _region_state == STATE_CAMP:
        player.global_position = PORTAL_POSITION + Vector3(0.0, 0.0, 1.5)
        _interact_portal()
        print("CAMP01_LEGACY_ARENA_FIXTURE portal=", _portal_uses, " state=", _region_state)
