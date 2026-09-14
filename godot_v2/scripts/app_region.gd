extends "res://scripts/app_arpg_hud.gd"

const RegionMapScript = preload("res://scripts/region_map.gd")
var region_map: RiftRegionMap

func _build_world() -> void:
    var environment_node := WorldEnvironment.new()
    environment_node.name = "WorldEnvironment"
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color(0.018, 0.024, 0.030)
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.43, 0.50, 0.58)
    environment.ambient_light_energy = 0.68
    environment_node.environment = environment
    add_child(environment_node)

    var light := DirectionalLight3D.new()
    light.name = "RegionLight"
    light.rotation_degrees = Vector3(-58, -34, 0)
    light.light_energy = 1.08
    light.shadow_enabled = false
    add_child(light)

    # Keep the root-level Ground runtime contract used by smoke tests and future systems.
    # The actual terrain meshes/colliders live inside the region builder below.
    var ground_anchor := Node3D.new()
    ground_anchor.name = "Ground"
    add_child(ground_anchor)

    region_map = RegionMapScript.new()
    add_child(region_map)
    region_map.build()

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
        enemy.position = region_map.enemy_spawn_position(maxi(slot, 0), enemy_serial)

func _physics_process(delta: float) -> void:
    if player == null:
        return

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
    if player_visual != null and absf(input_vector.x) > 0.05:
        player_visual.flip_h = input_vector.x < 0.0

    _update_enemies(delta)
    _update_loot()
    if mouse_fire_held and attack_cooldown <= 0.0:
        _attack_at_screen(mouse_fire_position)

func debug_region_state() -> Dictionary:
    return {
        "region": region_map.name if region_map != null else "",
        "north_edge": RiftRegionMap.NORTH_EDGE,
        "south_edge": RiftRegionMap.SOUTH_EDGE,
        "half_width": RiftRegionMap.HALF_WIDTH,
        "player_spawn": region_map.spawn_position() if region_map != null else Vector3.ZERO,
    }
