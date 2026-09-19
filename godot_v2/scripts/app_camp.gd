extends "res://scripts/app_skill_aim.gd"

# CAMP-01 deliberately keeps one running game instance. Equipment, sockets,
# inventory, gems, currency, drops and enemy/Boss state are never re-created
# when the portal is used. Only the active region's simulation is switched.
const STATE_CAMP := "camp"
const STATE_COMBAT := "combat"
const CAMP_CENTER := Vector3(0.0, 0.0, 196.0)
const CAMP_SPAWN := Vector3(0.0, 0.0, 202.0)
const PORTAL_POSITION := Vector3(0.0, 0.0, 188.0)
const PORTAL_RADIUS := 3.0
const CAMP_SPEED := 6.2

var _region_state := STATE_COMBAT
var _camp_root: Node3D
var _portal_root: Node3D
var _camp_layer: CanvasLayer
var _camp_button: Button
var _camp_caption: Label
var _portal_uses := 0

func _ready() -> void:
    super._ready()
    if player == null or region_map == null or ui == null:
        return
    _build_camp()
    _build_camp_controls()
    _set_region_state(STATE_CAMP)
    player.global_position = CAMP_SPAWN
    _reset_v5_controls()
    _refresh_camp_prompt()

func _camp_material(tint: Color, emission: float = 0.0) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = tint
    material.roughness = 0.91
    if emission > 0.0:
        material.emission_enabled = true
        material.emission = tint
        material.emission_energy_multiplier = emission
    return material

func _camp_mesh(parent: Node3D, shape: Mesh, location: Vector3, tint: Color, emission: float = 0.0) -> MeshInstance3D:
    var visual := MeshInstance3D.new()
    visual.mesh = shape
    visual.position = location
    visual.material_override = _camp_material(tint, emission)
    visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(visual)
    return visual

func _camp_box(parent: Node3D, dimensions: Vector3, location: Vector3, tint: Color, emission: float = 0.0) -> void:
    var shape := BoxMesh.new()
    shape.size = dimensions
    _camp_mesh(parent, shape, location, tint, emission)

func _build_camp() -> void:
    _camp_root = Node3D.new()
    _camp_root.name = "SafeCamp"
    _camp_root.position = CAMP_CENTER
    add_child(_camp_root)
    # All camp positions are relative to CAMP_CENTER. The arena's terrain and
    # encounters remain unmodified at their original region-map coordinates.
    _camp_box(_camp_root, Vector3(27.0, 0.3, 30.0), Vector3(0, -0.15, 0), Color(0.15, 0.21, 0.15))
    var floor_body := StaticBody3D.new()
    floor_body.name = "CampFloorCollision"
    _camp_root.add_child(floor_body)
    var floor_shape := CollisionShape3D.new()
    var floor_box := BoxShape3D.new()
    floor_box.size = Vector3(27.0, 0.3, 30.0)
    floor_shape.shape = floor_box
    floor_shape.position.y = -0.15
    floor_body.add_child(floor_shape)

    # Stone approach, fire pit and several low wall segments establish an
    # unmistakable small fantasy refuge without importing external art.
    for n in range(7):
        _camp_box(_camp_root, Vector3(2.35, 0.075, 1.55), Vector3(sin(float(n) * 0.8) * 0.45, 0.045, 7.3 - float(n) * 2.15), Color(0.34, 0.35, 0.31))
    for n in range(10):
        var angle := float(n) * TAU / 10.0
        _camp_box(_camp_root, Vector3(1.2, 0.28, 0.66), Vector3(-5.0 + cos(angle) * 1.05, 0.14, 5.8 + sin(angle) * 1.05), Color(0.36, 0.31, 0.25))
    var fire := SphereMesh.new()
    fire.radius = 0.55
    fire.height = 1.15
    _camp_mesh(_camp_root, fire, Vector3(-5.0, 0.57, 5.8), Color(1.0, 0.42, 0.09), 3.2)
    var ember := SphereMesh.new()
    ember.radius = 0.29
    ember.height = 0.58
    _camp_mesh(_camp_root, ember, Vector3(-5.0, 1.20, 5.8), Color(1.0, 0.82, 0.25), 3.5)
    for side in [-1.0, 1.0]:
        _camp_box(_camp_root, Vector3(1.3, 1.1, 13.4), Vector3(side * 13.0, 0.36, 0.0), Color(0.23, 0.26, 0.23))
        _camp_box(_camp_root, Vector3(10.0, 0.7, 0.85), Vector3(side * 8.4, 0.30, 13.3), Color(0.27, 0.27, 0.24))
    _camp_box(_camp_root, Vector3(26.0, 0.7, 0.85), Vector3(0.0, 0.30, -13.6), Color(0.27, 0.27, 0.24))

    _portal_root = Node3D.new()
    _portal_root.name = "CombatPortal"
    _portal_root.position = PORTAL_POSITION - CAMP_CENTER
    _camp_root.add_child(_portal_root)
    _camp_box(_portal_root, Vector3(4.0, 0.32, 1.35), Vector3(0, 0.16, 0), Color(0.35, 0.33, 0.40))
    for side in [-1.0, 1.0]:
        _camp_box(_portal_root, Vector3(0.43, 3.5, 0.60), Vector3(side * 1.55, 1.88, 0), Color(0.39, 0.40, 0.51))
        var crystal := SphereMesh.new()
        crystal.radius = 0.24
        crystal.height = 0.48
        _camp_mesh(_portal_root, crystal, Vector3(side * 1.55, 3.74, 0), Color(0.37, 0.84, 1.0), 3.0)
    _camp_box(_portal_root, Vector3(3.55, 0.48, 0.68), Vector3(0, 3.53, 0), Color(0.39, 0.40, 0.51))
    var plane := BoxMesh.new()
    plane.size = Vector3(2.75, 2.93, 0.09)
    var gate := _camp_mesh(_portal_root, plane, Vector3(0, 1.86, 0), Color(0.20, 0.70, 1.0), 2.4)
    var gate_mat := gate.material_override as StandardMaterial3D
    gate_mat.albedo_color.a = 0.69
    gate_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    var portal_name := Label3D.new()
    portal_name.name = "PortalName"
    portal_name.text = "裂隙傳送門"
    portal_name.position = Vector3(0, 4.25, 0)
    portal_name.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    portal_name.font = ui_font
    portal_name.font_size = 32
    portal_name.outline_size = 7
    portal_name.modulate = Color(0.52, 0.91, 1.0)
    _portal_root.add_child(portal_name)
    var camp_name := Label3D.new()
    camp_name.name = "CampName"
    camp_name.text = "旅者營地 · 安全區域"
    camp_name.position = Vector3(-4.0, 2.2, 9.0)
    camp_name.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    camp_name.font = ui_font
    camp_name.font_size = 30
    camp_name.outline_size = 6
    camp_name.modulate = Color(1.0, 0.83, 0.52)
    _camp_root.add_child(camp_name)

func _build_camp_controls() -> void:
    _camp_layer = CanvasLayer.new()
    _camp_layer.name = "CampInteractionHUD"
    _camp_layer.layer = 18
    add_child(_camp_layer)
    var overlay := Control.new()
    overlay.name = "CampOverlay"
    overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _camp_layer.add_child(overlay)
    _camp_caption = Label.new()
    _camp_caption.name = "CampStatus"
    _camp_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _camp_caption.add_theme_font_size_override("font_size", 20)
    _camp_caption.add_theme_color_override("font_color", Color(1.0, 0.86, 0.57))
    _camp_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
    overlay.add_child(_camp_caption)
    _camp_button = Button.new()
    _camp_button.name = "EnterCombatPortal"
    _camp_button.text = "進入裂隙｜F／E"
    _camp_button.focus_mode = Control.FOCUS_NONE
    _camp_button.visible = false
    _camp_button.pressed.connect(_interact_portal)
    overlay.add_child(_camp_button)
    get_viewport().size_changed.connect(_layout_camp_controls, CONNECT_DEFERRED)
    _layout_camp_controls()

func _layout_camp_controls() -> void:
    if _camp_button == null or _camp_caption == null:
        return
    var size := get_viewport().get_visible_rect().size
    _camp_caption.position = Vector2(12.0, minf(size.y * 0.14, 92.0))
    _camp_caption.size = Vector2(maxf(120.0, size.x - 24.0), 32.0)
    _camp_button.size = Vector2(clampf(size.x * 0.35, 120.0, 190.0), clampf(size.y * 0.078, 50.0, 68.0))
    _camp_button.position = Vector2((size.x - _camp_button.size.x) * 0.5, clampf(size.y * 0.70, 132.0, size.y - _camp_button.size.y - 84.0))

func _set_region_state(next_state: String) -> void:
    if next_state not in [STATE_CAMP, STATE_COMBAT]:
        return
    _region_state = next_state
    var in_camp := _region_state == STATE_CAMP
    _camp_root.visible = in_camp
    _camp_layer.visible = in_camp
    region_map.visible = not in_camp
    enemies_root.visible = not in_camp
    projectiles_root.visible = not in_camp
    if loot_root != null:
        loot_root.visible = not in_camp
    if region_map_overlay != null:
        region_map_overlay.visible = not in_camp
    if _boss_layer != null:
        _boss_layer.visible = not in_camp
    mouse_fire_held = false

func _refresh_camp_prompt() -> void:
    if _camp_button == null or player == null:
        return
    var near := _region_state == STATE_CAMP and player.global_position.distance_to(PORTAL_POSITION) <= PORTAL_RADIUS
    _camp_button.visible = near and not _inventory_open()
    if _camp_caption != null:
        _camp_caption.text = "裂隙傳送門｜按 F／E 或點擊進入戰鬥區" if near else "安全營地｜走近藍色傳送門進入戰鬥區"

func _interact_portal() -> void:
    if _region_state != STATE_CAMP or player == null or _inventory_open():
        return
    if player.global_position.distance_to(PORTAL_POSITION) > PORTAL_RADIUS:
        ui.set_hint("請先走近裂隙傳送門。")
        return
    _reset_v5_controls()
    _set_region_state(STATE_COMBAT)
    player.global_position = region_map.spawn_position()
    region_map.update_streaming(player.position)
    _portal_uses += 1
    _camp_button.hide()
    ui.set_hint("已進入裂隙戰鬥區｜裝備、寶石、背包與通貨保持原狀。")
    _refresh_gameplay_ui()

func _physics_process(delta: float) -> void:
    if _region_state != STATE_CAMP:
        super._physics_process(delta)
        return
    if player == null:
        return
    var modal := _inventory_open()
    _set_v5_locked(modal)
    mouse_fire_held = false
    if modal:
        player.velocity = Vector3.ZERO
        _refresh_camp_prompt()
        return
    var keyboard := Vector2.ZERO
    if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): keyboard.x -= 1
    if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): keyboard.x += 1
    if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): keyboard.y -= 1
    if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): keyboard.y += 1
    var motion := move_input if move_input.length() > 0.03 else keyboard.normalized()
    player.velocity = Vector3(motion.x, 0.0, motion.y) * CAMP_SPEED
    player.move_and_slide()
    player.position.x = clampf(player.position.x, -11.5, 11.5)
    player.position.z = clampf(player.position.z, 182.6, 209.0)
    player.position.y = 0.0
    if player_visual != null and absf(motion.x) > 0.05:
        player_visual.flip_h = motion.x < 0.0
    _refresh_camp_prompt()

func _unhandled_input(event: InputEvent) -> void:
    if _region_state != STATE_CAMP or _inventory_open():
        super._unhandled_input(event)
        return
    if event is InputEventKey:
        var key := event as InputEventKey
        if key.pressed and not key.echo and key.keycode in [KEY_F, KEY_E]:
            _interact_portal()
            get_viewport().set_input_as_handled()
            return
        if key.pressed and not key.echo and key.keycode == KEY_F11:
            _toggle_fullscreen()
            get_viewport().set_input_as_handled()
            return
    # No world-click attack, map overlay or skill/flask shortcuts in camp.
    get_viewport().set_input_as_handled()

func _attack() -> void:
    if _region_state == STATE_CAMP:
        return
    super._attack()

func _attack_at_screen(screen_position: Vector2) -> void:
    if _region_state == STATE_CAMP:
        return
    super._attack_at_screen(screen_position)

func _use_skill(slot: int) -> void:
    if _region_state == STATE_CAMP:
        return
    super._use_skill(slot)

func _damage_player(amount: float) -> void:
    if _region_state == STATE_CAMP:
        return
    # Retain the inherited combat-area death/respawn rules unchanged.
    super._damage_player(amount)

func debug_camp_state() -> Dictionary:
    return {"region":_region_state, "camp_visible":_camp_root != null and _camp_root.visible, "arena_visible":region_map != null and region_map.visible, "enemy_count":enemies.size(), "enemy_visible":enemies_root != null and enemies_root.visible, "portal_position":PORTAL_POSITION, "player_position":player.global_position if player != null else Vector3.ZERO, "near_portal":_camp_button != null and _camp_button.visible, "portal_uses":_portal_uses, "interact_button":_camp_button != null, "loot_count":loot_drops.size() + gem_ground.size(), "inventory":weapon_inventory.size() + armor_inventory.size() + gem_inventory.size(), "currency":gem_currency.duplicate(true)}
