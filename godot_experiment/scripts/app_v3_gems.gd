extends "res://scripts/app_picture_equipment.gd"

# V3 uses the existing equipment, sockets, loot_root and gem inventory.
# Ground gems have a separate array so the existing equipment's 24-item cap
# can never delete a gemstone that the player has not picked up.
var gem_ground: Array[Dictionary] = []
var _gem_rng := RandomNumberGenerator.new()
var _last_gem_pickup_scan := 0
var _colder_until: Dictionary = {}
var _picked_gem_uids: Dictionary = {}

func _ready() -> void:
    _gem_rng.randomize()
    super._ready()

func _drop_loot(position: Vector3, entry: Dictionary, guaranteed: bool) -> void:
    var elite := bool(entry.get("elite", false))
    var boss := bool(entry.get("boss", false))
    # Preserve existing equipment/currency rates; parent gem roll used six fixed IDs.
    if guaranteed or randf() < (0.80 if elite or boss else 0.03):
        var archetype: Dictionary = entry.get("archetype", {})
        if not archetype.is_empty():
            var equipment: Array[Dictionary] = LootSystem.roll_master(String(archetype["loot_profile"]), int(archetype["level"]), elite, true)
            for item in equipment:
                _spawn_loot_visual(position + Vector3(randf_range(-0.45, 0.45), 0.0, randf_range(-0.45, 0.45)), item)
    if GemSystem.should_drop(_gem_rng, elite, boss):
        var gem_id := GemSystem.roll_drop_id(_gem_rng)
        if not gem_id.is_empty():
            _spawn_gem_ground(position, gem_id)
    if randf() < (0.75 if boss else (0.30 if elite else 0.07)):
        var kinds := ["jeweller", "fusing", "chromatic", "refine"]
        var kind: String = String(kinds[randi_range(0, kinds.size() - 1)])
        var names := {"jeweller":"開孔石", "fusing":"連結石", "chromatic":"幻色石", "refine":"精煉石"}
        _spawn_loot_visual(position + Vector3(randf_range(-0.8, 0.8), 0.0, randf_range(-0.8, 0.8)), {"id":"currency_" + kind, "slot":"通貨", "name":String(names[kind]), "rarity":"通貨", "color":Color(0.92, 0.75, 0.37), "currency":kind})

func _spawn_gem_ground(death_position: Vector3, gem_id: String) -> void:
    var gem := _make_gem(gem_id)
    if gem.is_empty() or loot_root == null:
        return
    var position := death_position + Vector3(_gem_rng.randf_range(-0.48, 0.48), 0.0, _gem_rng.randf_range(-0.48, 0.48))
    if region_map != null:
        position = region_map.clamp_player(position)
    loot_serial += 1
    var drop := Node3D.new()
    drop.name = "GemDrop_%d" % loot_serial
    loot_root.add_child(drop)
    drop.global_position = position
    var color := _gem_color(String(gem["color"]))
    var ring := MeshInstance3D.new()
    var base := CylinderMesh.new()
    base.top_radius = 0.39
    base.bottom_radius = 0.39
    base.height = 0.075
    ring.mesh = base
    ring.position.y = 0.11
    ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.emission_enabled = true
    material.emission = color
    material.emission_energy_multiplier = 2.8
    ring.material_override = material
    drop.add_child(ring)
    var crystal := MeshInstance3D.new()
    var shape := SphereMesh.new()
    shape.radius = 0.24
    shape.height = 0.47
    crystal.mesh = shape
    crystal.position.y = 0.40
    crystal.material_override = material
    crystal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    drop.add_child(crystal)
    var label := Label3D.new()
    label.name = "GemName"
    label.text = "◆ %s" % String(gem["name"])
    label.position = Vector3(0, 0.98, 0)
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.font = ui_font
    label.font_size = 30
    label.outline_size = 5
    label.modulate = color
    drop.add_child(label)
    var item := {"id":"gem_" + gem_id, "slot":"寶石", "name":String(gem["name"]), "rarity":"寶石", "color":color, "gem":gem.duplicate(true)}
    gem_ground.append({"node":drop, "item":item, "uid":int(gem["uid"])})

func _physics_process(delta: float) -> void:
    super._physics_process(delta)
    if player == null or (armor_ui != null and armor_ui.is_open()) or (gem_ui != null and gem_ui.is_open()):
        return
    var now := Time.get_ticks_msec()
    if now - _last_gem_pickup_scan >= 80:
        _last_gem_pickup_scan = now
        _update_gem_ground()

func _update_gem_ground() -> void:
    for i in range(gem_ground.size() - 1, -1, -1):
        var entry: Dictionary = gem_ground[i]
        var node := entry.get("node") as Node3D
        if not is_instance_valid(node):
            push_error("Gem ground object disappeared before pickup: %s" % str(entry.get("uid", 0)))
            gem_ground.remove_at(i)
            continue
        if player.global_position.distance_to(node.global_position) > LOOT_PICKUP_RANGE:
            continue
        var item: Dictionary = entry.get("item", {})
        var gem: Dictionary = item.get("gem", {})
        if not _receive_ground_gem(gem):
            continue
        gem_ground.remove_at(i)
        node.queue_free()
        picked_loot += 1
        _gem_message = "獲得寶石：%s" % String(gem["name"])
        ui.set_hint(_gem_message)
        _refresh_gem_ui()

func _receive_ground_gem(gem: Dictionary) -> bool:
    var uid := int(gem.get("uid", 0))
    if uid <= 0 or GemSystem.data(gem).is_empty() or _picked_gem_uids.has(uid):
        return false
    # Current gem stash has unlimited capacity; future limits must reject here
    # before the gem is removed from the ground.
    for stored in gem_inventory:
        if int(stored.get("uid", -1)) == uid:
            return false
    var before := gem_inventory.size()
    gem_inventory.append(gem.duplicate(true))
    if gem_inventory.size() != before + 1 or int(gem_inventory.back().get("uid", 0)) != uid:
        return false
    _picked_gem_uids[uid] = true
    return true

func _use_skill(slot: int) -> void:
    var entries := _hotbar_entries()
    if slot < 0 or slot >= entries.size():
        super._use_skill(slot)
        return
    var entry: Dictionary = entries[slot]
    var gem: Dictionary = entry["gem"]
    var id := String(gem.get("id", ""))
    var info: Dictionary = GemSystem.data(gem)
    if not bool(info.get("v3", false)):
        super._use_skill(slot)
        return
    if (armor_ui != null and armor_ui.is_open()) or (gem_ui != null and gem_ui.is_open()) or _is_region_map_open() or skill_cooldowns[slot] > 0.05:
        return
    var gear: Dictionary = (entry.get("equipment", equipped_weapon) as Dictionary).duplicate(true)
    gear["damage"] = float(equipped_weapon.get("damage", 0.0))
    var socket_index := int(entry["socket_index"])
    var cost := GemSystem.skill_mana(gear, socket_index)
    if player_mana + 0.001 < cost:
        ui.set_hint("魔力不足：%s" % String(gem["name"]))
        return
    player_mana -= cost
    var cd := GemSystem.skill_cooldown(gear, socket_index)
    skill_cooldowns[slot] = cd
    var uid := int(gem.get("uid", 0))
    if uid > 0:
        _gem_cooldowns[uid] = cd
    _cast_v3_skill(id, gem, gear, socket_index)
    _refresh_resource_hud()
    _refresh_gameplay_ui()

func _cast_v3_skill(id: String, gem: Dictionary, gear: Dictionary, socket_index: int) -> void:
    var info := GemSystem.data(gem)
    var supports := GemSystem.support_ids(gear, socket_index)
    var damage := GemSystem.skill_damage(gear, socket_index) * (0.85 if _aura_enabled else 1.0)
    if (info.get("tags", []) as Array).has("spell") and not supports.has("controlled_destruction_support") and randf() < float(equipped_weapon.get("crit_chance", 5.0)) / 100.0:
        damage *= 1.5
    var radius := GemSystem.skill_radius(gear, socket_index, 3.0)
    var origin := player.global_position
    var element_color := _gem_color(String(gem["color"]))
    var aimed := last_aim_direction
    if aimed.length_squared() < 0.01:
        aimed = Vector3(1, 0, 0)
    aimed = aimed.normalized()
    match id:
        "cleave", "ground_slam":
            var reach := GemSystem.skill_radius(gear, socket_index, 3.5 if id == "cleave" else 5.5)
            _v3_hit_cone(origin, aimed, reach, 0.05 if id == "cleave" else 0.3, damage, supports)
            _spawn_hit_flash(origin + aimed * (reach * 0.55) + Vector3(0, 0.65, 0), element_color, 4.0)
        "molten_strike":
            _v3_hit_cone(origin, aimed, GemSystem.skill_radius(gear, socket_index, 2.5), 0.1, damage, supports)
            _v3_projectiles(origin, damage * 0.55, 3, 6.5, supports, GemSystem.skill_radius(gear, socket_index, 1.4), false, element_color)
        "burning_arrow":
            _v3_projectiles(origin, damage, 1, 11.5, supports, 0.0, false, element_color, 0.30)
        "split_arrow":
            _v3_projectiles(origin, damage * 0.85, 3, 11.5, supports, 0.0, false, element_color)
        "ice_shot":
            _v3_projectiles(origin, damage, 1, 11.5, supports, radius * 0.60, true, element_color)
        "galvanic_arrow":
            _v3_projectiles(origin, damage * 0.80, 3, 8.0, supports, 0.0, false, element_color)
        "freezing_pulse":
            _v3_projectiles(origin, damage, 1, 10.0, supports, 0.7, true, element_color)
        "arc":
            var ids := _enemy_ids_in_range(10.0, 4)
            for i in range(ids.size()):
                var index := _enemy_index_by_id(ids[i])
                if index >= 0:
                    var target := enemies[index]["node"] as CharacterBody3D
                    _spawn_hit_flash(target.global_position + Vector3(0, 0.8, 0), element_color, 2.0)
                    _damage_enemy(index, damage * pow(0.82, float(i)))
        "frost_nova":
            _spawn_hit_flash(origin + Vector3(0, 0.5, 0), element_color, radius * 1.6)
            _v3_damage_area(origin, radius, damage, true, supports)
    ui.set_hint("%s｜傷害 %.1f｜連線輔助 %d" % [String(gem["name"]), damage, supports.size()])

func _v3_hit_cone(origin: Vector3, direction: Vector3, reach: float, min_dot: float, damage: float, supports: Array[String]) -> void:
    var ids := _enemy_ids_in_range(reach, 99)
    for id in ids:
        var index := _enemy_index_by_id(id)
        if index < 0:
            continue
        var target := enemies[index]["node"] as CharacterBody3D
        var offset := target.global_position - origin
        offset.y = 0
        if offset.length_squared() > 0.01 and offset.normalized().dot(direction) >= min_dot:
            _v3_hit_enemy(id, damage, false, supports)

func _v3_projectiles(origin: Vector3, damage: float, count: int, reach: float, supports: Array[String], area: float, cold: bool, color: Color, burn_ratio: float = 0.0) -> void:
    var total := count + (1 if supports.has("pierce_support") else 0)
    var targets := _enemy_ids_in_range(reach, total)
    for id in targets:
        var index := _enemy_index_by_id(id)
        if index < 0:
            continue
        var target := enemies[index]["node"] as CharacterBody3D
        var projectile := _create_orb("V3Projectile", color, color, 0.17, 0.28)
        projectiles_root.add_child(projectile)
        projectile.global_position = origin + Vector3(0, 1.0, 0)
        var destination := target.global_position + Vector3(0, 0.9, 0)
        var travel := PROJECTILE_TRAVEL_TIME * (0.62 if supports.has("faster_projectiles_support") else 1.0)
        var tween := create_tween()
        tween.tween_property(projectile, "global_position", destination, travel)
        tween.tween_callback(_v3_resolve_projectile.bind(id, projectile, damage, area, cold, supports, burn_ratio))
    for n in range(targets.size(), total):
        var angle := (float(n) - float(total - 1) * 0.5) * 0.24
        _spawn_miss_projectile(origin + last_aim_direction.rotated(Vector3.UP, angle) * reach + Vector3(0, 1.0, 0))

func _v3_resolve_projectile(enemy_id: int, projectile: Node3D, damage: float, area: float, cold: bool, supports: Array[String], burn_ratio: float) -> void:
    _release_or_free_projectile(projectile)
    var index := _enemy_index_by_id(enemy_id)
    if index < 0:
        return
    var pos := (enemies[index]["node"] as CharacterBody3D).global_position
    _v3_hit_enemy(enemy_id, damage * (1.0 + burn_ratio), cold, supports)
    if area > 0.0:
        _spawn_hit_flash(pos + Vector3(0, 0.5, 0), Color(0.42, 0.73, 1.0) if cold else Color(1.0, 0.35, 0.18), area)
        _v3_damage_area(pos, area, damage * 0.40, cold, supports, enemy_id)

func _v3_damage_area(center: Vector3, radius: float, damage: float, cold: bool, supports: Array[String], exclude: int = -1) -> void:
    var ids := _enemy_ids_in_range(9999.0, 999)
    for id in ids:
        if id == exclude:
            continue
        var index := _enemy_index_by_id(id)
        if index >= 0 and (enemies[index]["node"] as CharacterBody3D).global_position.distance_to(center) <= radius:
            _v3_hit_enemy(id, damage, cold, supports)

func _v3_hit_enemy(enemy_id: int, damage: float, cold: bool, supports: Array[String]) -> void:
    var index := _enemy_index_by_id(enemy_id)
    if index < 0:
        return
    if supports.has("hypothermia_support") and Time.get_ticks_msec() < int(_colder_until.get(enemy_id, -1)):
        damage *= 1.24
    if cold:
        _colder_until[enemy_id] = Time.get_ticks_msec() + 2100
    _damage_enemy(index, damage)

func debug_gem_ground_state() -> Dictionary:
    var entries: Array[Dictionary] = []
    for drop in gem_ground:
        var item: Dictionary = drop["item"]
        var gem: Dictionary = item["gem"]
        entries.append({"id":String(gem["id"]), "uid":int(gem["uid"]), "name":String(gem["name"]), "world_position":(drop["node"] as Node3D).global_position})
    return {"pool":GemSystem.drop_pool().size(), "world":entries, "stash":gem_inventory.size(), "picked":_picked_gem_uids.size()}
