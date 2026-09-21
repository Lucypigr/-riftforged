extends Node
# Bounded, delta-driven persistent effects. No timers retain dead enemy references.
const Gems = preload("res://scripts/linked_gem_system.gd")
const MAX_EFFECTS := 24
var host
var effects: Array[Dictionary] = []
var hit_count := 0
var last_profile: Dictionary = {}

func profile(gem: Dictionary, gear: Dictionary, index: int) -> Dictionary:
    var info := Gems.data(gem)
    var supports := Gems.support_ids(gear, index)
    var duration := float(info.get("duration", 0.0))
    if supports.has("increased_duration_support"):
        duration *= 1.5
    if supports.has("swift_affliction_support"):
        duration *= 0.7
    return {"id":String(gem.id), "behavior":String(info.behavior), "damage":Gems.skill_damage(gear, index),
        "radius":Gems.skill_radius(gear, index, float(info.get("radius", 0.0))), "duration":duration,
        "supports":supports, "cold":info.tags.has("cold"), "count":int(info.get("count", 1)) + (2 if supports.has("volley_support") else 0),
        "range":float(info.get("max_range", 10.0)), "color":host._gem_color(String(gem.color))}

func cast(gem: Dictionary, gear: Dictionary, index: int) -> void:
    var p := profile(gem, gear, index)
    p.damage *= 0.85 if host._aura_enabled else 1.0
    p["direction"] = host.last_aim_direction.normalized()
    p["origin"] = host.player.global_position
    p["point"] = host._aim_point
    last_profile = p.duplicate(true)
    var behavior := String(p.behavior)
    if behavior == "projectile":
        shoot(p)
        if p.supports.has("echo_support"):
            var echo := p.duplicate(true)
            echo.behavior = "echo"
            add_effect(echo, p.origin, 0.18)
    elif behavior == "cone":
        host._v3_hit_cone(p.origin, p.direction, p.radius, 0.15, p.damage, p.supports)
        host._spawn_hit_flash(p.origin + p.direction * 2.0 + Vector3.UP, p.color, p.radius)
    elif behavior == "wave":
        for i in range(3):
            var wave := p.duplicate(true)
            wave.behavior = "delayed"
            add_effect(wave, p.origin + p.direction * float(2 + i * 3), 0.12 + i * 0.15)
    elif behavior == "delayed":
        add_effect(p, p.point, p.duration)
    elif behavior == "totem":
        var count := 2 if p.supports.has("multiple_totems_support") else 1
        for i in range(count):
            enforce_cap(behavior, 3 if count == 2 else 1)
            var point: Vector3 = p.point + Vector3(float(i) * 1.2, 0, 0)
            add_effect(p.duplicate(true), host.region_map.clamp_player(point), p.duration)
    else:
        if behavior in ["orbit", "beam"]:
            erase_id(String(p.id))
        if behavior == "minion":
            enforce_cap(behavior, 3)
        if behavior in ["zone", "travelling"]:
            enforce_cap(behavior, 6)
        add_effect(p, p.origin if behavior in ["orbit", "beam", "travelling"] else p.point, p.duration)

func shoot(p: Dictionary) -> void:
    var before: Vector3 = host.last_aim_direction
    host.last_aim_direction = p.direction
    host._v3_projectiles(p.origin, p.damage, p.count, p.range, p.supports, p.radius, p.cold, p.color)
    host.last_aim_direction = before

func add_effect(p: Dictionary, point: Vector3, lifetime: float) -> void:
    if effects.size() >= MAX_EFFECTS:
        remove_effect(0)
    var node := MeshInstance3D.new()
    var cylinder := CylinderMesh.new()
    var construct := String(p.behavior) in ["totem", "minion"]
    cylinder.top_radius = 0.25 if construct else maxf(0.25, float(p.radius))
    cylinder.bottom_radius = 0.55 if construct else cylinder.top_radius
    cylinder.height = 1.4 if construct else 0.07
    node.mesh = cylinder
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.albedo_color = Color(p.color, 0.8 if construct else 0.22)
    node.material_override = material
    node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    host.projectiles_root.add_child(node)
    node.global_position = point + Vector3(0, 0.7 if construct else 0.09, 0)
    p["node"] = node
    p["position"] = point
    p["left"] = lifetime
    p["tick"] = 0.0
    p["travelled"] = 0.0
    effects.append(p)

func _physics_process(delta: float) -> void:
    if not is_instance_valid(host) or host.player == null or host._inventory_open():
        return
    advance(delta)

func advance(delta: float) -> void:
    for i in range(effects.size() - 1, -1, -1):
        var p := effects[i]
        p.left -= delta
        p.tick -= delta
        var behavior := String(p.behavior)
        if behavior in ["orbit", "beam"]:
            p.position = host.player.global_position
        elif behavior == "travelling":
            var step_distance := minf(delta * 5.0, maxf(0.0, float(p.range) - float(p.travelled)))
            p.travelled += step_distance
            if step_distance <= 0.00001:
                remove_effect(i)
                continue
            var requested: Vector3 = p.position + p.direction * step_distance
            var bounded: Vector3 = host.region_map.clamp_player(requested)
            if bounded.distance_to(requested) > 0.1 or blocked(p.position, bounded):
                remove_effect(i)
                continue
            p.position = bounded
        elif behavior == "minion":
            var target := nearest(p.position, 12.0)
            if target >= 0:
                var target_pos: Vector3 = host.enemies[target].node.global_position
                var next: Vector3 = host.region_map.clamp_player(p.position.move_toward(target_pos, delta * 4.5))
                if not blocked(p.position, next):
                    p.position = next
                else:
                    # Slide around obstructions; when trapped wait until target moves.
                    var direction: Vector3 = (target_pos - p.position).normalized()
                    for angle in [PI / 2.0, -PI / 2.0]:
                        var side: Vector3 = host.region_map.clamp_player(p.position + direction.rotated(Vector3.UP, angle) * delta * 4.5)
                        if not blocked(p.position, side):
                            p.position = side
                            break
        if is_instance_valid(p.node):
            p.node.global_position = p.position + Vector3(0, 0.7 if behavior in ["minion", "totem"] else 0.09, 0)
            p.node.rotation.y += delta * 2.0
        if behavior in ["delayed", "echo"]:
            if p.left <= 0.0:
                if behavior == "echo":
                    shoot(p)
                else:
                    damage_area(p, p.position)
                remove_effect(i)
            continue
        if p.tick <= 0.0:
            p.tick = 0.65 if behavior in ["totem", "minion"] else 0.4
            if behavior == "totem":
                var target := nearest(p.position, 9.0)
                if target >= 0:
                    damage_area(p, host.enemies[target].node.global_position)
            elif behavior == "beam":
                host._v3_hit_cone(p.position, p.direction, p.radius, 0.94, p.damage, p.supports)
                host._spawn_hit_flash(p.position + p.direction * 3.0 + Vector3.UP, p.color, 1.0)
            else:
                damage_area(p, p.position)
        if p.left <= 0.0:
            remove_effect(i)

func damage_area(p: Dictionary, point: Vector3) -> void:
    hit_count += 1
    host._v3_damage_area(point, p.radius, p.damage, p.cold, p.supports)
    host._spawn_hit_flash(point + Vector3(0, 0.3, 0), p.color, minf(4.0, p.radius))

func nearest(point: Vector3, reach: float) -> int:
    var best := -1
    var distance := reach
    for i in range(host.enemies.size()):
        var enemy: Dictionary = host.enemies[i]
        if not is_instance_valid(enemy.get("node")) or float(enemy.get("hp", 0)) <= 0:
            continue
        var d: float = enemy.node.global_position.distance_to(point)
        if d < distance and not blocked(point, enemy.node.global_position):
            best = i
            distance = d
    return best

func enforce_cap(behavior: String, cap: int) -> void:
    var matching: Array[int] = []
    for i in range(effects.size()):
        if String(effects[i].behavior) == behavior:
            matching.append(i)
    if matching.size() >= cap:
        remove_effect(matching[0])

func erase_id(id: String) -> void:
    for i in range(effects.size() - 1, -1, -1):
        if String(effects[i].id) == id:
            remove_effect(i)

func remove_effect(index: int) -> void:
    var node = effects[index].get("node")
    if is_instance_valid(node):
        node.queue_free()
    effects.remove_at(index)

func clear() -> void:
    for i in range(effects.size() - 1, -1, -1):
        remove_effect(i)

func blocked(from: Vector3, to: Vector3) -> bool:
    if from.distance_squared_to(to) < 0.00001:
        return false
    var ray := PhysicsRayQueryParameters3D.create(from + Vector3(0, 0.8, 0), to + Vector3(0, 0.8, 0))
    var excluded: Array[RID] = [host.player.get_rid()]
    for enemy in host.enemies:
        if is_instance_valid(enemy.get("node")):
            excluded.append(enemy.node.get_rid())
    ray.exclude = excluded
    return not host.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
