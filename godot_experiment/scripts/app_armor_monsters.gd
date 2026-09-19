extends "res://scripts/app_poe_inventory.gd"

const ArmorSystem = preload("res://scripts/armor_equipment.gd")
const ArmorUIScript = preload("res://scripts/armor_equipment_ui.gd")
const TARGET_ENEMY_COUNT := 19

var equipped_armor: Dictionary = {}
var armor_inventory: Array[Dictionary] = []
var armor_ui: RiftArmorEquipmentUI
var _editing_slot := "weapon"
var _armor_ready := false
var _casting_equipment: Dictionary = {}

func _ready() -> void:
    super._ready()
    if ui == null or player == null:
        return
    for slot in ArmorSystem.SLOTS:
        equipped_armor[slot] = ArmorSystem.starter(slot)
    # One spare item makes replacement and retaining socketed gems testable.
    armor_inventory.append(ArmorSystem.normalize({"id":"field_hood", "slot":"頭部", "name":"斥候頭盔", "rarity":"魔法", "level":2, "armor":12.0, "prefix":{}, "suffix":{}}))
    armor_ui = ArmorUIScript.new() as RiftArmorEquipmentUI
    armor_ui.name = "ArmorEquipment"
    add_child(armor_ui)
    armor_ui.setup(ui_font)
    armor_ui.edit_requested.connect(_open_equipment_sockets)
    armor_ui.equip_requested.connect(_equip_armor)
    var inventory_ui := ui as RiftPoEInventoryUI
    if inventory_ui != null:
        if inventory_ui.socket_edit_requested.is_connected(_open_gem_ui):
            inventory_ui.socket_edit_requested.disconnect(_open_gem_ui)
        inventory_ui.socket_edit_requested.connect(_open_armor_ui)
    _armor_ready = true
    _recompute_armor_stats()
    while enemies.size() < TARGET_ENEMY_COUNT:
        var spawn_slot := enemies.size()
        _spawn_enemy(false, spawn_slot)
    _gem_message = "武器和頭／身／腿／鞋的孔洞皆可放寶石。裝備 → 裝備孔洞可管理四個部位。"
    _refresh_gameplay_ui()

func _open_armor_ui() -> void:
    if armor_ui == null:
        return
    if gem_ui != null and gem_ui.is_open():
        gem_ui.close()
    var inventory_ui := ui as RiftPoEInventoryUI
    if inventory_ui != null and inventory_ui.equipment_panel != null:
        inventory_ui.equipment_panel.visible = false
    armor_ui.set_data(equipped_armor, armor_inventory)
    armor_ui.open()

func _open_gem_ui() -> void:
    _editing_slot = "weapon"
    if armor_ui != null and armor_ui.is_open():
        armor_ui.close()
    super._open_gem_ui()

func _open_equipment_sockets(slot: String) -> void:
    if not equipped_armor.has(slot):
        return
    _editing_slot = slot
    if armor_ui != null and armor_ui.is_open():
        armor_ui.close()
    _gem_message = "正在編輯%s：點背包寶石再點同色孔；開孔與連線只影響這件裝備。" % slot
    # Bypass the weapon-only launcher: keep the selected wearable as the target.
    super._open_gem_ui()
    _refresh_gem_ui()

func _get_weapon() -> Dictionary:
    if _editing_slot != "weapon" and equipped_armor.has(_editing_slot):
        var gear := ArmorSystem.normalize(equipped_armor[_editing_slot])
        gear["damage"] = float(equipped_weapon.get("damage", 0.0))
        return gear
    return super._get_weapon()

func _save_weapon(item: Dictionary) -> void:
    if _editing_slot == "weapon" or not equipped_armor.has(_editing_slot):
        super._save_weapon(item)
        _validate_gem_toggles()
        return
    var saved := ArmorSystem.normalize(item)
    saved.erase("damage")
    equipped_armor[_editing_slot] = saved
    _validate_gem_toggles()
    _refresh_gameplay_ui()

func _use_currency(kind: String) -> void:
    if kind == "jeweller" and _editing_slot != "weapon":
        var armor: Dictionary = equipped_armor.get(_editing_slot, {})
        if (armor.get("sockets", []) as Array).size() >= int(armor.get("max_sockets", 4)):
            _gem_message = "%s最多只能開 %d 孔，沒有消耗開孔石。" % [_editing_slot, int(armor.get("max_sockets", 4))]
            _refresh_gem_ui()
            return
    super._use_currency(kind)

func _refresh_gem_ui() -> void:
    if gem_ui == null:
        return
    gem_ui.set_data(_get_weapon(), gem_inventory, gem_currency, _selected_gem, _aura_enabled, _gem_message)
    if armor_ui != null:
        armor_ui.set_data(equipped_armor, armor_inventory)

func _equip_armor(index: int) -> void:
    if index < 0 or index >= armor_inventory.size():
        return
    var next := ArmorSystem.normalize(armor_inventory[index])
    var slot := String(next.get("slot", ""))
    if not equipped_armor.has(slot):
        return
    var previous: Dictionary = equipped_armor[slot]
    armor_inventory.remove_at(index)
    armor_inventory.append(previous.duplicate(true))
    equipped_armor[slot] = next.duplicate(true)
    _recompute_armor_stats()
    _validate_gem_toggles()
    _refresh_gameplay_ui()
    ui.set_hint("已裝備 %s：%s；此部位孔洞與已插寶石一併保留。" % [slot, String(next.get("name", "護具"))])

func _recompute_armor_stats() -> void:
    var old_max := player_max_hp
    player_max_hp = 100.0 + ArmorSystem.health_bonus(equipped_armor)
    player_hp = clampf(player_hp + player_max_hp - old_max, 1.0, player_max_hp)
    _refresh_resource_hud()

func _pickup_item(item: Dictionary) -> void:
    var slot := ArmorSystem.canonical_slot(String(item.get("slot", "")))
    if not slot.is_empty():
        var armor := ArmorSystem.normalize(item)
        if armor.is_empty():
            return
        picked_loot += 1
        armor_inventory.append(armor)
        ui.set_hint("撿到 %s｜%d 孔。裝備 → 管理裝備可替換。" % [String(armor.get("name", "護具")), (armor.get("sockets", []) as Array).size()])
        if armor_ui != null:
            armor_ui.set_data(equipped_armor, armor_inventory)
        return
    super._pickup_item(item)

func _has_installed_gem(id: String) -> bool:
    if super._has_installed_gem(id):
        return true
    for slot in ArmorSystem.SLOTS:
        var gear: Dictionary = equipped_armor.get(slot, {})
        for entry in gear.get("sockets", []):
            var gem: Dictionary = (entry as Dictionary).get("gem", {})
            if String(gem.get("id", "")) == id:
                return true
    return false

func _has_any_aura() -> bool:
    if GemSystem.has_aura(equipped_weapon):
        return true
    for slot in ArmorSystem.SLOTS:
        if GemSystem.has_aura(equipped_armor.get(slot, {})):
            return true
    return false

func _validate_gem_toggles() -> void:
    if not _has_any_aura():
        _aura_enabled = false
    if not _has_installed_gem("rift_trail"):
        _trail_enabled = false

func _toggle_aura() -> void:
    if not _has_any_aura():
        _aura_enabled = false
        _gem_message = "先在武器或護具同色孔安裝疾行光環。"
    else:
        _aura_enabled = not _aura_enabled
        _gem_message = "疾行光環已%s：移速 +20%%，傷害 -15%%。" % ("啟動" if _aura_enabled else "關閉")
    _refresh_gem_ui()

func _hotbar_entries() -> Array[Dictionary]:
    var entries: Array[Dictionary] = []
    var all_gear: Array[Dictionary] = [equipped_weapon]
    for slot in ArmorSystem.SLOTS:
        if equipped_armor.has(slot):
            all_gear.append(equipped_armor[slot])
    for gear in all_gear:
        var sockets: Array = gear.get("sockets", [])
        for index in range(sockets.size()):
            var gem: Dictionary = (sockets[index] as Dictionary).get("gem", {})
            var info: Dictionary = GemSystem.data(gem)
            if String(info.get("role", "")) in ["attack", "aura"]:
                entries.append({"socket_index":index, "gem":gem.duplicate(true), "info":info, "equipment":gear.duplicate(true)})
                if entries.size() >= 5:
                    return entries
    return entries

func _use_skill(slot: int) -> void:
    var entries := _hotbar_entries()
    _casting_equipment = (entries[slot]["equipment"] as Dictionary).duplicate(true) if slot >= 0 and slot < entries.size() else {}
    _casting_equipment["damage"] = float(equipped_weapon.get("damage", 0.0))
    super._use_skill(slot)
    _casting_equipment = {}

func _skill_damage_for(id: String) -> float:
    var all_gear: Array[Dictionary] = [equipped_weapon]
    for slot in ArmorSystem.SLOTS:
        if equipped_armor.has(slot):
            all_gear.append(equipped_armor[slot])
    for item in all_gear:
        var sockets: Array = item.get("sockets", [])
        for index in range(sockets.size()):
            var gem: Dictionary = (sockets[index] as Dictionary).get("gem", {})
            if String(gem.get("id", "")) == id:
                var gear := item.duplicate(true)
                gear["damage"] = float(equipped_weapon.get("damage", 0.0))
                return GemSystem.skill_damage(gear, index) * (0.85 if _aura_enabled else 1.0)
    return 0.0

func _cast_socket_burst(index: int) -> void:
    var damage := GemSystem.skill_damage(_casting_equipment, index) * (0.85 if _aura_enabled else 1.0)
    var targets := _enemy_ids_in_range(4.2, 99)
    _spawn_hit_flash(player.global_position + Vector3(0, 0.7, 0), Color(1.0, 0.27, 0.10), 5.2)
    for target_id in targets:
        var enemy_index := _enemy_index_by_id(target_id)
        if enemy_index >= 0:
            _damage_enemy(enemy_index, damage)
    ui.set_hint("緋紅爆裂：範圍傷害 %.1f" % damage)

func _cast_socket_bolts(index: int) -> void:
    var damage := GemSystem.skill_damage(_casting_equipment, index) * (0.85 if _aura_enabled else 1.0)
    var supports := GemSystem.support_ids(_casting_equipment, index)
    var count := 3 if supports.has("multishot") else 1
    var chains := 2 if supports.has("chain") else 0
    var targets := _enemy_ids_in_range(_weapon_range(), count)
    var fired := 0
    for target_id in targets:
        var enemy_index := _enemy_index_by_id(target_id)
        if enemy_index >= 0:
            _fire_gem_bolt(target_id, enemies[enemy_index]["node"] as CharacterBody3D, damage, chains, [target_id], player.global_position + Vector3(0, 1.02, 0))
            fired += 1
    for extra in range(fired, count):
        var angle := (float(extra) - float(count - 1) * 0.5) * 0.22
        var direction := last_aim_direction.rotated(Vector3.UP, angle)
        _spawn_miss_projectile(player.global_position + direction * _weapon_range() + Vector3(0, 1.0, 0))
    ui.set_hint("緋紅火球：單發 %.1f｜%d 顆｜連鎖 %d" % [damage, count, chains])

func _physics_process(delta: float) -> void:
    if armor_ui != null and armor_ui.is_open():
        if player != null:
            player.velocity = Vector3.ZERO
        return
    super._physics_process(delta)
    if _aura_enabled and not GemSystem.has_aura(equipped_weapon) and _has_any_aura() and player != null and region_map != null and player.velocity.length_squared() > 0.01:
        var regular_velocity := player.velocity
        player.velocity = regular_velocity * 0.20
        player.move_and_slide()
        player.position = region_map.clamp_player(player.position)
        region_map.update_streaming(player.position)
        player.velocity = regular_velocity

func _unhandled_input(event: InputEvent) -> void:
    if armor_ui != null and armor_ui.is_open():
        if event is InputEventKey:
            var key := event as InputEventKey
            if key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
                armor_ui.close()
        get_viewport().set_input_as_handled()
        return
    super._unhandled_input(event)

func _damage_player(amount: float) -> void:
    # Reduces incoming damage without changing monster attack or death logic.
    var armor := ArmorSystem.defense(equipped_armor)
    super._damage_player(amount * 100.0 / (100.0 + armor))

func _spawn_enemy(force_elite: bool = false, slot: int = -1) -> void:
    super._spawn_enemy(force_elite, slot)
    if enemies.is_empty():
        return
    var entry: Dictionary = enemies.back()
    var monster := entry.get("node") as CharacterBody3D
    var archetype: Dictionary = entry.get("archetype", {})
    if monster == null:
        return
    var id := String(archetype.get("id", ""))
    var accent: Color = archetype.get("color", Color.WHITE)
    # Lightweight, distinct 3D silhouettes rather than recolours of one sprite.
    match id:
        "bone_runner":
            _monster_part(monster, Vector3(-0.38, 1.70, 0), Vector3(0.16, 0.75, 0.24), accent)
            _monster_part(monster, Vector3(0.38, 1.70, 0), Vector3(0.16, 0.75, 0.24), accent)
        "rift_bulwark":
            _monster_part(monster, Vector3(-0.74, 1.0, 0), Vector3(0.50, 1.24, 0.30), accent)
            _monster_part(monster, Vector3(0.74, 1.0, 0), Vector3(0.50, 1.24, 0.30), accent)
        "crystal_archer":
            _monster_part(monster, Vector3(0, 1.98, 0), Vector3(0.24, 0.74, 0.25), accent)
            _monster_part(monster, Vector3(0.62, 1.08, 0), Vector3(0.32, 0.12, 0.54), accent)
        "swamp_sapper":
            _monster_part(monster, Vector3(-0.48, 0.58, 0), Vector3(0.52, 0.28, 0.44), accent)
            _monster_part(monster, Vector3(0.48, 0.58, 0), Vector3(0.52, 0.28, 0.44), accent)
        "rift_oracle":
            _monster_part(monster, Vector3(-0.48, 2.05, 0), Vector3(0.12, 0.58, 0.18), accent)
            _monster_part(monster, Vector3(0.48, 2.05, 0), Vector3(0.12, 0.58, 0.18), accent)
            _monster_part(monster, Vector3(0, 2.36, 0), Vector3(0.72, 0.12, 0.20), accent)
        "rift_warden":
            _monster_part(monster, Vector3(-0.56, 1.27, 0), Vector3(0.31, 0.83, 0.20), accent)
        "rift_hexer":
            _monster_part(monster, Vector3(0, 2.06, 0), Vector3(0.65, 0.18, 0.22), accent)
        "rift_champion":
            _monster_part(monster, Vector3(-0.57, 1.95, 0), Vector3(0.29, 0.67, 0.28), accent)
            _monster_part(monster, Vector3(0.57, 1.95, 0), Vector3(0.29, 0.67, 0.28), accent)

func _monster_part(monster: Node3D, position: Vector3, dimensions: Vector3, color: Color) -> void:
    var part := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = dimensions
    part.mesh = mesh
    part.position = position
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    part.material_override = material
    monster.add_child(part)

func _enemy_cast_projectile(enemy: CharacterBody3D, damage: float) -> void:
    super._enemy_cast_projectile(enemy, damage)
    for entry in enemies:
        if entry.get("node") == enemy:
            var archetype: Dictionary = entry.get("archetype", {})
            if int(archetype.get("volley", 1)) > 1:
                get_tree().create_timer(0.17).timeout.connect(_volley_followup.bind(enemy, damage * 0.65), CONNECT_ONE_SHOT)
            break

func _volley_followup(enemy: CharacterBody3D, damage: float) -> void:
    if is_instance_valid(enemy) and is_instance_valid(player):
        super._enemy_cast_projectile(enemy, damage)

func debug_armor_state() -> Dictionary:
    var counts := {}
    var names := {}
    for slot in ArmorSystem.SLOTS:
        var item: Dictionary = equipped_armor.get(slot, {})
        counts[slot] = (item.get("sockets", []) as Array).size()
        names[slot] = String(item.get("name", ""))
    return {"slots":counts, "names":names, "bag":armor_inventory.size(), "defense":ArmorSystem.defense(equipped_armor), "panel_ready":armor_ui != null and armor_ui.root != null, "panel_open":armor_ui != null and armor_ui.is_open(), "editing":_editing_slot, "monster_count":enemies.size(), "monster_types":debug_archetypes()}
