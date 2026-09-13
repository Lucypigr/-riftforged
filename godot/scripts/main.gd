extends Node3D

const GemCatalog = preload("res://scripts/gem_catalog.gd")

const PLAYER_SPEED := 6.0
const ENEMY_SPEED := 2.15
const PROJECTILE_SPEED := 14.0
const PROJECTILE_LIFE := 1.4
const JOYSTICK_RADIUS := 50.0
const MAX_ENEMIES := 5
const BASE_DAMAGE := 20.0
const BASE_ATTACK_COOLDOWN := 0.38
const WORLD_LIMIT := 20.0

var player: CharacterBody3D
var camera: Camera3D
var enemies_root: Node3D
var loot_root: Node3D
var enemies: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var loot_drops: Array[Dictionary] = []
var enemy_serial := 0
var spawn_timer := 0.0
var attack_cooldown := 0.0
var player_hp := 100.0
var player_max_hp := 100.0
var kills := 0

var socket_gems: Array[String] = ["crimson_bolt", "", "", ""]
var gem_stash: Array[String] = ["verdant_chain", "verdant_multishot", "crimson_burst"]
var selected_stash_gem := ""

var joystick_vector := Vector2.ZERO
var joystick_touch_id := -1
var ui_layer: CanvasLayer
var joystick_back: Panel
var joystick_knob: Panel
var attack_button: Button
var gem_button: Button
var status_label: Label
var build_label: Label
var hint_label: Label
var hp_bar: ProgressBar
var gem_panel: Panel
var gem_socket_row: HBoxContainer
var gem_stash_box: VBoxContainer
var socket_buttons: Array[Button] = []

func _ready() -> void:
    randomize()
    _build_world()
    _build_player()
    _build_enemy_root()
    _build_loot_root()
    _build_ui()
    for i in range(MAX_ENEMIES):
        _spawn_enemy(i == MAX_ENEMIES - 1)
    _spawn_gem_drop(Vector3(2.2, 0.0, 1.0), "azure_reach")
    get_viewport().size_changed.connect(_layout_ui)
    _layout_ui()
    _refresh_gem_ui()
    _refresh_hud()

func _build_world() -> void:
    var world := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.027, 0.035, 0.046)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.48, 0.56, 0.68)
    env.ambient_light_energy = 0.66
    world.environment = env
    world.name = "WorldEnvironment"
    add_child(world)

    var light := DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-55.0, -25.0, 0.0)
    light.light_energy = 1.25
    light.shadow_enabled = true
    light.name = "KeyLight"
    add_child(light)

    var floor_mesh := MeshInstance3D.new()
    var plane := PlaneMesh.new()
    plane.size = Vector2(46.0, 46.0)
    floor_mesh.mesh = plane
    var floor_mat := StandardMaterial3D.new()
    floor_mat.albedo_color = Color(0.085, 0.115, 0.10)
    floor_mat.roughness = 1.0
    floor_mesh.material_override = floor_mat
    floor_mesh.name = "Ground"
    add_child(floor_mesh)

    var floor_body := StaticBody3D.new()
    var floor_shape := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = Vector3(46.0, 0.25, 46.0)
    floor_shape.shape = box
    floor_shape.position.y = -0.15
    floor_body.add_child(floor_shape)
    floor_body.name = "GroundCollision"
    add_child(floor_body)

    for z in range(-15, 16, 3):
        var path_tile := MeshInstance3D.new()
        var path_mesh := BoxMesh.new()
        path_mesh.size = Vector3(3.5, 0.035, 2.0)
        path_tile.mesh = path_mesh
        path_tile.position = Vector3(float((z / 3) % 2) * 0.7, 0.02, float(z))
        var path_mat := StandardMaterial3D.new()
        path_mat.albedo_color = Color(0.16, 0.145, 0.12)
        path_mat.roughness = 1.0
        path_tile.material_override = path_mat
        add_child(path_tile)

    var prop_positions := [
        Vector3(-5.0, 0.6, -4.0), Vector3(5.5, 0.6, 4.0),
        Vector3(-7.0, 0.6, 5.0), Vector3(7.0, 0.6, -5.5),
        Vector3(0.0, 0.6, -8.0), Vector3(-1.0, 0.6, 8.0),
        Vector3(-10.0, 0.6, -8.0), Vector3(10.0, 0.6, 9.0)
    ]
    for i in range(prop_positions.size()):
        var prop := MeshInstance3D.new()
        var prop_mesh := BoxMesh.new()
        prop_mesh.size = Vector3(1.15, 1.1 + float(i % 3) * 0.42, 1.15)
        prop.mesh = prop_mesh
        prop.position = prop_positions[i]
        var prop_mat := StandardMaterial3D.new()
        prop_mat.albedo_color = Color(0.18 + float(i) * 0.008, 0.16, 0.14)
        prop_mat.roughness = 0.95
        prop.material_override = prop_mat
        prop.name = "Prop%d" % i
        add_child(prop)

func _build_player() -> void:
    player = CharacterBody3D.new()
    player.name = "Player"
    player.position = Vector3.ZERO
    add_child(player)

    var player_shape := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.42
    capsule.height = 1.5
    player_shape.shape = capsule
    player_shape.position.y = 0.75
    player.add_child(player_shape)

    var shadow := MeshInstance3D.new()
    var shadow_mesh := CylinderMesh.new()
    shadow_mesh.top_radius = 0.58
    shadow_mesh.bottom_radius = 0.58
    shadow_mesh.height = 0.025
    shadow.mesh = shadow_mesh
    shadow.position.y = 0.02
    var shadow_mat := StandardMaterial3D.new()
    shadow_mat.albedo_color = Color(0.0, 0.0, 0.0, 0.36)
    shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    shadow.material_override = shadow_mat
    player.add_child(shadow)

    var visual := _make_billboard(Color(0.78, 0.84, 0.98), Vector2(1.1, 1.75))
    visual.name = "PlayerBillboard"
    visual.position.y = 0.92
    player.add_child(visual)

    var accent := _make_billboard(Color(0.85, 0.20, 0.26), Vector2(0.42, 0.75))
    accent.name = "PlayerAccent"
    accent.position = Vector3(0.0, 0.95, -0.02)
    player.add_child(accent)

    camera = Camera3D.new()
    camera.name = "Camera3D"
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = 17.0
    camera.keep_aspect = Camera3D.KEEP_WIDTH
    camera.position = Vector3(0.0, 10.5, 11.0)
    camera.rotation_degrees = Vector3(-44.0, 0.0, 0.0)
    camera.current = true
    player.add_child(camera)

func _build_enemy_root() -> void:
    enemies_root = Node3D.new()
    enemies_root.name = "Enemies"
    add_child(enemies_root)

func _build_loot_root() -> void:
    loot_root = Node3D.new()
    loot_root.name = "Loot"
    add_child(loot_root)

func _spawn_enemy(elite: bool = false) -> void:
    enemy_serial += 1
    var node := CharacterBody3D.new()
    node.name = "Enemy_%d" % enemy_serial
    var angle := randf() * TAU
    var radius := randf_range(9.0, 16.0)
    node.position = Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
    enemies_root.add_child(node)

    var enemy_shape := CollisionShape3D.new()
    var shape := CapsuleShape3D.new()
    shape.radius = 0.52 if elite else 0.45
    shape.height = 1.65 if elite else 1.5
    enemy_shape.shape = shape
    enemy_shape.position.y = 0.8
    node.add_child(enemy_shape)

    var color := Color(0.88, 0.42, 0.18) if elite else Color(0.64, 0.24, 0.72)
    var visual := _make_billboard(color, Vector2(1.38, 2.0) if elite else Vector2(1.15, 1.8))
    visual.name = "EnemyBillboard"
    visual.position.y = 1.02
    node.add_child(visual)

    var label := Label3D.new()
    label.name = "EnemyLabel"
    var max_hp := 110.0 if elite else 60.0
    label.text = "%s %d" % ["菁英裂隙獸" if elite else "裂隙獸", int(max_hp)]
    label.position = Vector3(0.0, 2.25, 0.0)
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.font_size = 26
    label.outline_size = 8
    label.modulate = Color(1.0, 0.82, 0.66) if elite else Color(1.0, 0.84, 0.96)
    node.add_child(label)

    enemies.append({
        "id": enemy_serial,
        "node": node,
        "hp": max_hp,
        "max_hp": max_hp,
        "speed": ENEMY_SPEED * (1.08 if elite else 1.0),
        "touch_cd": 0.0,
        "elite": elite,
    })

func _make_billboard(color: Color, mesh_size: Vector2) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    var quad := QuadMesh.new()
    quad.size = mesh_size
    node.mesh = quad
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
    node.material_override = mat
    return node

func _build_ui() -> void:
    ui_layer = CanvasLayer.new()
    ui_layer.name = "MobileUI"
    add_child(ui_layer)

    joystick_back = Panel.new()
    joystick_back.name = "Joystick"
    joystick_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
    joystick_back.add_theme_stylebox_override("panel", _round_style(Color(0.08, 0.10, 0.13, 0.58), 68))
    ui_layer.add_child(joystick_back)

    joystick_knob = Panel.new()
    joystick_knob.name = "JoystickKnob"
    joystick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
    joystick_knob.add_theme_stylebox_override("panel", _round_style(Color(0.70, 0.76, 0.86, 0.70), 32))
    joystick_back.add_child(joystick_knob)

    attack_button = Button.new()
    attack_button.name = "AttackButton"
    attack_button.text = "攻擊"
    attack_button.focus_mode = Control.FOCUS_NONE
    attack_button.add_theme_font_size_override("font_size", 20)
    attack_button.add_theme_stylebox_override("normal", _round_style(Color(0.48, 0.10, 0.13, 0.82), 46))
    attack_button.add_theme_stylebox_override("hover", _round_style(Color(0.60, 0.14, 0.18, 0.90), 46))
    attack_button.add_theme_stylebox_override("pressed", _round_style(Color(0.80, 0.20, 0.22, 0.98), 46))
    attack_button.pressed.connect(_fire)
    ui_layer.add_child(attack_button)

    gem_button = Button.new()
    gem_button.name = "GemButton"
    gem_button.text = "寶石"
    gem_button.focus_mode = Control.FOCUS_NONE
    gem_button.add_theme_font_size_override("font_size", 16)
    gem_button.add_theme_stylebox_override("normal", _round_style(Color(0.08, 0.14, 0.23, 0.92), 18))
    gem_button.pressed.connect(_toggle_gem_panel)
    ui_layer.add_child(gem_button)

    status_label = Label.new()
    status_label.name = "Status"
    status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status_label.add_theme_font_size_override("font_size", 17)
    status_label.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0))
    status_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
    status_label.add_theme_constant_override("shadow_offset_x", 2)
    status_label.add_theme_constant_override("shadow_offset_y", 2)
    ui_layer.add_child(status_label)

    hp_bar = ProgressBar.new()
    hp_bar.name = "HpBar"
    hp_bar.min_value = 0.0
    hp_bar.max_value = player_max_hp
    hp_bar.value = player_hp
    hp_bar.show_percentage = false
    ui_layer.add_child(hp_bar)

    build_label = Label.new()
    build_label.name = "Build"
    build_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    build_label.add_theme_font_size_override("font_size", 14)
    build_label.add_theme_color_override("font_color", Color(0.78, 0.85, 0.95))
    ui_layer.add_child(build_label)

    hint_label = Label.new()
    hint_label.name = "Hint"
    hint_label.text = "左下移動 · 右下攻擊 · 右上寶石"
    hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint_label.add_theme_font_size_override("font_size", 13)
    hint_label.add_theme_color_override("font_color", Color(0.75, 0.80, 0.86))
    ui_layer.add_child(hint_label)

    _build_gem_panel()

func _build_gem_panel() -> void:
    gem_panel = Panel.new()
    gem_panel.name = "GemPanel"
    gem_panel.visible = false
    gem_panel.mouse_filter = Control.MOUSE_FILTER_STOP
    gem_panel.add_theme_stylebox_override("panel", _round_style(Color(0.035, 0.045, 0.065, 0.98), 20))
    ui_layer.add_child(gem_panel)

    var content := VBoxContainer.new()
    content.name = "Content"
    content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    content.add_theme_constant_override("separation", 10)
    content.offset_left = 14.0
    content.offset_top = 14.0
    content.offset_right = -14.0
    content.offset_bottom = -14.0
    gem_panel.add_child(content)

    var title := Label.new()
    title.text = "裂隙寶石 · 4 連"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 22)
    title.add_theme_color_override("font_color", Color(0.94, 0.84, 0.62))
    content.add_child(title)

    var help := Label.new()
    help.text = "先點背包寶石，再點孔洞安裝。四個孔洞彼此連線，輔助只會強化同組主動寶石。"
    help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    help.add_theme_font_size_override("font_size", 13)
    content.add_child(help)

    gem_socket_row = HBoxContainer.new()
    gem_socket_row.name = "Sockets"
    gem_socket_row.alignment = BoxContainer.ALIGNMENT_CENTER
    gem_socket_row.add_theme_constant_override("separation", 8)
    content.add_child(gem_socket_row)

    for i in range(4):
        var button := Button.new()
        button.name = "Socket%d" % i
        button.custom_minimum_size = Vector2(66.0, 66.0)
        button.focus_mode = Control.FOCUS_NONE
        button.pressed.connect(_on_socket_pressed.bind(i))
        gem_socket_row.add_child(button)
        socket_buttons.append(button)

    var line := HSeparator.new()
    content.add_child(line)

    var stash_title := Label.new()
    stash_title.text = "寶石背包"
    stash_title.add_theme_font_size_override("font_size", 16)
    content.add_child(stash_title)

    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content.add_child(scroll)

    gem_stash_box = VBoxContainer.new()
    gem_stash_box.name = "Stash"
    gem_stash_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    gem_stash_box.add_theme_constant_override("separation", 6)
    scroll.add_child(gem_stash_box)

func _round_style(color: Color, radius: int) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.corner_radius_top_left = radius
    style.corner_radius_top_right = radius
    style.corner_radius_bottom_left = radius
    style.corner_radius_bottom_right = radius
    style.border_width_left = 1
    style.border_width_top = 1
    style.border_width_right = 1
    style.border_width_bottom = 1
    style.border_color = Color(1.0, 1.0, 1.0, 0.12)
    return style

func _layout_ui() -> void:
    if not is_instance_valid(joystick_back):
        return
    var viewport_size: Vector2 = get_viewport().get_visible_rect().size

    joystick_back.size = Vector2(136.0, 136.0)
    joystick_back.position = Vector2(22.0, viewport_size.y - 170.0)
    joystick_knob.size = Vector2(56.0, 56.0)
    _set_joystick_visual(joystick_vector)

    attack_button.size = Vector2(94.0, 94.0)
    attack_button.position = Vector2(viewport_size.x - 118.0, viewport_size.y - 142.0)

    gem_button.size = Vector2(68.0, 44.0)
    gem_button.position = Vector2(viewport_size.x - 80.0, 18.0)

    status_label.position = Vector2(12.0, 12.0)
    status_label.size = Vector2(viewport_size.x - 100.0, 26.0)

    hp_bar.position = Vector2(18.0, 42.0)
    hp_bar.size = Vector2(minf(220.0, viewport_size.x - 116.0), 18.0)

    build_label.position = Vector2(12.0, 64.0)
    build_label.size = Vector2(viewport_size.x - 24.0, 24.0)

    hint_label.position = Vector2(12.0, 88.0)
    hint_label.size = Vector2(viewport_size.x - 24.0, 34.0)

    var panel_width: float = minf(360.0, viewport_size.x - 24.0)
    var panel_height: float = minf(500.0, viewport_size.y - 150.0)
    gem_panel.size = Vector2(panel_width, panel_height)
    gem_panel.position = Vector2((viewport_size.x - panel_width) * 0.5, maxf(112.0, (viewport_size.y - panel_height) * 0.5))

func _physics_process(delta: float) -> void:
    attack_cooldown = maxf(0.0, attack_cooldown - delta)
    spawn_timer = maxf(0.0, spawn_timer - delta)

    var keyboard := Vector2.ZERO
    if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
        keyboard.x -= 1.0
    if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
        keyboard.x += 1.0
    if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
        keyboard.y -= 1.0
    if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
        keyboard.y += 1.0
    keyboard = keyboard.normalized()

    var move_input := joystick_vector if joystick_vector.length() > 0.02 else keyboard
    player.velocity = Vector3(move_input.x, 0.0, move_input.y) * PLAYER_SPEED
    player.move_and_slide()
    player.position.x = clampf(player.position.x, -WORLD_LIMIT, WORLD_LIMIT)
    player.position.z = clampf(player.position.z, -WORLD_LIMIT, WORLD_LIMIT)

    _update_enemies(delta)
    _update_projectiles(delta)
    _update_loot(delta)

    if enemies.size() < MAX_ENEMIES and spawn_timer <= 0.0:
        _spawn_enemy(kills > 0 and kills % 8 == 0)
        spawn_timer = 0.75

func _update_enemies(delta: float) -> void:
    for i in range(enemies.size() - 1, -1, -1):
        var entry: Dictionary = enemies[i]
        var node := entry["node"] as CharacterBody3D
        if not is_instance_valid(node):
            enemies.remove_at(i)
            continue

        entry["touch_cd"] = maxf(0.0, float(entry["touch_cd"]) - delta)
        var to_player := player.global_position - node.global_position
        to_player.y = 0.0
        if to_player.length() > 1.25:
            node.velocity = to_player.normalized() * float(entry["speed"])
            node.move_and_slide()
        else:
            node.velocity = Vector3.ZERO
            if float(entry["touch_cd"]) <= 0.0:
                var damage := 15.0 if bool(entry["elite"]) else 10.0
                _damage_player(damage)
                entry["touch_cd"] = 0.8
        enemies[i] = entry

func _damage_player(amount: float) -> void:
    player_hp = maxf(0.0, player_hp - amount)
    _refresh_hud()
    if player_hp <= 0.0:
        player_hp = player_max_hp
        player.position = Vector3.ZERO
        hint_label.text = "你被裂隙吞沒，已在營火重生"
        _refresh_hud()

func _fire() -> void:
    if attack_cooldown > 0.0 or enemies.is_empty():
        return
    var target := _nearest_enemy(player.global_position, [])
    if target.is_empty():
        return

    var profile := _build_profile()
    if String(profile["active_id"]).is_empty():
        hint_label.text = "沒有安裝主動寶石"
        return

    attack_cooldown = BASE_ATTACK_COOLDOWN * float(profile["cooldown"])
    var origin := player.global_position + Vector3(0.0, 0.78, 0.0)
    var target_node := target["node"] as CharacterBody3D
    var target_pos := target_node.global_position + Vector3(0.0, 0.78, 0.0)
    var base_direction := (target_pos - origin).normalized()
    var total_projectiles := 1 + int(profile["projectiles"])
    var spread := deg_to_rad(11.0)
    var center := float(total_projectiles - 1) * 0.5

    for i in range(total_projectiles):
        var angle := (float(i) - center) * spread
        var direction := base_direction.rotated(Vector3.UP, angle)
        _spawn_projectile(origin, direction, profile, [])

func _spawn_projectile(origin: Vector3, direction: Vector3, profile: Dictionary, hit_ids: Array) -> void:
    var projectile := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 0.15
    sphere.height = 0.30
    projectile.mesh = sphere
    var mat := StandardMaterial3D.new()
    var projectile_color := Color.html(String(profile["projectile_color"]))
    mat.albedo_color = projectile_color
    mat.emission_enabled = true
    mat.emission = projectile_color
    mat.emission_energy_multiplier = 2.2
    projectile.material_override = mat
    projectile.position = origin
    projectile.name = "Projectile"
    add_child(projectile)

    var copied_hits: Array = hit_ids.duplicate()
    projectiles.append({
        "node": projectile,
        "velocity": direction.normalized() * PROJECTILE_SPEED * float(profile["speed"]),
        "life": PROJECTILE_LIFE * float(profile["life"]),
        "damage": BASE_DAMAGE * float(profile["damage"]),
        "chain": int(profile["chain"]),
        "pierce": int(profile["pierce"]),
        "forks": int(profile["forks"]),
        "fork_damage": float(profile["fork_damage"]),
        "splash": float(profile["splash"]),
        "splash_damage": float(profile["splash_damage"]),
        "hit_ids": copied_hits,
        "projectile_color": String(profile["projectile_color"]),
    })

func _update_projectiles(delta: float) -> void:
    for i in range(projectiles.size() - 1, -1, -1):
        if i >= projectiles.size():
            continue
        var entry: Dictionary = projectiles[i]
        var node := entry["node"] as MeshInstance3D
        if not is_instance_valid(node):
            projectiles.remove_at(i)
            continue

        var velocity: Vector3 = entry["velocity"]
        node.position += velocity * delta
        entry["life"] = float(entry["life"]) - delta
        projectiles[i] = entry

        var hit_enemy_id := -1
        for enemy_entry in enemies:
            var enemy_node := enemy_entry["node"] as CharacterBody3D
            if not is_instance_valid(enemy_node):
                continue
            var enemy_id := int(enemy_entry["id"])
            var hit_ids: Array = entry["hit_ids"]
            if hit_ids.has(enemy_id):
                continue
            if node.global_position.distance_to(enemy_node.global_position + Vector3(0.0, 0.78, 0.0)) < 0.72:
                hit_enemy_id = enemy_id
                break

        if hit_enemy_id != -1:
            _handle_projectile_hit(i, hit_enemy_id)
        elif i < projectiles.size() and float(projectiles[i]["life"]) <= 0.0:
            _remove_projectile(i)

func _handle_projectile_hit(projectile_index: int, enemy_id: int) -> void:
    if projectile_index < 0 or projectile_index >= projectiles.size():
        return
    var entry: Dictionary = projectiles[projectile_index]
    var node := entry["node"] as MeshInstance3D
    if not is_instance_valid(node):
        _remove_projectile(projectile_index)
        return

    var impact := node.global_position
    var hit_ids: Array = entry["hit_ids"]
    hit_ids.append(enemy_id)
    entry["hit_ids"] = hit_ids
    projectiles[projectile_index] = entry

    _damage_enemy_by_id(enemy_id, float(entry["damage"]))
    _apply_splash(enemy_id, impact, float(entry["damage"]), float(entry["splash"]), float(entry["splash_damage"]), hit_ids)

    if int(entry["forks"]) > 0:
        var base_direction := (entry["velocity"] as Vector3).normalized()
        var child_profile := {
            "damage": float(entry["damage"]) / BASE_DAMAGE * float(entry["fork_damage"]),
            "cooldown": 1.0,
            "projectiles": 0,
            "chain": int(entry["chain"]),
            "pierce": 0,
            "forks": 0,
            "fork_damage": 1.0,
            "splash": float(entry["splash"]),
            "splash_damage": float(entry["splash_damage"]),
            "speed": (entry["velocity"] as Vector3).length() / PROJECTILE_SPEED,
            "life": maxf(0.25, float(entry["life"]) / PROJECTILE_LIFE),
            "projectile_color": String(entry["projectile_color"]),
            "active_id": "fork_child",
        }
        var forks := int(entry["forks"])
        for f in range(forks):
            var fork_angle := deg_to_rad(-24.0 if f % 2 == 0 else 24.0)
            _spawn_projectile(impact, base_direction.rotated(Vector3.UP, fork_angle), child_profile, hit_ids)
        _remove_projectile(projectile_index)
        return

    if int(entry["chain"]) > 0:
        var next_target := _nearest_enemy(impact, hit_ids, 7.0)
        if not next_target.is_empty():
            var next_node := next_target["node"] as CharacterBody3D
            var next_direction := (next_node.global_position + Vector3(0.0, 0.78, 0.0) - impact).normalized()
            entry["velocity"] = next_direction * (entry["velocity"] as Vector3).length()
            entry["chain"] = int(entry["chain"]) - 1
            entry["damage"] = float(entry["damage"]) * 0.88
            entry["hit_ids"] = hit_ids
            projectiles[projectile_index] = entry
            return

    if int(entry["pierce"]) > 0:
        entry["pierce"] = int(entry["pierce"]) - 1
        entry["hit_ids"] = hit_ids
        projectiles[projectile_index] = entry
        return

    _remove_projectile(projectile_index)

func _apply_splash(main_enemy_id: int, impact: Vector3, main_damage: float, radius: float, multiplier: float, hit_ids: Array) -> void:
    if radius <= 0.0 or multiplier <= 0.0:
        return
    var targets: Array[int] = []
    for entry in enemies:
        var id := int(entry["id"])
        if id == main_enemy_id or hit_ids.has(id):
            continue
        var node := entry["node"] as CharacterBody3D
        if is_instance_valid(node) and node.global_position.distance_to(impact) <= radius:
            targets.append(id)
    for id in targets:
        _damage_enemy_by_id(id, main_damage * multiplier)

func _remove_projectile(index: int) -> void:
    if index < 0 or index >= projectiles.size():
        return
    var node := projectiles[index]["node"] as MeshInstance3D
    if is_instance_valid(node):
        node.queue_free()
    projectiles.remove_at(index)

func _damage_enemy_by_id(enemy_id: int, amount: float) -> void:
    for i in range(enemies.size()):
        var entry: Dictionary = enemies[i]
        if int(entry["id"]) != enemy_id:
            continue
        var node := entry["node"] as CharacterBody3D
        entry["hp"] = float(entry["hp"]) - amount
        if is_instance_valid(node):
            var label := node.get_node_or_null("EnemyLabel") as Label3D
            if label:
                label.text = "%s %d" % ["菁英裂隙獸" if bool(entry["elite"]) else "裂隙獸", maxi(0, int(ceil(float(entry["hp"]))))]
        if float(entry["hp"]) <= 0.0:
            _kill_enemy_at(i)
        else:
            enemies[i] = entry
        return

func _kill_enemy_at(index: int) -> void:
    if index < 0 or index >= enemies.size():
        return
    var entry: Dictionary = enemies[index]
    var node := entry["node"] as CharacterBody3D
    var drop_position := node.global_position if is_instance_valid(node) else Vector3.ZERO
    var elite := bool(entry["elite"])
    if is_instance_valid(node):
        node.queue_free()
    enemies.remove_at(index)
    kills += 1
    spawn_timer = 0.4

    var drop_chance := 0.35 if elite else 0.05
    if randf() < drop_chance:
        _spawn_gem_drop(drop_position, GemCatalog.random_drop())
    _refresh_hud()

func _nearest_enemy(from: Vector3, excluded_ids: Array, max_distance: float = INF) -> Dictionary:
    var best: Dictionary = {}
    var best_distance := max_distance
    for entry in enemies:
        var id := int(entry["id"])
        if excluded_ids.has(id):
            continue
        var node := entry["node"] as CharacterBody3D
        if not is_instance_valid(node):
            continue
        var distance := from.distance_to(node.global_position)
        if distance < best_distance:
            best_distance = distance
            best = entry
    return best

func _spawn_gem_drop(position: Vector3, gem_id: String) -> void:
    var gem := GemCatalog.get_gem(gem_id)
    if gem.is_empty():
        return
    var node := MeshInstance3D.new()
    node.name = "GemDrop_%s" % gem_id
    var mesh := SphereMesh.new()
    mesh.radius = 0.24
    mesh.height = 0.46
    node.mesh = mesh
    node.position = position + Vector3(0.0, 0.45, 0.0)
    var mat := StandardMaterial3D.new()
    var color := GemCatalog.gem_color(gem_id)
    mat.albedo_color = color
    mat.emission_enabled = true
    mat.emission = color
    mat.emission_energy_multiplier = 3.0
    node.material_override = mat
    loot_root.add_child(node)

    var label := Label3D.new()
    label.text = String(gem["name"])
    label.position = Vector3(0.0, 0.62, 0.0)
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.font_size = 22
    label.outline_size = 7
    node.add_child(label)

    loot_drops.append({"node": node, "gem_id": gem_id, "phase": randf() * TAU, "base_y": node.position.y})

func _update_loot(delta: float) -> void:
    for i in range(loot_drops.size() - 1, -1, -1):
        var entry: Dictionary = loot_drops[i]
        var node := entry["node"] as MeshInstance3D
        if not is_instance_valid(node):
            loot_drops.remove_at(i)
            continue
        entry["phase"] = float(entry["phase"]) + delta * 2.5
        node.rotation.y += delta * 1.8
        node.position.y = float(entry["base_y"]) + sin(float(entry["phase"])) * 0.10
        loot_drops[i] = entry
        if player.global_position.distance_to(node.global_position) < 1.35:
            var gem_id := String(entry["gem_id"])
            gem_stash.append(gem_id)
            var gem := GemCatalog.get_gem(gem_id)
            hint_label.text = "拾取：%s" % String(gem.get("name", gem_id))
            node.queue_free()
            loot_drops.remove_at(i)
            _refresh_gem_ui()

func _build_profile() -> Dictionary:
    var profile := {
        "active_id": "",
        "damage": 1.0,
        "cooldown": 1.0,
        "projectiles": 0,
        "chain": 0,
        "pierce": 0,
        "forks": 0,
        "fork_damage": 1.0,
        "splash": 0.0,
        "splash_damage": 0.0,
        "speed": 1.0,
        "life": 1.0,
        "projectile_color": "65a9ff",
    }

    for gem_id in socket_gems:
        if gem_id.is_empty():
            continue
        var gem := GemCatalog.get_gem(gem_id)
        if String(gem.get("kind", "")) == "active":
            profile["active_id"] = gem_id
            var active: Dictionary = gem.get("active", {})
            profile["damage"] = float(profile["damage"]) * float(active.get("damage", 1.0))
            profile["projectiles"] = int(profile["projectiles"]) + int(active.get("projectiles", 0))
            profile["chain"] = int(profile["chain"]) + int(active.get("chain", 0))
            profile["pierce"] = int(profile["pierce"]) + int(active.get("pierce", 0))
            profile["speed"] = float(profile["speed"]) * float(active.get("speed", 1.0))
            profile["projectile_color"] = String(active.get("projectile_color", "65a9ff"))
            break

    if String(profile["active_id"]).is_empty():
        return profile

    for gem_id in socket_gems:
        if gem_id.is_empty():
            continue
        var gem := GemCatalog.get_gem(gem_id)
        if String(gem.get("kind", "")) != "support":
            continue
        var support: Dictionary = gem.get("support", {})
        profile["damage"] = float(profile["damage"]) * float(support.get("damage", 1.0))
        profile["cooldown"] = float(profile["cooldown"]) * float(support.get("cooldown", 1.0))
        profile["projectiles"] = int(profile["projectiles"]) + int(support.get("projectiles", 0))
        profile["chain"] = int(profile["chain"]) + int(support.get("chain", 0))
        profile["pierce"] = int(profile["pierce"]) + int(support.get("pierce", 0))
        profile["forks"] = int(profile["forks"]) + int(support.get("forks", 0))
        profile["fork_damage"] = float(profile["fork_damage"]) * float(support.get("fork_damage", 1.0))
        profile["splash"] = maxf(float(profile["splash"]), float(support.get("splash", 0.0)))
        profile["splash_damage"] = maxf(float(profile["splash_damage"]), float(support.get("splash_damage", 0.0)))
        profile["speed"] = float(profile["speed"]) * float(support.get("speed", 1.0))
        profile["life"] = float(profile["life"]) * float(support.get("life", 1.0))

    return profile

func _toggle_gem_panel() -> void:
    gem_panel.visible = not gem_panel.visible
    if gem_panel.visible:
        joystick_vector = Vector2.ZERO
        _set_joystick_visual(joystick_vector)
        _refresh_gem_ui()

func _on_socket_pressed(index: int) -> void:
    if index < 0 or index >= socket_gems.size():
        return
    if not selected_stash_gem.is_empty():
        var replaced := socket_gems[index]
        if not replaced.is_empty():
            gem_stash.append(replaced)
        socket_gems[index] = selected_stash_gem
        var selected_index := gem_stash.find(selected_stash_gem)
        if selected_index != -1:
            gem_stash.remove_at(selected_index)
        selected_stash_gem = ""
    elif not socket_gems[index].is_empty():
        gem_stash.append(socket_gems[index])
        socket_gems[index] = ""
    _refresh_gem_ui()
    _refresh_hud()

func _on_stash_pressed(gem_id: String) -> void:
    selected_stash_gem = "" if selected_stash_gem == gem_id else gem_id
    _refresh_gem_ui()

func _refresh_gem_ui() -> void:
    if not is_instance_valid(gem_stash_box):
        return

    for i in range(socket_buttons.size()):
        var button := socket_buttons[i]
        var gem_id := socket_gems[i]
        if gem_id.is_empty():
            button.text = "○\n空孔"
            button.add_theme_color_override("font_color", Color(0.70, 0.72, 0.76))
            button.add_theme_stylebox_override("normal", _round_style(Color(0.07, 0.075, 0.09, 0.96), 34))
        else:
            var gem := GemCatalog.get_gem(gem_id)
            button.text = "%s\n%s" % [String(gem.get("icon", "◆")), String(gem.get("name", gem_id))]
            var color := GemCatalog.gem_color(gem_id)
            button.add_theme_color_override("font_color", color.lightened(0.18))
            button.add_theme_stylebox_override("normal", _round_style(Color(color.r * 0.22, color.g * 0.22, color.b * 0.22, 0.98), 34))
        button.add_theme_font_size_override("font_size", 11)

    for child in gem_stash_box.get_children():
        child.queue_free()

    if gem_stash.is_empty():
        var empty := Label.new()
        empty.text = "背包暫時沒有寶石；擊殺怪物後有機率掉落。"
        empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        gem_stash_box.add_child(empty)
    else:
        for gem_id in gem_stash:
            var gem := GemCatalog.get_gem(gem_id)
            var row := Button.new()
            row.focus_mode = Control.FOCUS_NONE
            row.text = "%s  %s · %s" % [String(gem.get("icon", "◆")), String(gem.get("name", gem_id)), _kind_name(String(gem.get("kind", "")))]
            row.custom_minimum_size = Vector2(0.0, 44.0)
            var color := GemCatalog.gem_color(gem_id)
            row.add_theme_color_override("font_color", color.lightened(0.22))
            if selected_stash_gem == gem_id:
                row.add_theme_stylebox_override("normal", _round_style(Color(color.r * 0.32, color.g * 0.32, color.b * 0.32, 0.98), 12))
            else:
                row.add_theme_stylebox_override("normal", _round_style(Color(0.06, 0.07, 0.09, 0.96), 12))
            row.pressed.connect(_on_stash_pressed.bind(gem_id))
            gem_stash_box.add_child(row)

func _kind_name(kind: String) -> String:
    if kind == "active":
        return "主動"
    if kind == "support":
        return "輔助"
    return kind

func _refresh_hud() -> void:
    if not is_instance_valid(status_label):
        return
    hp_bar.value = player_hp
    status_label.text = "生命 %d/%d   擊殺 %d" % [int(player_hp), int(player_max_hp), kills]
    var profile := _build_profile()
    var active_name := "未裝主動"
    if not String(profile["active_id"]).is_empty():
        var active := GemCatalog.get_gem(String(profile["active_id"]))
        active_name = String(active.get("name", profile["active_id"]))
    var supports := 0
    for gem_id in socket_gems:
        if not gem_id.is_empty() and String(GemCatalog.get_gem(gem_id).get("kind", "")) == "support":
            supports += 1
    build_label.text = "%s · %d 個連線輔助 · 投射 %d · 連鎖 %d" % [active_name, supports, 1 + int(profile["projectiles"]), int(profile["chain"])]

func debug_install_gem(gem_id: String, socket_index: int) -> void:
    if socket_index < 0 or socket_index >= socket_gems.size():
        return
    socket_gems[socket_index] = gem_id
    _refresh_gem_ui()
    _refresh_hud()

func debug_build_profile() -> Dictionary:
    return _build_profile()

func _unhandled_input(event: InputEvent) -> void:
    if gem_panel.visible:
        return

    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
        _fire()
        get_viewport().set_input_as_handled()
        return

    if event is InputEventScreenTouch:
        if event.pressed and joystick_touch_id == -1:
            var center := joystick_back.position + joystick_back.size * 0.5
            if event.position.distance_to(center) <= 92.0:
                joystick_touch_id = event.index
                _update_joystick(event.position)
                get_viewport().set_input_as_handled()
        elif not event.pressed and event.index == joystick_touch_id:
            joystick_touch_id = -1
            joystick_vector = Vector2.ZERO
            _set_joystick_visual(joystick_vector)
            get_viewport().set_input_as_handled()

    elif event is InputEventScreenDrag and event.index == joystick_touch_id:
        _update_joystick(event.position)
        get_viewport().set_input_as_handled()

    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        var center := joystick_back.position + joystick_back.size * 0.5
        if event.pressed and event.position.distance_to(center) <= 92.0:
            joystick_touch_id = -2
            _update_joystick(event.position)
        elif not event.pressed and joystick_touch_id == -2:
            joystick_touch_id = -1
            joystick_vector = Vector2.ZERO
            _set_joystick_visual(joystick_vector)

    elif event is InputEventMouseMotion and joystick_touch_id == -2 and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
        _update_joystick(event.position)

func _update_joystick(screen_pos: Vector2) -> void:
    var center := joystick_back.position + joystick_back.size * 0.5
    var delta := screen_pos - center
    if delta.length() > JOYSTICK_RADIUS:
        delta = delta.normalized() * JOYSTICK_RADIUS
    joystick_vector = delta / JOYSTICK_RADIUS
    _set_joystick_visual(joystick_vector)

func _set_joystick_visual(value: Vector2) -> void:
    if not is_instance_valid(joystick_knob):
        return
    var center := joystick_back.size * 0.5
    var knob_half := joystick_knob.size * 0.5
    joystick_knob.position = center - knob_half + value * JOYSTICK_RADIUS
