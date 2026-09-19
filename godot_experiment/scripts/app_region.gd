extends "res://scripts/app_arpg_hud.gd"

const RegionMapScript = preload("res://scripts/region_map.gd")
const RegionMapOverlayScript = preload("res://scripts/region_map_overlay.gd")

var region_map: RiftRegionMap
var region_map_overlay: RiftRegionMapOverlay
var _terrain_visibility_stabilized := false

func _ready() -> void:
    super._ready()
    if region_map != null and player != null and ui_font != null:
        region_map_overlay = RegionMapOverlayScript.new() as RiftRegionMapOverlay
        region_map_overlay.name = "RegionMapOverlay"
        add_child(region_map_overlay)
        region_map_overlay.setup(ui_font, region_map, player)
        region_map_overlay.toggle_requested.connect(_toggle_region_map)
        region_map_overlay.close_requested.connect(_close_region_map)

func _build_world() -> void:
    var environment_node := WorldEnvironment.new()
    environment_node.name = "WorldEnvironment"
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color(0.035, 0.045, 0.055)
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.62, 0.68, 0.72)
    environment.ambient_light_energy = 0.88
    environment_node.environment = environment
    add_child(environment_node)

    var light := DirectionalLight3D.new()
    light.name = "RegionLight"
    light.rotation_degrees = Vector3(-58, -34, 0)
    light.light_color = Color(1.0, 0.94, 0.84)
    light.light_energy = 1.22
    light.shadow_enabled = false
    add_child(light)

    region_map = RegionMapScript.new()
    add_child(region_map)
    region_map.build()
    _stabilize_region_surface_materials()
    region_map.exit_reached.connect(_on_region_exit_reached)

# The procedural terrain/road triangles are generated at runtime. On the Web
# Compatibility renderer a back-facing procedural surface can be culled before
# its vertex colour ever reaches the screen, which looks exactly like a black
# ground because only the dark world background remains. Terrain and road are
# deliberately two-sided and unshaded: their authored vertex/albedo colours are
# now renderer-independent while props/enemies keep normal scene lighting.
func _stabilize_region_surface_materials() -> void:
    _terrain_visibility_stabilized = false
    if region_map == null:
        return
    var chunk_root := region_map.get_node_or_null("TerrainChunks")
    if chunk_root == null:
        return

    var terrain_fixed := false
    var road_fixed := false
    for chunk in chunk_root.get_children():
        for child in chunk.get_children():
            var mesh_instance := child as MeshInstance3D
            if mesh_instance == null or mesh_instance.mesh == null or mesh_instance.mesh.get_surface_count() < 1:
                continue
            var material := mesh_instance.mesh.surface_get_material(0) as BaseMaterial3D
            if material == null:
                continue
            var node_name := String(mesh_instance.name)
            if node_name.begins_with("Terrain_"):
                material.cull_mode = BaseMaterial3D.CULL_DISABLED
                material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
                terrain_fixed = true
            elif node_name.begins_with("Road_"):
                material.cull_mode = BaseMaterial3D.CULL_DISABLED
                material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
                road_fixed = true

    _terrain_visibility_stabilized = terrain_fixed and road_fixed

func _build_player() -> void:
    super._build_player()
    if region_map != null:
        player.position = region_map.spawn_position()

func _spawn_enemy(force_elite: bool = false, slot: int = -1) -> void:
    super._spawn_enemy(force_elite, slot)
    if region_map == null or enemies.is_empty():
        return
    var entry: Dictionary = enemies[enemies.size() - 1]
    var enemy := entry["node"] as CharacterBody3D
    if is_instance_valid(enemy):
        enemy.position = region_map.enemy_spawn_position(maxi(slot, 0), enemy_serial, force_elite)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey:
        var key := event as InputEventKey
        if key.pressed and not key.echo and key.keycode == KEY_M:
            _toggle_region_map()
            get_viewport().set_input_as_handled()
            return
        if _is_region_map_open() and key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
            _close_region_map()
            get_viewport().set_input_as_handled()
            return
    if _is_region_map_open():
        get_viewport().set_input_as_handled()
        return
    super._unhandled_input(event)

# Region 01 owns its world bounds and terrain stream while preserving all higher
# level ARPG ticks inherited from the older arena runtime.
func _physics_process(delta: float) -> void:
    if player == null:
        return
    if _is_region_map_open():
        player.velocity = Vector3.ZERO
        return

    player_mana = minf(player_max_mana, player_mana + MANA_REGEN_PER_SECOND * delta)
    _resource_ui_accumulator += delta

    for i in range(skill_cooldowns.size()):
        skill_cooldowns[i] = maxf(0.0, skill_cooldowns[i] - delta)
    _skill_ui_accumulator += delta

    attack_cooldown = maxf(0.0, attack_cooldown - delta)
    var keyboard := Vector2.ZERO
    if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): keyboard.x -= 1
    if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): keyboard.x += 1
    if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): keyboard.y -= 1
    if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): keyboard.y += 1
    keyboard = keyboard.normalized()

    var input_vector := move_input if move_input.length() > 0.03 else keyboard
    player.velocity = Vector3(input_vector.x, 0, input_vector.y) * PLAYER_SPEED
    player.move_and_slide()
    if region_map != null:
        player.position = region_map.clamp_player(player.position)
        region_map.update_streaming(player.position)
    if player_visual != null and absf(input_vector.x) > 0.05:
        player_visual.flip_h = input_vector.x < 0.0

    _update_enemies(delta)
    _snap_region_enemies_to_surface()
    _update_loot()
    _update_label_visibility()
    if mouse_fire_held and attack_cooldown <= 0.0:
        _attack_at_screen(mouse_fire_position)

    if _skill_ui_accumulator >= 0.10:
        _skill_ui_accumulator = 0.0
        var gameplay_ui := ui as RiftGameplayUI
        if gameplay_ui != null:
            gameplay_ui.set_skill_cooldowns(skill_cooldowns)

    if _resource_ui_accumulator >= 0.10:
        _resource_ui_accumulator = 0.0
        _refresh_resource_hud()

func _snap_region_enemies_to_surface() -> void:
    if region_map == null:
        return
    for entry_value in enemies:
        var entry := entry_value as Dictionary
        var enemy := entry.get("node") as CharacterBody3D
        if not is_instance_valid(enemy):
            continue
        var pos := enemy.position
        pos.y = region_map.surface_height(pos.x, pos.z)
        enemy.position = pos

func _toggle_region_map() -> void:
    if region_map_overlay == null:
        return
    region_map_overlay.set_open(not region_map_overlay.is_open())

func _close_region_map() -> void:
    if region_map_overlay != null:
        region_map_overlay.set_open(false)

func _is_region_map_open() -> bool:
    return region_map_overlay != null and region_map_overlay.is_open()

func _on_region_exit_reached() -> void:
    if ui != null:
        ui.set_hint("北方裂隙出口：Region 02 將從這裡接續")

func _use_dash_skill() -> void:
    skill_cooldowns[2] = 5.0
    var direction := _movement_direction()
    if direction.length_squared() < 0.01:
        direction = last_aim_direction
    if direction.length_squared() < 0.01:
        direction = Vector3(1, 0, 0)
    direction = direction.normalized()
    var start := player.global_position
    var destination := start + direction * 4.6
    if region_map != null:
        destination = region_map.clamp_player(destination)
    _spawn_hit_flash(start + Vector3(0, 0.65, 0), Color(0.30, 0.62, 1.0), 3.2)
    player.global_position = destination
    if region_map != null:
        region_map.update_streaming(player.position)
    _spawn_hit_flash(destination + Vector3(0, 0.65, 0), Color(0.30, 0.62, 1.0), 3.2)
    ui.set_hint("裂隙衝刺：快速位移")

func _damage_player(amount: float) -> void:
    player_hp = maxf(0.0, player_hp - amount)
    ui.set_hp(player_hp, player_max_hp)
    if player_hp <= 0.0:
        player_hp = player_max_hp
        player.velocity = Vector3.ZERO
        player.position = region_map.spawn_position() if region_map != null else Vector3.ZERO
        if region_map != null:
            region_map.update_streaming(player.position)
        ui.set_hp(player_hp, player_max_hp)
        ui.set_hint("你被裂隙吞沒，已在南方營地重生")

func debug_region_state() -> Dictionary:
    var streaming := region_map.streaming_state() if region_map != null else {}
    var terrain_visual := region_map.terrain_visual_state() if region_map != null else {}
    return {
        "region": region_map.name if region_map != null else "",
        "north_edge": RiftRegionMap.NORTH_EDGE,
        "south_edge": RiftRegionMap.SOUTH_EDGE,
        "half_width": RiftRegionMap.HALF_WIDTH,
        "player_spawn": region_map.spawn_position() if region_map != null else Vector3.ZERO,
        "zones": region_map.map_zones().size() if region_map != null else 0,
        "landmarks": region_map.map_landmarks().size() if region_map != null else 0,
        "region02_exit": region_map.get_node_or_null("Region02Exit") != null if region_map != null else false,
        "terrain_root": region_map.get_node_or_null("TerrainChunks") != null if region_map != null else false,
        "chunk_total": int(streaming.get("chunk_total", 0)),
        "chunk_loaded": int(streaming.get("loaded", 0)),
        "chunk_length": float(streaming.get("chunk_length", 0.0)),
        "terrain_spawn_luminance": float(terrain_visual.get("spawn_luminance", 0.0)),
        "terrain_visibility_stabilized": _terrain_visibility_stabilized,
    }

func debug_streaming_state() -> Dictionary:
    return region_map.streaming_state() if region_map != null else {}

func debug_map_state() -> Dictionary:
    if region_map_overlay == null:
        return {"open": false, "launcher": false, "screen": false, "player_marker": false, "map_size": Vector2.ZERO}
    return region_map_overlay.debug_state()
