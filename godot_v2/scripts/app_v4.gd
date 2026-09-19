extends "res://scripts/app_v3_gems.gd"

const V4HUD = preload("res://scripts/v4_hud.gd")
const MONSTER_TARGET := 36
const MONSTER_LIMIT := 44
const FLASK_MAX: Array[int] = [40, 40]
const FLASK_USE: Array[int] = [10, 10]
const FLASK_KILL_NORMAL := 2
const FLASK_KILL_ELITE := 5
const FLASK_KILL_BOSS := 12
const CAST_ACTION_SECONDS := 0.30
const ATTACK_ACTION_SECONDS := 0.30
const SUMMONER_LIMIT := 2
const BOSS_SUMMON_LIMIT := 4
const BOSS_POSITION_Z := -124.0

var _last_cast_frame := -1
var _next_cast_ms: Dictionary = {}
var _rewarded_deaths: Dictionary = {}
var _last_floor_scan_ms := 0
var _last_full_notice_ms := 0
var _floor_uid := 2000000
var charm_inventory: Array[Dictionary] = []
var _frost_slow_until := 0
var _boss_id := -1
var _boss_defeated := false
var _boss_phase := 1
var _boss_move := 0
var _boss_next_attack_ms := 0
var _boss_bar: ProgressBar
var _boss_layer: CanvasLayer
var _v4_ready := false

func _build_ui() -> void:
    ui = V4HUD.new()
    ui.name = "MobileUI"
    add_child(ui)
    ui.setup(ui_font)
    ui.movement_changed.connect(func(value: Vector2): move_input = value)
    ui.attack_requested.connect(_attack)
    var hud := ui as RiftV4HUD
    hud.skill_requested.connect(_use_skill)
    hud.weapon_equip_requested.connect(_equip_weapon_index)
    hud.fullscreen_requested.connect(_toggle_fullscreen)
    hud.set_desktop_mode(desktop_layout_enabled)
    ui.set_hp(player_hp, player_max_hp)
    _apply_runtime_hint()

func _ready() -> void:
    flask_charges = FLASK_MAX.duplicate()
    super._ready()
    if ui == null or player == null:
        return
    (ui as RiftV4HUD).set_flask_config(FLASK_MAX, FLASK_USE)
    while enemies.size() < MONSTER_TARGET:
        _spawn_enemy(false, enemies.size())
    _spawn_region_boss()
    _v4_ready = true
    _refresh_gameplay_ui()
    _refresh_resource_hud()

func _refresh_gameplay_ui() -> void:
    # Old V3 equipment code still owns skill identities, but V4 has no skill CD.
    for i in range(skill_cooldowns.size()):
        skill_cooldowns[i] = 0.0
    _gem_cooldowns.clear()
    super._refresh_gameplay_ui()
    for i in range(skill_cooldowns.size()):
        skill_cooldowns[i] = 0.0
    _gem_cooldowns.clear()
    var hud := ui as RiftV4HUD
    if hud != null:
        hud.set_skill_cooldowns(skill_cooldowns)

func _refresh_resource_hud() -> void:
    super._refresh_resource_hud()
    var hud := ui as RiftV4HUD
    if hud != null:
        hud.set_flask_charges(flask_charges)

func _action_seconds(gear: Dictionary, socket_index: int, info: Dictionary) -> float:
    var tags: Array = info.get("tags", [])
    var seconds := ATTACK_ACTION_SECONDS if tags.has("attack") else CAST_ACTION_SECONDS
    if tags.has("attack"):
        seconds = maxf(0.22, float(equipped_weapon.get("cooldown", 0.35)))
    if tags.has("movement"):
        seconds = 0.20
    var supports := GemSystem.support_ids(gear, socket_index)
    if tags.has("attack") and supports.has("faster_attacks_support"):
        seconds *= 0.80
    if tags.has("spell") and supports.has("faster_casting_support"):
        seconds *= 0.80
    return maxf(0.12, seconds)

func _use_skill(slot: int) -> void:
    if player == null or gem_ui != null and gem_ui.is_open() or armor_ui != null and armor_ui.is_open() or _is_region_map_open():
        return
    var hud := ui as RiftV4HUD
    if hud != null and hud.equipment_panel != null and hud.equipment_panel.visible:
        return
    var entries := _hotbar_entries()
    if slot < 0 or slot >= entries.size() or slot >= 5:
        return
    var entry: Dictionary = entries[slot]
    var gem: Dictionary = entry.get("gem", {})
    var info: Dictionary = GemSystem.data(gem)
    var id := String(gem.get("id", ""))
    if info.is_empty() or String(info.get("role", "")) not in ["attack", "aura"]:
        return
    if not bool(info.get("v3", false)) and id not in ["ember_bolt", "crimson_burst", "rift_dash", "rift_trail", "swift_aura"]:
        return
    var gear: Dictionary = (entry.get("equipment", equipped_weapon) as Dictionary).duplicate(true)
    gear["damage"] = float(equipped_weapon.get("damage", 0.0))
    var index := int(entry["socket_index"])
    var cost := GemSystem.skill_mana(gear, index)
    if player_mana + 0.001 < cost:
        ui.set_hint("魔力不足：%s 需要 %.0f" % [String(gem["name"]), cost])
        return
    var frame := int(Engine.get_process_frames())
    if frame == _last_cast_frame:
        return
    var uid := int(gem.get("uid", 0))
    var now := Time.get_ticks_msec()
    if now < int(_next_cast_ms.get(uid, 0)):
        return
    var destination := Vector3.ZERO
    if id == "rift_dash":
        var direction := _movement_direction()
        if direction.length_squared() < 0.01:
            direction = last_aim_direction
        if direction.length_squared() < 0.01:
            direction = Vector3(1, 0, 0)
        destination = player.global_position + direction.normalized() * 4.6
        if region_map != null:
            destination = region_map.clamp_player(destination)
        if destination.distance_to(player.global_position) < 0.16:
            ui.set_hint("前方無法位移，沒有消耗魔力")
            return
    _last_cast_frame = frame
    _next_cast_ms[uid] = now + int(_action_seconds(gear, index, info) * 1000.0)
    player_mana -= cost
    # The animation/action interval is measured in fractions of a second and
    # never starts any cooldown UI or a multi-second gem timer.
    match id:
        "swift_aura":
            _toggle_aura()
        "rift_trail":
            _trail_enabled = not _trail_enabled
            _trail_timer = 0.0
            ui.set_hint("裂隙足跡：%s" % ("開啟" if _trail_enabled else "關閉"))
        "rift_dash":
            _spawn_hit_flash(player.global_position + Vector3(0, 0.65, 0), Color(0.30, 0.62, 1.0), 3.2)
            player.global_position = destination
            if region_map != null:
                region_map.update_streaming(player.position)
            _spawn_hit_flash(destination + Vector3(0, 0.65, 0), Color(0.30, 0.62, 1.0), 3.2)
        "ember_bolt":
            _casting_equipment = gear
            _cast_socket_bolts(index)
            _casting_equipment = {}
        "crimson_burst":
            _casting_equipment = gear
            _cast_socket_burst(index)
            _casting_equipment = {}
        _:
            _cast_v3_skill(id, gem, gear, index)
    _refresh_resource_hud()
    _refresh_gameplay_ui()

func _use_flask(slot: int) -> void:
    if slot < 0 or slot >= FLASK_MAX.size() or flask_charges[slot] < FLASK_USE[slot]:
        if ui != null:
            ui.set_hint("藥水充能不足")
        return
    if slot == 0:
        if player_hp >= player_max_hp - 0.001:
            ui.set_hint("生命已滿，沒有消耗充能")
            return
        player_hp = minf(player_max_hp, player_hp + HEALTH_FLASK_HEAL)
        ui.set_hp(player_hp, player_max_hp)
    else:
        if player_mana >= player_max_mana - 0.001:
            ui.set_hint("魔力已滿，沒有消耗充能")
            return
        player_mana = minf(player_max_mana, player_mana + MANA_FLASK_RESTORE)
    flask_charges[slot] -= FLASK_USE[slot]
    ui.set_hint("%s：消耗 %d 充能" % ["生命藥水" if slot == 0 else "魔力藥水", FLASK_USE[slot]])
    _refresh_resource_hud()

func _grant_kill_charges(entry: Dictionary) -> void:
    var id := int(entry.get("id", -1))
    if id < 0 or _rewarded_deaths.has(id):
        return
    _rewarded_deaths[id] = true
    var amount := FLASK_KILL_BOSS if bool(entry.get("boss", false)) else (FLASK_KILL_ELITE if bool(entry.get("elite", false)) else FLASK_KILL_NORMAL)
    for i in range(flask_charges.size()):
        flask_charges[i] = mini(FLASK_MAX[i], flask_charges[i] + amount)
    _refresh_resource_hud()

func _kill_enemy(index: int) -> void:
    if index < 0 or index >= enemies.size():
        return
    var entry: Dictionary = enemies[index]
    var id := int(entry.get("id", -1))
    if _rewarded_deaths.has(id):
        return
    var boss := bool(entry.get("boss", false))
    var sapper := String((entry.get("archetype", {}) as Dictionary).get("id", "")) == "swamp_sapper"
    var center := (entry["node"] as CharacterBody3D).global_position
    if sapper:
        var stats: Dictionary = (entry["archetype"] as Dictionary).duplicate(true)
        stats["dying_burst"] = 0.0
        entry["archetype"] = stats
        enemies[index] = entry
    _grant_kill_charges(entry)
    if boss:
        _boss_defeated = true
        if _boss_bar != null:
            _boss_bar.visible = false
    super._kill_enemy(index)
    if sapper:
        _warning_blast(center, 2.8, 16.0, 0.65, -1)
    if boss:
        _remove_minions(id)
        ui.set_hint("裂隙領主已擊敗！靠近地上的獎勵即可拾取。")

func _drop_loot(position: Vector3, entry: Dictionary, guaranteed: bool) -> void:
    var special := bool(entry.get("boss", false))
    var adjusted := entry.duplicate(true)
    if special:
        var stats: Dictionary = (adjusted.get("archetype", {}) as Dictionary).duplicate(true)
        stats["level"] = int(stats.get("level", 1)) + 4
        adjusted["archetype"] = stats
    var before := loot_drops.size() + gem_ground.size()
    super._drop_loot(position, adjusted, guaranteed)
    if special:
        # Normal 80/78/75 percent rolls run first; guarantee one item ONLY if
        # all rolls fail. Elite item rolling uses the existing real affix pool.
        if loot_drops.size() + gem_ground.size() == before:
            var stats: Dictionary = adjusted.get("archetype", {})
            var rolled: Array[Dictionary] = LootSystem.roll_master(String(stats.get("loot_profile", "champion")), int(stats.get("level", 1)), true, true)
            for item in rolled:
                _spawn_loot_visual(position, item)

func _spawn_loot_visual(position: Vector3, item: Dictionary) -> void:
    # Bypass the 24-item eviction in the older performance subclass: ground
    # objects are player property until successfully collected, not a FIFO.
    if loot_root == null:
        return
    loot_serial += 1
    _floor_uid += 1
    var stored := item.duplicate(true)
    stored["floor_uid"] = _floor_uid
    if String(stored.get("slot", "")) == "武器" or not ArmorSystem.canonical_slot(String(stored.get("slot", ""))).is_empty():
        if int(stored.get("instance_uid", 0)) <= 0:
            stored["instance_uid"] = _floor_uid
    var safe := region_map.clamp_player(position) if region_map != null else position
    var drop := Node3D.new()
    drop.name = "Loot_%d" % loot_serial
    loot_root.add_child(drop)
    drop.global_position = safe
    var glow := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.top_radius = 0.26
    mesh.bottom_radius = 0.26
    mesh.height = 0.065
    glow.mesh = mesh
    glow.position.y = 0.10
    var mat := StandardMaterial3D.new()
    var tint: Color = stored.get("color", Color(0.94, 0.80, 0.55))
    mat.albedo_color = tint
    mat.emission_enabled = true
    mat.emission = tint
    mat.emission_energy_multiplier = 2.6
    glow.material_override = mat
    glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    drop.add_child(glow)
    var label := Label3D.new()
    label.name = "DropName"
    label.text = "%s [%s]" % [String(stored.get("name", "戰利品")), String(stored.get("rarity", ""))]
    label.position.y = 0.78
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.font = ui_font
    label.font_size = 27
    label.outline_size = 4
    label.modulate = tint
    drop.add_child(label)
    loot_drops.append({"node":drop, "item":stored, "uid":_floor_uid})

func _pickup_item(item: Dictionary) -> void:
    if String(item.get("slot", "")) == "護符":
        charm_inventory.append(item.duplicate(true))
        picked_loot += 1
        ui.set_hint("獲得護符：%s" % String(item.get("name", "護符")))
        return
    super._pickup_item(item)

func _update_loot() -> void:
    var now := Time.get_ticks_msec()
    if now - _last_floor_scan_ms < 80 or player == null:
        return
    _last_floor_scan_ms = now
    for i in range(loot_drops.size() - 1, -1, -1):
        var entry: Dictionary = loot_drops[i]
        var node := entry.get("node") as Node3D
        if not is_instance_valid(node):
            loot_drops.remove_at(i)
            continue
        if player.global_position.distance_to(node.global_position) > LOOT_PICKUP_RANGE:
            continue
        var item: Dictionary = entry.get("item", {})
        if not _can_store_equipment(item):
            if now - _last_full_notice_ms > 1900:
                ui.set_hint("背包已滿，戰利品留在地上")
                _last_full_notice_ms = now
            continue
        if String(item.get("slot", "")) == "通貨" and not gem_currency.has(String(item.get("currency", ""))):
            continue
        var previous := picked_loot
        _pickup_item(item)
        if picked_loot <= previous:
            continue
        loot_drops.remove_at(i)
        node.queue_free()

func _spawn_enemy(force_elite: bool = false, slot: int = -1) -> void:
    if enemies.size() >= MONSTER_LIMIT:
        return
    super._spawn_enemy(force_elite, slot)
    if enemies.is_empty():
        return
    var index := enemies.size() - 1
    var entry: Dictionary = enemies[index]
    var enemy := entry.get("node") as CharacterBody3D
    if not is_instance_valid(enemy):
        return
    var archetype: Dictionary = entry.get("archetype", {})
    # Existing five specialized archetypes remain; the frost caster completes
    # the sixth behavioral family without duplicating the existing archer.
    if not force_elite and posmod(slot, 10) == 8:
        archetype["id"] = "frost_wraith"
        archetype["name"] = "霜痕幽魂"
        archetype["behavior"] = "ranged"
        archetype["desired_range"] = 6.4
        archetype["skill_chance"] = 1.0
        archetype["skill_delay"] = 2.8
        archetype["skill_damage"] = 9.0 + float(archetype.get("level", 1))
        archetype["color"] = Color(0.32, 0.82, 1.0)
        var visual := entry.get("visual") as Sprite3D
        if visual != null:
            visual.modulate = archetype["color"]
        var label := entry.get("label") as Label3D
        if label != null:
            label.text = "%s Lv.%d %d" % [String(archetype["name"]), int(archetype["level"]), int(entry["hp"])]
        _monster_part(enemy, Vector3(0, 1.95, 0), Vector3(0.8, 0.14, 0.35), archetype["color"])
        entry["archetype"] = archetype
    if player != null and region_map != null:
        var candidate := enemy.global_position
        for offset in range(10):
            var collision := candidate.distance_to(player.global_position) < 5.0
            for other in enemies:
                if int(other.get("id", -1)) == int(entry["id"]):
                    continue
                var other_node := other.get("node") as CharacterBody3D
                if is_instance_valid(other_node) and candidate.distance_to(other_node.global_position) < 1.5:
                    collision = true
                    break
            if not collision:
                break
            candidate = region_map.enemy_spawn_position(maxi(0, slot + offset + 1), enemy_serial + offset, force_elite)
        enemy.global_position = region_map.clamp_player(candidate)
    enemies[index] = entry

func _enemy_cast_projectile(enemy: CharacterBody3D, damage: float) -> void:
    for entry in enemies:
        if entry.get("node") == enemy and String((entry.get("archetype", {}) as Dictionary).get("id", "")) == "frost_wraith":
            var orb := _create_orb("FrostBolt", Color(0.40, 0.86, 1.0), Color(0.25, 0.65, 1.0), 0.19, 0.32)
            projectiles_root.add_child(orb)
            orb.global_position = enemy.global_position + Vector3(0, 1.0, 0)
            var target := player.global_position + Vector3(0, 0.82, 0)
            var tween := create_tween()
            tween.tween_property(orb, "global_position", target, 0.76)
            tween.tween_callback(_resolve_frost_bolt.bind(orb, target, damage))
            return
    super._enemy_cast_projectile(enemy, damage)

func _resolve_frost_bolt(orb: Node3D, target: Vector3, damage: float) -> void:
    _release_or_free_projectile(orb)
    if player == null:
        return
    var flat := player.global_position
    flat.y = target.y
    if flat.distance_to(target) <= 1.25:
        _damage_player(damage)
        var now := Time.get_ticks_msec()
        if now >= _frost_slow_until:
            _frost_slow_until = now + 1600
        ui.set_hint("寒霜命中：移速短暫降低")

func _physics_process(delta: float) -> void:
    super._physics_process(delta)
    if player == null or not _v4_ready:
        return
    if Time.get_ticks_msec() < _frost_slow_until:
        player.global_position -= player.velocity * delta * 0.28
        if region_map != null:
            player.global_position = region_map.clamp_player(player.global_position)
    _update_special_enemies(delta)
    _update_region_boss()
    for i in range(skill_cooldowns.size()):
        skill_cooldowns[i] = 0.0

func _update_special_enemies(delta: float) -> void:
    for i in range(enemies.size() - 1, -1, -1):
        var entry: Dictionary = enemies[i]
        if bool(entry.get("boss", false)):
            continue
        if String((entry.get("archetype", {}) as Dictionary).get("id", "")) != "rift_oracle":
            continue
        var enemy := entry.get("node") as CharacterBody3D
        if not is_instance_valid(enemy) or enemy.global_position.distance_to(player.global_position) > 14.0:
            continue
        entry["summon_cd"] = maxf(0.0, float(entry.get("summon_cd", 4.0)) - delta)
        if float(entry["summon_cd"]) <= 0.0:
            entry["summon_cd"] = 7.5
            _summon_minions(int(entry["id"]), enemy.global_position, SUMMONER_LIMIT)
        enemies[i] = entry

func _summon_minions(owner_id: int, center: Vector3, owner_limit: int) -> void:
    var living := 0
    for entry in enemies:
        if int(entry.get("summoned_by", -1)) == owner_id:
            living += 1
    for n in range(mini(2, maxi(0, owner_limit - living))):
        if enemies.size() >= MONSTER_LIMIT:
            return
        var pos := center + Vector3(cos(float(n) * PI + 0.6) * 3.2, 0, sin(float(n) * PI + 0.6) * 3.2)
        if player.global_position.distance_to(pos) < 3.8:
            continue
        _spawn_enemy(false, 3 + n * 8)
        if enemies.is_empty():
            return
        var minion: Dictionary = enemies.back()
        minion["summoned_by"] = owner_id
        (minion["node"] as CharacterBody3D).global_position = region_map.clamp_player(pos) if region_map != null else pos
        enemies[enemies.size() - 1] = minion

func _remove_minions(owner_id: int) -> void:
    for i in range(enemies.size() - 1, -1, -1):
        if int(enemies[i].get("summoned_by", -1)) != owner_id:
            continue
        var node := enemies[i].get("node") as CharacterBody3D
        if is_instance_valid(node):
            node.queue_free()
        enemies.remove_at(i)

func _damage_enemy(index: int, damage: float) -> void:
    if index < 0 or index >= enemies.size():
        return
    var entry: Dictionary = enemies[index]
    var id := String((entry.get("archetype", {}) as Dictionary).get("id", ""))
    if id == "rift_bulwark":
        damage *= 0.70
    elif bool(entry.get("boss", false)):
        damage *= 0.82
    super._damage_enemy(index, damage)

func _spawn_region_boss() -> void:
    if _boss_id > 0 or _boss_defeated or region_map == null:
        return
    _spawn_enemy(true, 777)
    if enemies.is_empty():
        return
    var entry: Dictionary = enemies.back()
    var enemy := entry.get("node") as CharacterBody3D
    var stats: Dictionary = (entry["archetype"] as Dictionary).duplicate(true)
    stats["id"] = "rift_lord"
    stats["name"] = "裂隙領主"
    stats["hp"] = 1250.0
    stats["level"] = maxi(8, int(stats.get("level", 1)))
    stats["loot_profile"] = "champion"
    stats["behavior"] = "ranged"
    stats["desired_range"] = 3.5
    stats["skill_chance"] = 0.0
    stats["color"] = Color(0.88, 0.22, 0.46)
    stats["dying_burst"] = 0.0
    entry["archetype"] = stats
    entry["hp"] = 1250.0
    entry["max_hp"] = 1250.0
    entry["boss"] = true
    entry["elite"] = true
    enemy.global_position = region_map.clamp_player(Vector3(region_map.road_center_x(BOSS_POSITION_Z), 0, BOSS_POSITION_Z))
    var visual := entry.get("visual") as Sprite3D
    if visual != null:
        visual.modulate = stats["color"]
        visual.scale *= 1.55
    _monster_part(enemy, Vector3(-0.85, 1.75, 0), Vector3(0.38, 1.4, 0.28), stats["color"])
    _monster_part(enemy, Vector3(0.85, 1.75, 0), Vector3(0.38, 1.4, 0.28), stats["color"])
    (entry["label"] as Label3D).text = "裂隙領主 · 1250"
    enemies[enemies.size() - 1] = entry
    _boss_id = int(entry["id"])
    _boss_next_attack_ms = Time.get_ticks_msec() + 1200
    _boss_layer = CanvasLayer.new()
    _boss_layer.name = "RegionBossHUD"
    _boss_layer.layer = 8
    add_child(_boss_layer)
    _boss_bar = ProgressBar.new()
    _boss_bar.name = "BossHP"
    _boss_bar.min_value = 0.0
    _boss_bar.max_value = 1250.0
    _boss_bar.value = 1250.0
    _boss_bar.show_percentage = false
    _boss_bar.custom_minimum_size = Vector2(420, 29)
    _boss_bar.position = Vector2(420, 35)
    _boss_bar.visible = false
    _boss_layer.add_child(_boss_bar)
    var title := Label.new()
    title.name = "BossName"
    title.text = "裂隙領主"
    title.position = Vector2(420, 8)
    title.add_theme_font_size_override("font_size", 21)
    _boss_layer.add_child(title)
    title.visible = false

func _update_region_boss() -> void:
    if _boss_id < 0 or _boss_defeated or player == null:
        return
    var index := _enemy_index_by_id(_boss_id)
    if index < 0:
        return
    var entry: Dictionary = enemies[index]
    var boss := entry.get("node") as CharacterBody3D
    if not is_instance_valid(boss):
        return
    var distance := player.global_position.distance_to(boss.global_position)
    if _boss_bar != null:
        _boss_bar.value = float(entry["hp"])
        _boss_bar.visible = distance < 30.0
        (_boss_layer.get_node("BossName") as Label).visible = distance < 30.0
    if distance > 18.0:
        return
    if _boss_phase == 1 and float(entry["hp"]) <= float(entry["max_hp"]) * 0.55:
        _boss_phase = 2
        _summon_minions(_boss_id, boss.global_position, BOSS_SUMMON_LIMIT)
        ui.set_hint("裂隙領主進入第二階段：呼喚援軍！")
    var now := Time.get_ticks_msec()
    if now < _boss_next_attack_ms:
        return
    _boss_next_attack_ms = now + (1700 if _boss_phase == 2 else 2300)
    match _boss_move % 4:
        0:
            _warning_blast(boss.global_position, 3.2, 26.0, 0.75, _boss_id)
        1:
            _boss_barrage(boss.global_position)
        2:
            _warning_blast(boss.global_position, 6.0, 19.0, 0.90, _boss_id)
        3:
            if _boss_phase == 2:
                _summon_minions(_boss_id, boss.global_position, BOSS_SUMMON_LIMIT)
            else:
                _warning_blast(boss.global_position, 4.0, 16.0, 0.80, _boss_id)
    _boss_move += 1

func _warning_blast(center: Vector3, radius: float, damage: float, seconds: float, owner_id: int) -> void:
    var marker := MeshInstance3D.new()
    marker.name = "DangerTelegraph"
    var disc := CylinderMesh.new()
    disc.top_radius = radius
    disc.bottom_radius = radius
    disc.height = 0.03
    marker.mesh = disc
    marker.global_position = center + Vector3(0, 0.09, 0)
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(1.0, 0.13, 0.07, 0.38)
    mat.emission_enabled = true
    mat.emission = Color(1.0, 0.08, 0.06)
    mat.emission_energy_multiplier = 1.6
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    marker.material_override = mat
    marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    projectiles_root.add_child(marker)
    get_tree().create_timer(seconds).timeout.connect(_finish_warning.bind(marker, center, radius, damage, owner_id), CONNECT_ONE_SHOT)

func _finish_warning(marker: MeshInstance3D, center: Vector3, radius: float, damage: float, owner_id: int) -> void:
    if is_instance_valid(marker):
        marker.queue_free()
    if owner_id > 0 and _enemy_index_by_id(owner_id) < 0:
        return
    _spawn_hit_flash(center + Vector3(0, 0.6, 0), Color(1.0, 0.19, 0.06), radius)
    if player == null:
        return
    var offset := player.global_position - center
    offset.y = 0.0
    if offset.length() <= radius:
        _damage_player(damage)

func _boss_barrage(origin: Vector3) -> void:
    if player == null:
        return
    var aim := player.global_position
    for n in range(3):
        var destination := aim + Vector3(float(n - 1) * 1.9, 0.0, 0.0)
        var orb := _create_orb("BossRiftBolt", Color(1.0, 0.22, 0.54), Color(0.74, 0.11, 0.36), 0.24, 0.38)
        projectiles_root.add_child(orb)
        orb.global_position = origin + Vector3(0, 1.2, 0)
        var tween := create_tween()
        tween.tween_property(orb, "global_position", destination + Vector3(0, 0.9, 0), 0.78)
        tween.tween_callback(_finish_boss_bolt.bind(orb, destination))

func _finish_boss_bolt(orb: Node3D, destination: Vector3) -> void:
    _release_or_free_projectile(orb)
    if _boss_defeated or player == null:
        return
    var difference := player.global_position - destination
    difference.y = 0
    if difference.length() < 1.05:
        _damage_player(14.0 if _boss_phase == 1 else 19.0)

func debug_v4_state() -> Dictionary:
    return {"enemy_count":enemies.size(), "cap":MONSTER_LIMIT, "flask_charges":flask_charges.duplicate(), "flask_max":FLASK_MAX.duplicate(), "flask_cost":FLASK_USE.duplicate(), "boss_id":_boss_id, "boss_defeated":_boss_defeated, "boss_phase":_boss_phase, "boss_bar":_boss_bar != null, "floor":loot_drops.size(), "gems":gem_ground.size(), "charms":charm_inventory.size(), "slow":Time.get_ticks_msec() < _frost_slow_until, "cooldowns":skill_cooldowns.duplicate()}
