extends "res://scripts/app_camp.gd"

const ArcTouchHUD = preload("res://scripts/arc_touch_hud.gd")

# Reuse existing gameplay, hotbar and aiming signals: only the touch HUD is
# swapped for a circular, responsive layout with a freely turning thumbstick.
func _build_ui() -> void:
    ui = ArcTouchHUD.new()
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
    var terrain := BoxMesh.new()
    terrain.size = Vector3(110.0, 0.14, 110.0)
    var surroundings := _camp_mesh(_camp_root, terrain, Vector3(0.0, -0.37, 0.0), Color(0.105, 0.145, 0.12))
    surroundings.name = "CampSurroundings"

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
    if ui is RiftV5HUD:
        return
    super._apply_mobile_landscape_touch_overlay()

func _use_skill(slot: int) -> void:
    if _inventory_open():
        return
    var actions := _hotbar_entries()
    if slot < 0 or slot >= actions.size():
        return
    var action: Dictionary = actions[slot]
    # Existing hotbar renders an empty assignment as a nonempty Dictionary
    # with kind="empty"; Dictionary.is_empty() alone misses that placeholder.
    if action.is_empty() or String(action.get("kind", "")) == "empty":
        _open_armor_ui()
        _show_hotbar_page(true)
        ui.set_hint("選擇普攻或已裝備的主動寶石，再選擇快捷欄 %d。" % (slot + 1))
        return
    if _region_state != STATE_CAMP:
        super._use_skill(slot)
        return
    if player == null or _camp_root == null:
        return
    # Safe practice, including large default basic attack: a visible effect
    # with no mana, HP, enemy, loot or inventory change.
    var is_basic := String(action.get("kind", "")) == "basic"
    var gem: Dictionary = action.get("gem", {})
    var direction: Vector3 = _aim_direction if _aim_override else last_aim_direction
    direction.y = 0.0
    if direction.length_squared() < 0.0001:
        direction = Vector3(1.0, 0.0, 0.0)
    direction = direction.normalized()
    last_aim_direction = direction
    var preview := MeshInstance3D.new()
    preview.name = "CampSkillPreview"
    var orb := SphereMesh.new()
    orb.radius = 0.30
    orb.height = 0.60
    preview.mesh = orb
    var material := StandardMaterial3D.new()
    var fire := String(gem.get("id", "")) == "ember_bolt"
    material.albedo_color = Color(1.0, 0.75, 0.30) if is_basic else (Color(1.0, 0.36, 0.09) if fire else Color(0.30, 0.86, 1.0))
    material.emission_enabled = true
    material.emission = material.albedo_color
    material.emission_energy_multiplier = 2.8
    preview.material_override = material
    _camp_root.add_child(preview)
    var start: Vector3 = player.global_position + Vector3(0.0, 1.15, 0.0)
    preview.global_position = start
    var spec: Dictionary = AimRules.descriptor(gem)
    var reach := 2.4 if is_basic else clampf(float(spec.get("range", 0.0)), 1.5, 5.5)
    var tween := create_tween()
    tween.tween_property(preview, "global_position", start + direction * reach, 0.34 if is_basic else 0.42)
    tween.parallel().tween_property(preview, "scale", Vector3.ONE * 0.18, 0.34 if is_basic else 0.42)
    tween.tween_callback(preview.queue_free)
    ui.set_hint("安全營地試放：不耗魔、不造成傷害；通過傳送門後正常戰鬥。")

# Old combat-only suites use an explicit fixture; normal startup is camp.
func _ready() -> void:
    super._ready()
    var legacy_fixture := OS.get_cmdline_user_args().has("--camp01-legacy-combat") or OS.get_cmdline_args().has("--camp01-legacy-combat")
    if legacy_fixture and player != null and _region_state == STATE_CAMP:
        player.global_position = PORTAL_POSITION + Vector3(0.0, 0.0, 1.5)
        _interact_portal()
        print("CAMP01_LEGACY_ARENA_FIXTURE portal=", _portal_uses, " state=", _region_state)
