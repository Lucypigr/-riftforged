extends "res://scripts/app_camp.gd"

const LandscapeFitHUD = preload("res://scripts/landscape_fit_hud.gd")

# Reuse the existing gameplay and skill-aim signals. Only replace the HUD
# subclass responsible for geometry on short browser landscape viewports.
func _build_ui() -> void:
    ui = LandscapeFitHUD.new()
    ui.name = "MobileUI"
    add_child(ui)
    ui.setup(ui_font)
    ui.movement_changed.connect(func(value: Vector2): move_input = value)
    ui.attack_requested.connect(_attack)
    var hud := ui as RiftSkillAimHUD
    hud.skill_requested.connect(_use_skill)
    hud.aim_finished.connect(_finish_touch_aim)
    hud.weapon_equip_requested.connect(_equip_weapon_index)
    hud.fullscreen_requested.connect(_toggle_fullscreen)
    hud.set_desktop_mode(desktop_layout_enabled)
    ui.set_hp(player_hp, player_max_hp)
    _apply_runtime_hint()

func _build_camp() -> void:
    super._build_camp()
    # The old 27-unit-wide camp exposed black voids on a wide phone. Extend
    # only visual terrain; keep the original playable camp and walls intact.
    var terrain := BoxMesh.new()
    terrain.size = Vector3(110.0, 0.14, 110.0)
    var surroundings := _camp_mesh(_camp_root, terrain, Vector3(0.0, -0.37, 0.0), Color(0.105, 0.145, 0.12))
    surroundings.name = "CampSurroundings"

# The camp HUD is a separate CanvasLayer rather than a child of MobileUI/Root.
# Always use the same imported Traditional Chinese FontFile as other menus.
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

func _apply_mobile_landscape_touch_overlay() -> void:
    # The inherited legacy pass runs AFTER the V5 layout and moves the big
    # slot-five primary to a hard-coded 82px button. Keep HUD-owned geometry.
    if ui is RiftV5HUD:
        return
    super._apply_mobile_landscape_touch_overlay()

# Pre-CAMP suites enter through the genuine portal with an explicit CLI flag.
# Normal PC/Web/mobile startup always begins in camp.
func _ready() -> void:
    super._ready()
    var legacy_fixture := OS.get_cmdline_user_args().has("--camp01-legacy-combat") or OS.get_cmdline_args().has("--camp01-legacy-combat")
    if legacy_fixture and player != null and _region_state == STATE_CAMP:
        player.global_position = PORTAL_POSITION + Vector3(0.0, 0.0, 1.5)
        _interact_portal()
        print("CAMP01_LEGACY_ARENA_FIXTURE portal=", _portal_uses, " state=", _region_state)
