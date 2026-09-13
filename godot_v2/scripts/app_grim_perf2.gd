extends "res://scripts/app_grim_perf.gd"

# Second browser-performance pass: keep movement at 60 Hz while moving AI
# decisions, label visibility and ground-loot housekeeping off the hot path.

const AI_PHASES := 2
const MAX_GROUND_LOOT := 24
const LABEL_SCAN_MS := 180
const ENEMY_LABEL_DISTANCE_SQ := 240.25
const LOOT_LABEL_DISTANCE_SQ := 121.0

var _last_label_scan_ms := 0

func _spawn_enemy(force_elite: bool = false, slot: int = -1) -> void:
    super._spawn_enemy(force_elite, slot)
    if enemies.is_empty():
        return
    var index := enemies.size() - 1
    var entry: Dictionary = enemies[index]
    entry["ai_phase"] = int(entry["id"]) % AI_PHASES
    enemies[index] = entry

func _physics_process(delta: float) -> void:
    super._physics_process(delta)
    _update_label_visibility()

func _update_enemies(delta: float) -> void:
    var frame_phase := int(Engine.get_physics_frames()) % AI_PHASES
    for i in range(enemies.size() - 1, -1, -1):
        var entry: Dictionary = enemies[i]
        var enemy := entry["node"] as CharacterBody3D
        if not is_instance_valid(enemy):
            enemies.remove_at(i)
            continue

        entry["touch_cd"] = maxf(0.0, float(entry["touch_cd"]) - delta)
        entry["skill_cd"] = maxf(0.0, float(entry["skill_cd"]) - delta)

        var phase := int(entry.get("ai_phase", int(entry["id"]) % AI_PHASES))
        if phase != frame_phase:
            if enemy.velocity.length_squared() > 0.0001:
                enemy.move_and_slide()
            enemies[i] = entry
            continue

        var archetype: Dictionary = entry["archetype"]
        var to_player := player.global_position - enemy.global_position
        to_player.y = 0
        var distance := to_player.length()
        var direction := to_player.normalized() if distance > 0.001 else Vector3.ZERO
        var visual := entry["visual"] as Sprite3D
        if visual != null and absf(to_player.x) > 0.05:
            visual.flip_h = to_player.x > 0.0

        var trigger := float(archetype["low_health_trigger"])
        if not bool(entry["berserk"]) and trigger > 0.0 and float(entry["hp"]) / float(entry["max_hp"]) <= trigger:
            entry["berserk"] = true
            if visual != null:
                visual.modulate = Color(1.0, 0.30, 0.22)

        var speed := float(archetype["speed"])
        if bool(entry["berserk"]):
            speed *= float(archetype["berserk_speed"])

        if String(archetype["behavior"]) == "ranged":
            var desired := float(archetype["desired_range"])
            if distance > desired + 1.4:
                enemy.velocity = direction * speed
            elif distance < desired - 1.4:
                enemy.velocity = -direction * speed * 0.72
            else:
                enemy.velocity = Vector3.ZERO

            if float(entry["skill_cd"]) <= 0.0 and distance <= 8.5:
                entry["skill_cd"] = float(archetype["skill_delay"])
                if randf() <= float(archetype["skill_chance"]):
                    _enemy_cast_projectile(enemy, float(archetype["skill_damage"]))
        else:
            if distance > float(archetype["desired_range"]):
                enemy.velocity = direction * speed
            else:
                enemy.velocity = Vector3.ZERO
                if float(entry["touch_cd"]) <= 0.0:
                    var damage := float(archetype["touch_damage"])
                    if bool(entry["berserk"]):
                        damage *= 1.25
                    _damage_player(damage)
                    entry["touch_cd"] = float(archetype["touch_delay"])

        if enemy.velocity.length_squared() > 0.0001:
            enemy.move_and_slide()
        enemies[i] = entry

func _spawn_loot_visual(position: Vector3, item: Dictionary) -> void:
    super._spawn_loot_visual(position, item)
    while loot_drops.size() > MAX_GROUND_LOOT:
        var oldest: Dictionary = loot_drops[0]
        var node := oldest.get("node") as Node3D
        if is_instance_valid(node):
            node.queue_free()
        loot_drops.remove_at(0)

func _update_label_visibility() -> void:
    var now := Time.get_ticks_msec()
    if now - _last_label_scan_ms < LABEL_SCAN_MS:
        return
    _last_label_scan_ms = now

    for entry in enemies:
        var enemy := entry.get("node") as Node3D
        var label := entry.get("label") as Label3D
        if is_instance_valid(enemy) and is_instance_valid(label):
            label.visible = player.global_position.distance_squared_to(enemy.global_position) <= ENEMY_LABEL_DISTANCE_SQ

    for entry in loot_drops:
        var drop := entry.get("node") as Node3D
        if not is_instance_valid(drop):
            continue
        var distance_sq := player.global_position.distance_squared_to(drop.global_position)
        for child in drop.get_children():
            if child is Label3D:
                (child as Label3D).visible = distance_sq <= LOOT_LABEL_DISTANCE_SQ

func debug_perf_pass2() -> Dictionary:
    return {
        "ai_phases": AI_PHASES,
        "loot_cap": MAX_GROUND_LOOT,
        "label_scan_ms": LABEL_SCAN_MS,
    }
