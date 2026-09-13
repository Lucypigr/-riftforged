extends Node3D

const PLAYER_SPEED := 6.0
const ENEMY_SPEED := 2.1
const PROJECTILE_SPEED := 14.0
const PROJECTILE_LIFE := 1.4
const JOYSTICK_RADIUS := 50.0

var player: CharacterBody3D
var enemy: CharacterBody3D
var camera: Camera3D
var enemy_hp := 60.0
var projectiles: Array[Dictionary] = []
var joystick_vector := Vector2.ZERO
var joystick_touch_id := -1
var ui_layer: CanvasLayer
var joystick_back: Panel
var joystick_knob: Panel
var attack_button: Button
var status_label: Label
var hint_label: Label
var _respawn_timer := 0.0

func _ready() -> void:
    _build_world()
    _build_player()
    _build_enemy()
    _build_ui()
    get_viewport().size_changed.connect(_layout_ui)
    _layout_ui()

func _build_world() -> void:
    var world := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.035, 0.045, 0.055)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.50, 0.58, 0.70)
    env.ambient_light_energy = 0.65
    world.environment = env
    world.name = "WorldEnvironment"
    add_child(world)

    var light := DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-55.0, -25.0, 0.0)
    light.light_energy = 1.2
    light.shadow_enabled = true
    light.name = "KeyLight"
    add_child(light)

    var floor_mesh := MeshInstance3D.new()
    var plane := PlaneMesh.new()
    plane.size = Vector2(46.0, 46.0)
    floor_mesh.mesh = plane
    var floor_mat := StandardMaterial3D.new()
    floor_mat.albedo_color = Color(0.10, 0.14, 0.12)
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

    var prop_positions := [
        Vector3(-5.0, 0.6, -4.0), Vector3(5.5, 0.6, 4.0),
        Vector3(-7.0, 0.6, 5.0), Vector3(7.0, 0.6, -5.5),
        Vector3(0.0, 0.6, -8.0), Vector3(-1.0, 0.6, 8.0)
    ]
    for i in range(prop_positions.size()):
        var prop := MeshInstance3D.new()
        var prop_mesh := BoxMesh.new()
        prop_mesh.size = Vector3(1.25, 1.2 + float(i % 2) * 0.5, 1.25)
        prop.mesh = prop_mesh
        prop.position = prop_positions[i]
        var prop_mat := StandardMaterial3D.new()
        prop_mat.albedo_color = Color(0.20 + i * 0.012, 0.18, 0.16)
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

func _build_enemy() -> void:
    if is_instance_valid(enemy):
        enemy.queue_free()
    enemy = CharacterBody3D.new()
    enemy.name = "Enemy"
    enemy.position = Vector3(5.0, 0.0, -4.0)
    add_child(enemy)

    var enemy_shape := CollisionShape3D.new()
    var shape := CapsuleShape3D.new()
    shape.radius = 0.5
    shape.height = 1.55
    enemy_shape.shape = shape
    enemy_shape.position.y = 0.78
    enemy.add_child(enemy_shape)

    var visual := _make_billboard(Color(0.68, 0.25, 0.72), Vector2(1.2, 1.85))
    visual.name = "EnemyBillboard"
    visual.position.y = 0.98
    enemy.add_child(visual)

    var label := Label3D.new()
    label.name = "EnemyLabel"
    label.text = "裂隙獸 60"
    label.position = Vector3(0.0, 2.2, 0.0)
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.font_size = 28
    label.outline_size = 8
    label.modulate = Color(1.0, 0.85, 0.95)
    enemy.add_child(label)
    enemy_hp = 60.0

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

    status_label = Label.new()
    status_label.name = "Status"
    status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status_label.add_theme_font_size_override("font_size", 18)
    status_label.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0))
    status_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
    status_label.add_theme_constant_override("shadow_offset_x", 2)
    status_label.add_theme_constant_override("shadow_offset_y", 2)
    ui_layer.add_child(status_label)

    hint_label = Label.new()
    hint_label.name = "Hint"
    hint_label.text = "左下拖曳移動 · 右下攻擊 · 鍵盤 WASD / Space 也可測"
    hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint_label.add_theme_font_size_override("font_size", 14)
    hint_label.add_theme_color_override("font_color", Color(0.75, 0.80, 0.86))
    ui_layer.add_child(hint_label)

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
    style.border_color = Color(1.0, 1.0, 1.0, 0.10)
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

    status_label.position = Vector2(12.0, 18.0)
    status_label.size = Vector2(viewport_size.x - 24.0, 54.0)
    hint_label.position = Vector2(12.0, 72.0)
    hint_label.size = Vector2(viewport_size.x - 24.0, 42.0)

    var aspect: float = viewport_size.x / maxf(viewport_size.y, 1.0)
    var orientation: String = "直立" if viewport_size.y >= viewport_size.x else "橫向"
    status_label.text = "Godot 4.7.2 · 2.5D 原型 · %s · %.2f aspect\nCamera KEEP_WIDTH / Orthographic" % [orientation, aspect]

func _physics_process(delta: float) -> void:
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
    player.position.x = clamp(player.position.x, -20.0, 20.0)
    player.position.z = clamp(player.position.z, -20.0, 20.0)

    _update_enemy(delta)
    _update_projectiles(delta)

func _update_enemy(delta: float) -> void:
    if not is_instance_valid(enemy):
        if _respawn_timer > 0.0:
            _respawn_timer -= delta
            if _respawn_timer <= 0.0:
                _build_enemy()
        return
    var to_player := player.global_position - enemy.global_position
    to_player.y = 0.0
    if to_player.length() > 2.2:
        enemy.velocity = to_player.normalized() * ENEMY_SPEED
        enemy.move_and_slide()
    else:
        enemy.velocity = Vector3.ZERO

func _fire() -> void:
    if not is_instance_valid(enemy):
        return
    var origin := player.global_position + Vector3(0.0, 0.75, 0.0)
    var target := enemy.global_position + Vector3(0.0, 0.75, 0.0)
    var direction := (target - origin).normalized()
    var projectile := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 0.15
    sphere.height = 0.30
    projectile.mesh = sphere
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.35, 0.78, 1.0)
    mat.emission_enabled = true
    mat.emission = Color(0.20, 0.60, 1.0)
    mat.emission_energy_multiplier = 2.0
    projectile.material_override = mat
    projectile.position = origin
    projectile.name = "Projectile"
    add_child(projectile)
    projectiles.append({"node": projectile, "velocity": direction * PROJECTILE_SPEED, "life": PROJECTILE_LIFE})

func _update_projectiles(delta: float) -> void:
    for i in range(projectiles.size() - 1, -1, -1):
        var entry: Dictionary = projectiles[i]
        var node: MeshInstance3D = entry["node"]
        if not is_instance_valid(node):
            projectiles.remove_at(i)
            continue
        var velocity: Vector3 = entry["velocity"]
        node.position += velocity * delta
        entry["life"] = float(entry["life"]) - delta
        projectiles[i] = entry
        if is_instance_valid(enemy) and node.global_position.distance_to(enemy.global_position + Vector3(0.0, 0.75, 0.0)) < 0.72:
            _damage_enemy(20.0)
            node.queue_free()
            projectiles.remove_at(i)
        elif float(entry["life"]) <= 0.0:
            node.queue_free()
            projectiles.remove_at(i)

func _damage_enemy(amount: float) -> void:
    if not is_instance_valid(enemy):
        return
    enemy_hp -= amount
    var label := enemy.get_node_or_null("EnemyLabel") as Label3D
    if label:
        label.text = "裂隙獸 %d" % maxi(0, int(ceil(enemy_hp)))
    if enemy_hp <= 0.0:
        enemy.queue_free()
        enemy = null
        _respawn_timer = 1.0

func _unhandled_input(event: InputEvent) -> void:
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
