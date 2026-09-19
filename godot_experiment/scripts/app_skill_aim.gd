extends "res://scripts/app_hotbar_safe.gd"

const AimHUD = preload("res://scripts/skill_aim_hud.gd")
const AimRules = preload("res://scripts/skill_aim_rules.gd")
const FLIGHT_HEIGHT := 1.0
const FLIGHT_SPEED_BASE := 11.5

var _aim_override := false
var _aim_direction := Vector3(1.0, 0.0, 0.0)
var _aim_point := Vector3.ZERO
var _aim_releases := 0
var _aim_shot_history: Array[Dictionary] = []

func _build_ui() -> void:
    ui = AimHUD.new()
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

func _refresh_gameplay_ui() -> void:
    super._refresh_gameplay_ui()
    var hud := ui as RiftSkillAimHUD
    if hud == null:
        return
    var modes: Array[Dictionary] = []
    for entry in _hotbar_entries():
        if String(entry.get("kind", "")) == "gem":
            modes.append(AimRules.descriptor(entry.get("gem", {})))
        else:
            modes.append({"mode":"direction", "range":_weapon_range()} if String(entry.get("kind", "")) == "basic" else {"mode":"none", "range":0.0})
    hud.set_aim_modes(modes)

func _finish_touch_aim(slot: int, drag_pixels: Vector2) -> void:
    if _inventory_open() or player == null:
        return
    var entries := _hotbar_entries()
    if slot < 0 or slot >= entries.size():
        return
    var entry: Dictionary = entries[slot]
    if String(entry.get("kind", "")) == "basic":
        last_aim_direction = _screen_drag_direction(drag_pixels)
        _aim_releases += 1
        _attack()
        return
    if String(entry.get("kind", "")) != "gem":
        return
    var spec := AimRules.descriptor(entry.get("gem", {}))
    var mode := String(spec.get("mode", "none"))
    if not AimRules.needs_drag(mode):
        return
    var direction := _screen_drag_direction(drag_pixels)
    _aim_direction = direction
    _aim_point = player.global_position + direction * minf(4.0, float(spec.get("range", 0.0)))
    if mode == "point" and drag_pixels.length_squared() > 0.0:
        var requested := player.global_position + Vector3(drag_pixels.x, 0, drag_pixels.y) / RiftSkillAimHUD.PIXELS_PER_WORLD_UNIT
        _aim_point = AimRules.limit_point(player.global_position, requested, float(spec.get("range", 0.0)))
    if region_map != null:
        _aim_point = region_map.clamp_player(_aim_point)
    _aim_override = true
    _aim_releases += 1
    _use_skill(slot)
    _aim_override = false

func _use_skill(slot: int) -> void:
    if _inventory_open() or player == null:
        return
    var entries := _hotbar_entries()
    if slot < 0 or slot >= entries.size():
        return
    var entry: Dictionary = entries[slot]
    if String(entry.get("kind", "")) != "gem":
        super._use_skill(slot)
        return
    var spec := AimRules.descriptor(entry.get("gem", {}))
    var mode := String(spec.get("mode", "none"))
    if AimRules.needs_drag(mode):
        if not _aim_override and not _mobile_controls() and camera != null:
            var ground := _screen_to_ground(get_viewport().get_mouse_position())
            var offset := ground - player.global_position
            _aim_direction = AimRules.valid_direction(offset, last_aim_direction)
            _aim_point = AimRules.limit_point(player.global_position, ground, float(spec.get("range", 0.0)))
            if region_map != null:
                _aim_point = region_map.clamp_player(_aim_point)
            _aim_override = true
        elif not _aim_override:
            _aim_direction = AimRules.valid_direction(last_aim_direction, Vector3(1, 0, 0))
        last_aim_direction = _aim_direction
        if player_visual != null and absf(last_aim_direction.x) > 0.02:
            player_visual.flip_h = last_aim_direction.x < 0.0
    super._use_skill(slot)
    _aim_override = false

func _movement_direction() -> Vector3:
    # Dashes follow the locked skill aim, not the simultaneous left thumbstick.
    if _aim_override:
        return _aim_direction
    return super._movement_direction()

func _cast_socket_bolts(socket_index: int) -> void:
    var equipment: Dictionary = _casting_equipment if not _casting_equipment.is_empty() else equipped_weapon
    var damage := GemSystem.skill_damage(equipment, socket_index) * (0.85 if _aura_enabled else 1.0)
    var supports := GemSystem.support_ids(equipment, socket_index)
    var count := 3 if supports.has("multishot") else 1
    _launch_projectiles(player.global_position, damage, count, float(AimRules.AIM["ember_bolt"]["range"]), supports, 1.6, false, Color(1.0, 0.38, 0.15), 0.0, "ember")
    ui.set_hint("緋紅火球：固定射程 %.1f｜%d 顆｜連鎖 %d" % [float(AimRules.AIM["ember_bolt"]["range"]), count, 2 if supports.has("chain") else 0])

func _v3_projectiles(origin: Vector3, damage: float, count: int, reach: float, supports: Array[String], area: float, cold: bool, color: Color, burn_ratio: float = 0.0) -> void:
    # V3's previous version collected nearest enemy IDs and aimed the initial
    # projectile at each one. A fixed world-space line now owns its hit tests.
    var total := count + (2 if supports.has("multishot") else 0)
    _launch_projectiles(origin, damage, total, reach, supports, area, cold, color, burn_ratio, "v3")

func _launch_projectiles(origin: Vector3, damage: float, count: int, reach: float, supports: Array[String], area: float, cold: bool, color: Color, burn_ratio: float, kind: String) -> void:
    if player == null or projectiles_root == null:
        return
    var base := AimRules.valid_direction(last_aim_direction, Vector3(1, 0, 0))
    var amount := maxi(1, count)
    for n in range(amount):
        projectile_serial += 1
        var angle := (float(n) - float(amount - 1) * 0.5) * 0.22
        var direction := base.rotated(Vector3.UP, angle).normalized()
        var start := origin + Vector3(0, FLIGHT_HEIGHT, 0)
        var end := start + direction * reach
        var projectile := _create_orb("AimedSkillProjectile", color, color, 0.17, 0.28)
        projectiles_root.add_child(projectile)
        projectile.global_position = start
        var flight := {"node":projectile, "previous":start, "end":end, "range":reach, "direction":direction, "damage":damage, "supports":supports.duplicate(), "area":area, "cold":cold, "burn":burn_ratio, "kind":kind, "hits":[], "pierce":1 if supports.has("pierce_support") else 0, "done":false}
        _aim_shot_history.append({"kind":kind, "start":start, "end":end, "range":reach, "direction":direction})
        if _aim_shot_history.size() > 32:
            _aim_shot_history.pop_front()
        var duration := maxf(0.1, PROJECTILE_TRAVEL_TIME * reach / FLIGHT_SPEED_BASE) * (0.62 if supports.has("faster_projectiles_support") else 1.0)
        var flight_tween := create_tween()
        flight_tween.tween_method(_advance_projectile.bind(flight), start, end, duration)
        flight_tween.tween_callback(_finish_projectile.bind(flight))

func _advance_projectile(position: Vector3, flight: Dictionary) -> void:
    if bool(flight.get("done", false)):
        return
    var projectile := flight["node"] as Node3D
    if not is_instance_valid(projectile):
        flight["done"] = true
        return
    var previous: Vector3 = flight["previous"]
    var segment := position - previous
    projectile.global_position = position
    flight["previous"] = position
    if segment.length_squared() < 0.000001:
        return
    # Collision with the existing map's physical obstacles or boundary ends
    # the flight; the original V3 arrows have no homing/retargeting path.
    if region_map != null:
        var safe := region_map.clamp_player(Vector3(position.x, 0, position.z))
        if Vector2(safe.x - position.x, safe.z - position.z).length_squared() > 0.015:
            _finish_projectile(flight)
            return
    var query := PhysicsRayQueryParameters3D.create(previous, position)
    query.exclude = [player.get_rid()]
    var wall := get_world_3d().direct_space_state.intersect_ray(query)
    if not wall.is_empty() and wall.get("collider") is StaticBody3D:
        _finish_projectile(flight)
        return
    var candidates: Array[Dictionary] = []
    var hit_ids: Array = flight["hits"]
    var horizontal := Vector3(segment.x, 0, segment.z)
    var length2 := horizontal.length_squared()
    if length2 <= 0.000001:
        return
    for entry in enemies:
        var enemy := entry.get("node") as CharacterBody3D
        var id := int(entry.get("id", -1))
        if not is_instance_valid(enemy) or hit_ids.has(id):
            continue
        var to_enemy := enemy.global_position - previous
        to_enemy.y = 0
        var along := clampf(to_enemy.dot(horizontal) / length2, 0.0, 1.0)
        var lateral := (to_enemy - horizontal * along).length()
        if lateral <= (0.88 if bool(entry.get("elite", false)) else 0.72):
            candidates.append({"id":id, "fraction":along})
    candidates.sort_custom(func(a: Dictionary, b: Dictionary): return float(a["fraction"]) < float(b["fraction"]))
    for hit in candidates:
        var id := int(hit["id"])
        if hit_ids.has(id):
            continue
        hit_ids.append(id)
        _resolve_directional_hit(id, flight)
        if int(flight["pierce"]) <= 0:
            _finish_projectile(flight)
            break
        flight["pierce"] = int(flight["pierce"]) - 1

func _resolve_directional_hit(enemy_id: int, flight: Dictionary) -> void:
    var index := _enemy_index_by_id(enemy_id)
    if index < 0:
        return
    var node := enemies[index]["node"] as CharacterBody3D
    if not is_instance_valid(node):
        return
    var position := node.global_position
    var damage := float(flight["damage"])
    var supports: Array[String] = flight["supports"]
    if String(flight["kind"]) == "ember":
        _damage_enemy(index, damage)
        _damage_area(position, 1.6, damage * 0.38, enemy_id)
    else:
        _v3_hit_enemy(enemy_id, damage * (1.0 + float(flight["burn"])), bool(flight["cold"]), supports)
        if float(flight["area"]) > 0.0:
            _spawn_hit_flash(position + Vector3(0, 0.5, 0), Color(0.42, 0.73, 1.0) if bool(flight["cold"]) else Color(1.0, 0.35, 0.18), float(flight["area"]))
            _v3_damage_area(position, float(flight["area"]), damage * 0.40, bool(flight["cold"]), supports, enemy_id)
    if supports.has("chain"):
        _chain_from_impact(position, enemy_id, damage, bool(flight["cold"]), supports, flight["hits"])

func _chain_from_impact(position: Vector3, first_id: int, damage: float, cold: bool, supports: Array[String], hits: Array) -> void:
    var visited: Array = hits.duplicate()
    if not visited.has(first_id):
        visited.append(first_id)
    var center := position
    for hop in range(2):
        var target_id := -1
        var nearest := 5.8
        for entry in enemies:
            var enemy := entry.get("node") as CharacterBody3D
            var id := int(entry.get("id", -1))
            if not is_instance_valid(enemy) or visited.has(id):
                continue
            var distance := center.distance_to(enemy.global_position)
            if distance < nearest:
                nearest = distance
                target_id = id
        if target_id < 0:
            return
        var index := _enemy_index_by_id(target_id)
        if index < 0:
            return
        center = (enemies[index]["node"] as CharacterBody3D).global_position
        visited.append(target_id)
        _spawn_hit_flash(center + Vector3(0, 0.8, 0), Color(1.0, 0.47, 0.22), 1.5)
        _v3_hit_enemy(target_id, damage * pow(0.85, float(hop + 1)), cold, supports)

func _finish_projectile(flight: Dictionary) -> void:
    if bool(flight.get("done", false)):
        return
    flight["done"] = true
    var projectile := flight.get("node") as Node3D
    if is_instance_valid(projectile):
        _release_or_free_projectile(projectile)

func debug_skill_aim() -> Dictionary:
    return {"modes":(ui as RiftSkillAimHUD).debug_aim() if ui is RiftSkillAimHUD else {}, "releases":_aim_releases, "shots":_aim_shot_history.duplicate(true), "last_direction":last_aim_direction, "point":_aim_point}

func _screen_drag_direction(pixels: Vector2) -> Vector3:
    if camera == null or pixels.length_squared() < 0.01:
        return AimRules.valid_direction(last_aim_direction, Vector3.RIGHT)
    var center := get_viewport().get_visible_rect().size * 0.5
    return AimRules.valid_direction(_screen_to_ground(center + pixels) - _screen_to_ground(center), last_aim_direction)
