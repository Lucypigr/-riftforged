extends "res://scripts/app_region.gd"

const GemSystem = preload("res://scripts/linked_gem_system.gd")
const GemUIScript = preload("res://scripts/linked_gem_ui.gd")
const GEM_IDS := ["ember_bolt", "multishot", "chain", "crimson_burst", "swift_aura", "rift_trail"]

var gem_inventory: Array[Dictionary] = []
var gem_currency := {"jeweller":0, "fusing":0, "chromatic":0, "refine":0}
var gem_ui: RiftLinkedGemUI
var _selected_gem := -1
var _equipped_weapon_index := 0
var _next_gem_uid := 0
var _gem_message := ""
var _aura_enabled := false
var _trail_enabled := false
var _trail_timer := 0.0

func _ready() -> void:
    super._ready()
    if ui == null or weapon_inventory.is_empty():
        return
    var starter := GemSystem.normalize_weapon_sockets(weapon_inventory[0], true)
    var sockets: Array = starter["sockets"]
    sockets[0]["gem"] = _make_gem("ember_bolt")
    sockets[1]["gem"] = _make_gem("multishot")
    starter["sockets"] = sockets
    weapon_inventory[0] = starter.duplicate(true)
    equipped_weapon = starter.duplicate(true)
    for id in ["chain", "crimson_burst", "swift_aura", "rift_trail"]:
        gem_inventory.append(_make_gem(id))
    gem_ui = GemUIScript.new() as RiftLinkedGemUI
    gem_ui.name = "LinkedGemInventory"
    add_child(gem_ui)
    gem_ui.setup(ui_font)
    gem_ui.gem_requested.connect(_select_gem)
    gem_ui.socket_requested.connect(_use_socket)
    gem_ui.currency_requested.connect(_use_currency)
    gem_ui.aura_requested.connect(_toggle_aura)
    ui.gem_button.pressed.connect(_open_gem_ui)
    var gameplay_ui := ui as RiftGameplayUI
    if gameplay_ui != null and gameplay_ui.equipment_panel != null:
        var content := gameplay_ui.equipment_panel.get_node_or_null("Content") as VBoxContainer
        if content != null:
            var edit_button := Button.new()
            edit_button.name = "EditSocketsButton"
            edit_button.text = "◆ 編輯此武器孔洞／連線寶石"
            edit_button.custom_minimum_size.y = 42
            edit_button.pressed.connect(_open_gem_ui)
            content.add_child(edit_button)
    _gem_message = "紅孔火球與綠孔多重投射已連線，點擊其他寶石可換裝。"
    _refresh_gameplay_ui()

func _make_gem(id: String) -> Dictionary:
    _next_gem_uid += 1
    return GemSystem.make_gem(id, _next_gem_uid)

func _open_gem_ui() -> void:
    if gem_ui == null:
        return
    if ui.gem_panel != null:
        ui.gem_panel.visible = false
    var gameplay_ui := ui as RiftGameplayUI
    if gameplay_ui != null and gameplay_ui.equipment_panel != null:
        gameplay_ui.equipment_panel.visible = false
    _selected_gem = -1
    _refresh_gem_ui()
    gem_ui.open()

func _unhandled_input(event: InputEvent) -> void:
    if gem_ui != null and gem_ui.is_open():
        if event is InputEventKey:
            var key := event as InputEventKey
            if key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
                gem_ui.close()
        get_viewport().set_input_as_handled()
        return
    super._unhandled_input(event)

func _physics_process(delta: float) -> void:
    if gem_ui != null and gem_ui.is_open():
        if player != null:
            player.velocity = Vector3.ZERO
        return
    super._physics_process(delta)
    if player == null or region_map == null or _is_region_map_open():
        return
    if _aura_enabled and GemSystem.has_aura(equipped_weapon) and player.velocity.length_squared() > 0.01:
        var regular_velocity := player.velocity
        player.velocity = regular_velocity * 0.20
        player.move_and_slide()
        player.position = region_map.clamp_player(player.position)
        region_map.update_streaming(player.position)
        player.velocity = regular_velocity
    if _trail_enabled and _has_installed_gem("rift_trail"):
        _trail_timer -= delta
        if _trail_timer <= 0.0 and player.velocity.length_squared() > 0.1:
            _trail_timer = 0.38
            var pos := player.global_position - player.velocity.normalized() * 0.8
            _spawn_hit_flash(pos + Vector3(0, 0.22, 0), Color(0.35, 0.61, 1.0), 2.8)
            _damage_area(pos, 1.45, _skill_damage_for("rift_trail"), -1)

func _has_installed_gem(id: String) -> bool:
    for entry in equipped_weapon.get("sockets", []):
        var gem: Dictionary = (entry as Dictionary).get("gem", {})
        if String(gem.get("id", "")) == id:
            return true
    return false

func _select_gem(index: int) -> void:
    if index < 0 or index >= gem_inventory.size():
        return
    _selected_gem = -1 if _selected_gem == index else index
    _gem_message = "點擊同色孔安裝；已裝入的寶石可點孔拔下。" if _selected_gem >= 0 else "已取消選取。"
    _refresh_gem_ui()

func _use_socket(index: int) -> void:
    var weapon := _get_weapon()
    var sockets: Array = weapon.get("sockets", [])
    if index < 0 or index >= sockets.size():
        return
    var socket: Dictionary = sockets[index]
    var existing: Dictionary = socket.get("gem", {})
    if _selected_gem >= 0 and _selected_gem < gem_inventory.size():
        var incoming: Dictionary = gem_inventory[_selected_gem]
        if String(incoming.get("color", "")) != String(socket.get("color", "")):
            _gem_message = "孔色不符合：%s只能放進相同顏色的孔。" % String(incoming.get("name", "寶石"))
            _refresh_gem_ui()
            return
        if not existing.is_empty():
            gem_inventory.append(existing.duplicate(true))
        socket["gem"] = incoming.duplicate(true)
        gem_inventory.remove_at(_selected_gem)
        _selected_gem = -1
        _gem_message = "已安裝 %s；只有連線且標籤相容的支援效果會生效。" % String(incoming["name"])
    elif not existing.is_empty():
        gem_inventory.append(existing.duplicate(true))
        socket["gem"] = {}
        _gem_message = "已拔下 %s，返回寶石背包。" % String(existing["name"])
    else:
        _gem_message = "先點選背包中的同色寶石，再點此空孔。"
    sockets[index] = socket
    weapon["sockets"] = sockets
    _save_weapon(weapon)

func _use_currency(kind: String) -> void:
    if int(gem_currency.get(kind, 0)) <= 0:
        return
    var weapon := _get_weapon()
    var changed := false
    match kind:
        "jeweller":
            changed = GemSystem.add_socket(weapon)
            _gem_message = "新增了一個真實孔洞。" if changed else "武器已達六孔上限。"
        "fusing":
            changed = GemSystem.reroll_links(weapon)
            _gem_message = "連線已重鑄，只有同一連線群組的相容支援才生效。" if changed else "需要至少兩個孔才能重鑄連線。"
        "chromatic":
            if (weapon.get("sockets", []) as Array).is_empty():
                _gem_message = "尚無孔洞，沒有消耗幻色石。"
                _refresh_gem_ui()
                return
            var removed := GemSystem.recolor(weapon)
            for gem in removed:
                gem_inventory.append(gem)
            changed = true
            _selected_gem = -1
            _gem_message = "孔色已重鑄；不符合新孔色的寶石已安全退回背包。"
        "refine":
            if _selected_gem >= 0 and _selected_gem < gem_inventory.size():
                var gem := gem_inventory[_selected_gem]
                gem["refine"] = int(gem.get("refine", 0)) + 1
                gem_inventory[_selected_gem] = gem
                changed = true
                _gem_message = "%s 已精煉 +%d，傷害型寶石每級增加 5%% 基礎倍率。" % [String(gem["name"]), int(gem["refine"])]
            else:
                _gem_message = "先拔下並選取背包中的寶石，才能精煉。"
    if changed:
        gem_currency[kind] = int(gem_currency[kind]) - 1
    _save_weapon(weapon)

func _toggle_aura() -> void:
    if not GemSystem.has_aura(equipped_weapon):
        _aura_enabled = false
        _gem_message = "先將光環寶石安裝進同色孔。"
    else:
        _aura_enabled = not _aura_enabled
        _gem_message = "疾行光環已%s：移速 +20%%，造成傷害 -15%%。" % ("啟動" if _aura_enabled else "關閉")
    _refresh_gem_ui()

func _get_weapon() -> Dictionary:
    if _equipped_weapon_index >= 0 and _equipped_weapon_index < weapon_inventory.size():
        return GemSystem.normalize_weapon_sockets(weapon_inventory[_equipped_weapon_index], _equipped_weapon_index == 0)
    return GemSystem.normalize_weapon_sockets(equipped_weapon, false)

func _save_weapon(weapon: Dictionary) -> void:
    if _equipped_weapon_index >= 0 and _equipped_weapon_index < weapon_inventory.size():
        weapon_inventory[_equipped_weapon_index] = weapon.duplicate(true)
    equipped_weapon = weapon.duplicate(true)
    if not GemSystem.has_aura(equipped_weapon):
        _aura_enabled = false
    if not _has_installed_gem("rift_trail"):
        _trail_enabled = false
    _refresh_gameplay_ui()

func _equip_weapon_index(index: int) -> void:
    if index < 0 or index >= weapon_inventory.size():
        return
    _equipped_weapon_index = index
    weapon_inventory[index] = GemSystem.normalize_weapon_sockets(weapon_inventory[index], index == 0)
    super._equip_weapon_index(index)
    _save_weapon(weapon_inventory[index])

func _pickup_item(item: Dictionary) -> void:
    var slot := String(item.get("slot", ""))
    if slot == "寶石":
        var gem: Dictionary = item.get("gem", {})
        if not gem.is_empty():
            picked_loot += 1
            gem_inventory.append(gem.duplicate(true))
            _gem_message = "撿到 %s：已放進寶石背包。" % String(gem["name"])
            ui.set_hint(_gem_message)
            _refresh_gem_ui()
        return
    if slot == "通貨":
        var kind := String(item.get("currency", ""))
        if gem_currency.has(kind):
            gem_currency[kind] = int(gem_currency[kind]) + 1
            picked_loot += 1
            ui.set_hint("撿到通貨：%s × %d" % [String(item["name"]), int(gem_currency[kind])])
            _refresh_gem_ui()
        return
    var next_index := weapon_inventory.size()
    var should_auto := slot == "武器" and float(equipped_weapon.get("score", 0.0)) * 1.12 < float(WeaponSkillSystem.normalize_weapon(item).get("score", 0.0))
    super._pickup_item(item)
    if slot == "武器" and weapon_inventory.size() > next_index:
        weapon_inventory[next_index] = GemSystem.normalize_weapon_sockets(weapon_inventory[next_index], false)
        if should_auto:
            _equipped_weapon_index = next_index
            equipped_weapon = weapon_inventory[next_index].duplicate(true)
        _refresh_gameplay_ui()

func _drop_loot(position: Vector3, entry: Dictionary, guaranteed: bool) -> void:
    var elite := bool(entry.get("elite", false))
    var boss := bool(entry.get("boss", false))
    if guaranteed or randf() < (0.80 if elite or boss else 0.03):
        super._drop_loot(position, entry, true)
    if randf() < (0.78 if boss else (0.38 if elite else 0.05)):
        var id: String = String(GEM_IDS[randi_range(0, GEM_IDS.size() - 1)])
        var gem := _make_gem(id)
        var drop := {"id":"gem_" + id, "slot":"寶石", "name":String(gem["name"]), "rarity":"寶石", "color":_gem_color(String(gem["color"])), "gem":gem}
        _spawn_loot_visual(position + Vector3(randf_range(-0.8, 0.8), 0.0, randf_range(-0.8, 0.8)), drop)
    if randf() < (0.75 if boss else (0.30 if elite else 0.07)):
        var kinds := ["jeweller", "fusing", "chromatic", "refine"]
        var kind: String = String(kinds[randi_range(0, kinds.size() - 1)])
        var names := {"jeweller":"開孔石", "fusing":"連結石", "chromatic":"幻色石", "refine":"精煉石"}
        var currency_drop := {"id":"currency_" + kind, "slot":"通貨", "name":String(names[kind]), "rarity":"通貨", "color":Color(0.92, 0.75, 0.37), "currency":kind}
        _spawn_loot_visual(position + Vector3(randf_range(-0.8, 0.8), 0.0, randf_range(-0.8, 0.8)), currency_drop)

func _gem_color(id: String) -> Color:
    match id:
        "red": return Color(1.0, 0.35, 0.28)
        "green": return Color(0.39, 0.95, 0.43)
        "blue": return Color(0.34, 0.69, 1.0)
    return Color.WHITE

func _use_skill(slot: int) -> void:
    if slot == 0 and GemSystem.active_socket(equipped_weapon) < 0:
        ui.set_hint("請先在裝備孔洞中安裝攻擊技能寶石。")
        return
    super._use_skill(slot)

func _roll_weapon_damage(multiplier: float) -> float:
    var damage := super._roll_weapon_damage(multiplier)
    return damage * (0.85 if _aura_enabled else 1.0)

func _skill_damage_for(id: String) -> float:
    var sockets: Array = equipped_weapon.get("sockets", [])
    for i in range(sockets.size()):
        var gem: Dictionary = sockets[i].get("gem", {})
        if String(gem.get("id", "")) == id:
            return GemSystem.skill_damage(equipped_weapon, i) * (0.85 if _aura_enabled else 1.0)
    return 0.0

func _use_weapon_skill() -> void:
    var socket_index := GemSystem.active_socket(equipped_weapon)
    if socket_index < 0:
        return
    var socket: Dictionary = equipped_weapon["sockets"][socket_index]
    var gem: Dictionary = socket["gem"]
    var info := GemSystem.data(gem)
    var id := String(gem["id"])
    var damage := _skill_damage_for(id)
    skill_cooldowns[0] = float(info.get("cooldown", 2.4))
    if id == "rift_trail":
        _trail_enabled = not _trail_enabled
        _trail_timer = 0.0
        ui.set_hint("裂隙足跡：%s" % ("已啟動，移動留下傷害痕跡" if _trail_enabled else "已關閉"))
        return
    if id == "crimson_burst":
        var targets := _enemy_ids_in_range(4.2, 99)
        _spawn_hit_flash(player.global_position + Vector3(0, 0.7, 0), Color(1.0, 0.27, 0.10), 5.2)
        for target_id in targets:
            var index := _enemy_index_by_id(target_id)
            if index >= 0:
                _damage_enemy(index, damage)
        ui.set_hint("緋紅爆裂：範圍傷害 %.1f" % damage)
        return
    var supports := GemSystem.support_ids(equipped_weapon, socket_index)
    var projectile_count := 3 if supports.has("multishot") else 1
    var chain_count := 2 if supports.has("chain") else 0
    var target_ids := _enemy_ids_in_range(_weapon_range(), projectile_count)
    var fired := 0
    for target_id in target_ids:
        var index := _enemy_index_by_id(target_id)
        if index >= 0:
            _fire_gem_bolt(target_id, enemies[index]["node"] as CharacterBody3D, damage, chain_count, [target_id], player.global_position + Vector3(0, 1.02, 0))
            fired += 1
    for extra in range(fired, projectile_count):
        var angle := (float(extra) - float(projectile_count - 1) * 0.5) * 0.22
        var direction := last_aim_direction.rotated(Vector3.UP, angle)
        _spawn_miss_projectile(player.global_position + direction * _weapon_range() + Vector3(0, 1.0, 0))
    ui.set_hint("%s｜單發 %.1f｜%d 投射物｜連鎖 %d" % [String(gem["name"]), damage, projectile_count, chain_count])

func _fire_gem_bolt(enemy_id: int, target: CharacterBody3D, damage: float, chain_left: int, visited: Array[int], origin: Vector3) -> void:
    if not is_instance_valid(target):
        return
    projectile_serial += 1
    var projectile: Node3D = null
    if _combat_pool != null:
        projectile = _combat_pool.acquire_projectile(false, "GemBolt_%d" % projectile_serial)
    if projectile == null:
        projectile = _create_orb("GemBolt_%d" % projectile_serial, Color(1.0, 0.38, 0.15), Color(1.0, 0.22, 0.05), 0.18, 0.29)
        projectiles_root.add_child(projectile)
    projectile.global_position = origin
    var destination := target.global_position + Vector3(0, 0.9, 0)
    var tween := create_tween()
    tween.tween_property(projectile, "global_position", destination, PROJECTILE_TRAVEL_TIME)
    tween.tween_callback(_resolve_gem_bolt.bind(enemy_id, projectile, damage, chain_left, visited))

func _resolve_gem_bolt(enemy_id: int, projectile: Node3D, damage: float, chain_left: int, visited: Array[int]) -> void:
    _release_or_free_projectile(projectile)
    var index := _enemy_index_by_id(enemy_id)
    if index < 0:
        return
    var enemy := enemies[index]["node"] as CharacterBody3D
    if not is_instance_valid(enemy):
        return
    var hit_pos := enemy.global_position
    _damage_enemy(index, damage)
    _damage_area(hit_pos, 1.6, damage * 0.38, enemy_id)
    if chain_left <= 0:
        return
    var best_id := -1
    var best_distance := 5.8
    for entry in enemies:
        var candidate_id := int(entry["id"])
        var candidate := entry["node"] as CharacterBody3D
        if visited.has(candidate_id) or not is_instance_valid(candidate):
            continue
        var distance := hit_pos.distance_to(candidate.global_position)
        if distance <= best_distance:
            best_distance = distance
            best_id = candidate_id
    if best_id >= 0:
        var next_index := _enemy_index_by_id(best_id)
        if next_index >= 0:
            var next_visited: Array[int] = visited.duplicate()
            next_visited.append(best_id)
            _fire_gem_bolt(best_id, enemies[next_index]["node"] as CharacterBody3D, damage * 0.85, chain_left - 1, next_visited, hit_pos + Vector3(0, 0.95, 0))

func _refresh_gameplay_ui() -> void:
    super._refresh_gameplay_ui()
    if gem_ui != null:
        var gameplay_ui := ui as RiftGameplayUI
        if gameplay_ui != null:
            var names: Array[String] = ["未插技能", "爆裂", "衝刺"]
            var index := GemSystem.active_socket(equipped_weapon)
            if index >= 0:
                names[0] = String((equipped_weapon["sockets"][index] as Dictionary)["gem"].get("name", "技能"))
            gameplay_ui.set_skill_names(names)
        _refresh_gem_ui()

func _refresh_gem_ui() -> void:
    if gem_ui != null:
        gem_ui.set_data(equipped_weapon, gem_inventory, gem_currency, _selected_gem, _aura_enabled, _gem_message)

func debug_gem_state() -> Dictionary:
    var index := GemSystem.active_socket(equipped_weapon)
    return {
        "sockets": equipped_weapon.get("sockets", []).duplicate(true),
        "links": equipped_weapon.get("links", []).duplicate(),
        "stash": gem_inventory.duplicate(true),
        "currency": gem_currency.duplicate(true),
        "active_index": index,
        "supports": GemSystem.support_ids(equipped_weapon, index),
        "damage": GemSystem.skill_damage(equipped_weapon, index),
        "aura_on": _aura_enabled,
        "ui_ready": gem_ui != null and gem_ui.root != null,
        "ui_open": gem_ui != null and gem_ui.is_open(),
    }
