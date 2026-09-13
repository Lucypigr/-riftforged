extends Node3D

const MobileUIScript = preload("res://scripts/mobile_ui.gd")
const FontServiceScript = preload("res://scripts/font_service.gd")

const PLAYER_SPEED := 6.2
const ENEMY_SPEED := 2.0
const WORLD_LIMIT := 18.0
const MAX_ENEMIES := 5
const ATTACK_RANGE := 11.5
const ATTACK_DAMAGE := 28.0
const ATTACK_COOLDOWN := 0.36

var player: CharacterBody3D
var camera: Camera3D
var enemies_root: Node3D
var ui: RiftMobileUI
var ui_font: FontFile
var enemies: Array[Dictionary] = []
var enemy_serial := 0
var move_input := Vector2.ZERO
var player_hp := 100.0
var player_max_hp := 100.0
var attack_cooldown := 0.0
var kills := 0

func _ready() -> void:
    randomize()
    ui_font = FontServiceScript.load_ui_font()
    if ui_font == null:
        push_error("Riftforged v2 cannot start without the bundled Traditional Chinese font")
        return

    _build_world()
    _build_player()
    _build_enemies_root()
    _build_ui()
    for i in range(MAX_ENEMIES):
        _spawn_enemy(i == MAX_ENEMIES - 1)

func _build_world() -> void:
    var environment_node := WorldEnvironment.new()
    environment_node.name = "WorldEnvironment"
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color(0.026, 0.032, 0.043)
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.52, 0.58, 0.68)
    environment.ambient_light_energy = 0.72
    environment_node.environment = environment
    add_child(environment_node)

    var light := DirectionalLight3D.new()
    light.name = "KeyLight"
    light.rotation_degrees = Vector3(-55, -30, 0)
    light.light_energy = 1.15
    light.shadow_enabled = true
    add_child(light)

    var ground := MeshInstance3D.new()
    ground.name = "Ground"
    var plane := PlaneMesh.new()
    plane.size = Vector2(42, 42)
    ground.mesh = plane
    var ground_mat := StandardMaterial3D.new()
    ground_mat.albedo_color = Color(0.075, 0.10, 0.085)
    ground_mat.roughness = 1.0
    ground.material_override = ground_mat
    add_child(ground)

    var ground_body := StaticBody3D.new()
    ground_body.name = "GroundCollision"
    var shape_node := CollisionShape3D.new()
    var ground_shape := BoxShape3D.new()
    ground_shape.size = Vector3(42, 0.2, 42)
    shape_node.shape = ground_shape
    shape_node.position.y = -0.11
    ground_body.add_child(shape_node)
    add_child(ground_body)

    for z in range(-15, 16, 3):
        var tile := MeshInstance3D.new()
        var mesh := BoxMesh.new()
        mesh.size = Vector3(3.8, 0.04, 2.1)
        tile.mesh = mesh
        tile.position = Vector3(float((z / 3) % 2) * 0.65, 0.025, float(z))
        var mat := StandardMaterial3D.new()
        mat.albedo_color = Color(0.16, 0.145, 0.12)
        mat.roughness = 1.0
        tile.material_override = mat
        add_child(tile)

    var props := [
        Vector3(-5.5, 0.65, -4.0), Vector3(5.8, 0.65, 4.2),
        Vector3(-7.5, 0.65, 6.0), Vector3(7.5, 0.65, -5.8),
        Vector3(0.0, 0.65, -9.0), Vector3(-1.0, 0.65, 9.0)
    ]
    for i in range(props.size()):
        var prop := MeshInstance3D.new()
        prop.name = "Ruin%d" % i
        var box := BoxMesh.new()
        box.size = Vector3(1.2, 1.1 + float(i % 3) * 0.45, 1.2)
        prop.mesh = box
        prop.position = props[i]
        var prop_mat := StandardMaterial3D.new()
        prop_mat.albedo_color = Color(0.17, 0.15, 0.135)
        prop_mat.roughness = 0.95
        prop.material_override = prop_mat
        add_child(prop)

func _build_player() -> void:
    player = CharacterBody3D.new()
    player.name = "Player"
    add_child(player)

    var collision := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.42
    capsule.height = 1.55
    collision.shape = capsule
    collision.position.y = 0.78
    player.add_child(collision)

    var shadow := MeshInstance3D.new()
    var shadow_mesh := CylinderMesh.new()
    shadow_mesh.top_radius = 0.58
    shadow_mesh.bottom_radius = 0.58
    shadow_mesh.height = 0.025
    shadow.mesh = shadow_mesh
    shadow.position.y = 0.02
    var shadow_mat := StandardMaterial3D.new()
    shadow_mat.albedo_color = Color(0, 0, 0, 0.38)
    shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    shadow.material_override = shadow_mat
    player.add_child(shadow)

    var body := MeshInstance3D.new()
    body.name = "Body"
    var body_mesh := CapsuleMesh.new()
    body_mesh.radius = 0.42
    body_mesh.height = 1.55
    body.mesh = body_mesh
    body.position.y = 0.78
    var body_mat := StandardMaterial3D.new()
    body_mat.albedo_color = Color(0.74, 0.80, 0.96)
    body.material_override = body_mat
    player.add_child(body)

    var accent := MeshInstance3D.new()
    var accent_mesh := BoxMesh.new()
    accent_mesh.size = Vector3(0.5, 0.58, 0.18)
    accent.mesh = accent_mesh
    accent.position = Vector3(0, 0.88, -0.38)
    var accent_mat := StandardMaterial3D.new()
    accent_mat.albedo_color = Color(0.78, 0.16, 0.20)
    accent.material_override = accent_mat
    player.add_child(accent)

    camera = Camera3D.new()
    camera.name = "Camera3D"
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = 17.5
    camera.keep_aspect = Camera3D.KEEP_WIDTH
    camera.position = Vector3(0, 10.8, 11.4)
    camera.rotation_degrees = Vector3(-44, 0, 0)
    camera.current = true
    player.add_child(camera)

func _build_enemies_root() -> void:
    enemies_root = Node3D.new()
    enemies_root.name = "Enemies"
    add_child(enemies_root)

func _build_ui() -> void:
    ui = MobileUIScript.new()
    ui.name = "MobileUI"
    add_child(ui)
    ui.setup(ui_font)
    ui.movement_changed.connect(func(value: Vector2): move_input = value)
    ui.attack_requested.connect(_attack)
    ui.set_hp(player_hp, player_max_hp)

func _spawn_enemy(elite: bool = false) -> void:
    enemy_serial += 1
    var enemy := CharacterBody3D.new()
    enemy.name = "Enemy_%d" % enemy_serial
    var angle := randf() * TAU
    var radius := randf_range(8.5, 15.5)
    enemy.position = Vector3(cos(angle) * radius, 0, sin(angle) * radius)
    enemies_root.add_child(enemy)

    var collision := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.52 if elite else 0.44
    capsule.height = 1.7 if elite else 1.5
    collision.shape = capsule
    collision.position.y = 0.82
    enemy.add_child(collision)

    var visual := MeshInstance3D.new()
    visual.name = "Visual"
    var mesh := CapsuleMesh.new()
    mesh.radius = 0.52 if elite else 0.44
    mesh.height = 1.7 if elite else 1.5
    visual.mesh = mesh
    visual.position.y = 0.82
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.90, 0.38, 0.17) if elite else Color(0.54, 0.22, 0.68)
    visual.material_override = mat
    enemy.add_child(visual)

    var max_hp := 110.0 if elite else 60.0
    var label := Label3D.new()
    label.name = "NameLabel"
    label.text = "菁英裂隙獸 %d" % int(max_hp) if elite else "裂隙獸 %d" % int(max_hp)
    label.position = Vector3(0, 2.25, 0)
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.font = ui_font
    label.font_size = 28
    label.outline_size = 8
    label.modulate = Color(1.0, 0.82, 0.64) if elite else Color(0.96, 0.88, 1.0)
    enemy.add_child(label)

    enemies.append({
        "id": enemy_serial,
        "node": enemy,
        "label": label,
        "hp": max_hp,
        "max_hp": max_hp,
        "elite": elite,
        "touch_cd": 0.0,
    })

func _physics_process(delta: float) -> void:
    if player == null:
        return

    attack_cooldown = maxf(0.0, attack_cooldown - delta)

    var keyboard := Vector2.ZERO
    if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
        keyboard.x -= 1
    if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
        keyboard.x += 1
    if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
        keyboard.y -= 1
    if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
        keyboard.y += 1
    keyboard = keyboard.normalized()

    var input_vector := move_input if move_input.length() > 0.03 else keyboard
    player.velocity = Vector3(input_vector.x, 0, input_vector.y) * PLAYER_SPEED
    player.move_and_slide()
    player.position.x = clampf(player.position.x, -WORLD_LIMIT, WORLD_LIMIT)
    player.position.z = clampf(player.position.z, -WORLD_LIMIT, WORLD_LIMIT)

    _update_enemies(delta)

func _update_enemies(delta: float) -> void:
    for i in range(enemies.size() - 1, -1, -1):
        var entry: Dictionary = enemies[i]
        var enemy := entry["node"] as CharacterBody3D
        if not is_instance_valid(enemy):
            enemies.remove_at(i)
            continue

        entry["touch_cd"] = maxf(0.0, float(entry["touch_cd"]) - delta)
        var to_player := player.global_position - enemy.global_position
        to_player.y = 0
        if to_player.length() > 1.18:
            enemy.velocity = to_player.normalized() * ENEMY_SPEED * (1.08 if bool(entry["elite"]) else 1.0)
            enemy.move_and_slide()
        else:
            enemy.velocity = Vector3.ZERO
            if float(entry["touch_cd"]) <= 0:
                _damage_player(15.0 if bool(entry["elite"]) else 10.0)
                entry["touch_cd"] = 0.85
        enemies[i] = entry

func _attack() -> void:
    if attack_cooldown > 0 or enemies.is_empty():
        return
    var index := _nearest_enemy_index()
    if index < 0:
        ui.set_hint("附近沒有敵人")
        return

    var entry: Dictionary = enemies[index]
    var enemy := entry["node"] as CharacterBody3D
    if player.global_position.distance_to(enemy.global_position) > ATTACK_RANGE:
        ui.set_hint("敵人超出攻擊距離")
        return

    attack_cooldown = ATTACK_COOLDOWN
    entry["hp"] = maxf(0.0, float(entry["hp"]) - ATTACK_DAMAGE)
    var label := entry["label"] as Label3D
    var prefix := "菁英裂隙獸" if bool(entry["elite"]) else "裂隙獸"
    label.text = "%s %d" % [prefix, int(entry["hp"])]
    _spawn_hit_flash(enemy.global_position + Vector3(0, 0.9, 0))

    if float(entry["hp"]) <= 0:
        var was_elite := bool(entry["elite"])
        enemy.queue_free()
        enemies.remove_at(index)
        kills += 1
        ui.set_hint("擊倒 %s · 擊殺 %d" % [prefix, kills])
        _spawn_enemy(was_elite if kills % 7 == 0 else false)
    else:
        enemies[index] = entry

func _nearest_enemy_index() -> int:
    var best := -1
    var best_distance := INF
    for i in range(enemies.size()):
        var enemy := enemies[i]["node"] as CharacterBody3D
        if not is_instance_valid(enemy):
            continue
        var distance := player.global_position.distance_squared_to(enemy.global_position)
        if distance < best_distance:
            best_distance = distance
            best = i
    return best

func _damage_player(amount: float) -> void:
    player_hp = maxf(0.0, player_hp - amount)
    ui.set_hp(player_hp, player_max_hp)
    if player_hp <= 0:
        player_hp = player_max_hp
        player.position = Vector3.ZERO
        ui.set_hp(player_hp, player_max_hp)
        ui.set_hint("你被裂隙吞沒，已在營火重生")

func _spawn_hit_flash(position: Vector3) -> void:
    var flash := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 0.18
    sphere.height = 0.36
    flash.mesh = sphere
    flash.position = position
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(1.0, 0.64, 0.20)
    mat.emission_enabled = true
    mat.emission = Color(1.0, 0.32, 0.08)
    mat.emission_energy_multiplier = 2.0
    flash.material_override = mat
    add_child(flash)
    var tween := create_tween()
    tween.tween_property(flash, "scale", Vector3(2.8, 2.8, 2.8), 0.12)
    tween.tween_callback(flash.queue_free)

func debug_font() -> FontFile:
    return ui_font

func debug_enemy_count() -> int:
    return enemies.size()
