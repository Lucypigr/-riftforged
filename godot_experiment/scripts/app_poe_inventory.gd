extends "res://scripts/app_linked_gems.gd"

const PoEInventoryUIScript = preload("res://scripts/poe_inventory_ui.gd")
const SKILL_KEYS := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5]

# A socketed active gem earns a shortcut in socket order. Supports are modifiers,
# never free actions. Cooldowns follow the gem UID when the player changes gear.
var _gem_cooldowns: Dictionary = {}
var _last_hotbar_uids: Array[int] = []

func _build_ui() -> void:
    ui = PoEInventoryUIScript.new()
    ui.name = "MobileUI"
    add_child(ui)
    ui.setup(ui_font)
    ui.movement_changed.connect(func(value: Vector2): move_input = value)
    ui.attack_requested.connect(_attack)
    var gameplay_ui := ui as RiftPoEInventoryUI
    gameplay_ui.skill_requested.connect(_use_skill)
    gameplay_ui.weapon_equip_requested.connect(_equip_weapon_index)
    gameplay_ui.fullscreen_requested.connect(_toggle_fullscreen)
    gameplay_ui.set_desktop_mode(desktop_layout_enabled)
    ui.set_hp(player_hp, player_max_hp)
    _apply_runtime_hint()

func _ready() -> void:
    super._ready()
    if ui == null or weapon_inventory.is_empty():
        return
    skill_cooldowns.resize(5)
    # This mobility skill is NOT granted automatically. The player must open a
    # blue socket and insert this gem before any of the five keys can dash.
    gem_inventory.append(_make_gem("rift_dash"))
    var inventory_ui := ui as RiftPoEInventoryUI
    if inventory_ui != null:
        inventory_ui.socket_edit_requested.connect(_open_gem_ui)
    _gem_message = "主動寶石依武器孔洞順序填入 1–5；輔助寶石只強化連線技能。左鍵永遠是普攻。"
    _refresh_gameplay_ui()

func _apply_runtime_hint() -> void:
    if ui == null:
        return
    if desktop_layout_enabled:
        ui.set_hint("WASD 移動｜左鍵普攻｜1–5 已插主動寶石｜Q/E 藥水｜M 地圖")
    else:
        ui.set_hint("搖桿移動｜攻擊為普攻｜1–5 技能只由已插主動寶石產生｜裝備管理孔洞")

func _hotbar_entries() -> Array[Dictionary]:
    var entries: Array[Dictionary] = []
    var sockets: Array = equipped_weapon.get("sockets", [])
    for index in range(sockets.size()):
        var gem: Dictionary = (sockets[index] as Dictionary).get("gem", {})
        var info: Dictionary = GemSystem.data(gem)
        var role := String(info.get("role", ""))
        if role == "attack" or role == "aura":
            entries.append({"socket_index":index, "gem":gem.duplicate(true), "info":info})
            if entries.size() == 5:
                break
    return entries

func _refresh_gameplay_ui() -> void:
    for i in range(mini(_last_hotbar_uids.size(), skill_cooldowns.size())):
        if _last_hotbar_uids[i] > 0:
            _gem_cooldowns[_last_hotbar_uids[i]] = skill_cooldowns[i]
    super._refresh_gameplay_ui()
    var gameplay_ui := ui as RiftPoEInventoryUI
    if gameplay_ui == null:
        return
    var entries := _hotbar_entries()
    _last_hotbar_uids.clear()
    for i in range(skill_cooldowns.size()):
        var uid := int((entries[i]["gem"] as Dictionary).get("uid", 0)) if i < entries.size() else 0
        _last_hotbar_uids.append(uid)
        skill_cooldowns[i] = float(_gem_cooldowns.get(uid, 0.0)) if uid > 0 else 0.0
    gameplay_ui.set_equipped_weapon_index(_equipped_weapon_index)
    gameplay_ui.set_weapon_inventory(weapon_inventory, String(equipped_weapon.get("name", "")))
    gameplay_ui.set_hotbar_gems(entries)
    gameplay_ui.set_skill_cooldowns(skill_cooldowns)

func _physics_process(delta: float) -> void:
    var gameplay_ui := ui as RiftPoEInventoryUI
    if gameplay_ui != null and gameplay_ui.equipment_panel != null and gameplay_ui.equipment_panel.visible:
        if player != null:
            player.velocity = Vector3.ZERO
        return
    super._physics_process(delta)
    for i in range(mini(_last_hotbar_uids.size(), skill_cooldowns.size())):
        if _last_hotbar_uids[i] > 0:
            _gem_cooldowns[_last_hotbar_uids[i]] = skill_cooldowns[i]

func _unhandled_input(event: InputEvent) -> void:
    if gem_ui != null and gem_ui.is_open():
        super._unhandled_input(event)
        return
    var gameplay_ui := ui as RiftPoEInventoryUI
    if gameplay_ui != null and gameplay_ui.equipment_panel != null and gameplay_ui.equipment_panel.visible:
        if event is InputEventKey:
            var blocked_key := event as InputEventKey
            if blocked_key.pressed and not blocked_key.echo and blocked_key.keycode == KEY_ESCAPE:
                gameplay_ui.equipment_panel.visible = false
        get_viewport().set_input_as_handled()
        return
    if event is InputEventKey:
        var key := event as InputEventKey
        if key.pressed and not key.echo:
            var slot := SKILL_KEYS.find(key.keycode)
            if slot >= 0:
                _use_skill(slot)
                get_viewport().set_input_as_handled()
                return
            if key.keycode == KEY_Q or key.keycode == KEY_E:
                _use_flask(0 if key.keycode == KEY_Q else 1)
                get_viewport().set_input_as_handled()
                return
    # Mouse left button is intentionally still handled by the existing basic
    # attack code; no active skill is assigned to the mouse.
    super._unhandled_input(event)

func _use_skill(slot: int) -> void:
    var gameplay_ui := ui as RiftPoEInventoryUI
    if gem_ui != null and gem_ui.is_open():
        return
    if gameplay_ui != null and gameplay_ui.equipment_panel != null and gameplay_ui.equipment_panel.visible:
        return
    if _is_region_map_open() or slot < 0 or slot >= 5 or slot >= skill_cooldowns.size():
        return
    var entries := _hotbar_entries()
    if slot >= entries.size():
        ui.set_hint("%d 是空技能欄：先在武器孔洞安裝主動技能寶石。" % (slot + 1))
        return
    if skill_cooldowns[slot] > 0.05:
        return
    var entry: Dictionary = entries[slot]
    var gem: Dictionary = entry["gem"]
    var info: Dictionary = entry["info"]
    var id := String(gem.get("id", ""))
    var uid := int(gem.get("uid", 0))
    var mana_cost := float(info.get("mana", 12.0))
    if player_mana + 0.001 < mana_cost:
        ui.set_hint("魔力不足：%s 需要 %d" % [String(gem.get("name", "技能")), int(mana_cost)])
        return
    player_mana -= mana_cost
    var cooldown := float(info.get("cooldown", 1.0))
    skill_cooldowns[slot] = cooldown
    if uid > 0:
        _gem_cooldowns[uid] = cooldown
    match id:
        "swift_aura":
            _toggle_aura()
        "rift_trail":
            _trail_enabled = not _trail_enabled
            _trail_timer = 0.0
            ui.set_hint("裂隙足跡：%s" % ("開啟" if _trail_enabled else "關閉"))
        "rift_dash":
            _cast_socket_dash()
        "crimson_burst":
            _cast_socket_burst(int(entry["socket_index"]))
        "ember_bolt":
            _cast_socket_bolts(int(entry["socket_index"]))
    _refresh_resource_hud()
    _refresh_gameplay_ui()

func _cast_socket_dash() -> void:
    var direction := _movement_direction()
    if direction.length_squared() < 0.01:
        direction = last_aim_direction
    if direction.length_squared() < 0.01:
        direction = Vector3(1, 0, 0)
    direction = direction.normalized()
    var start := player.global_position
    var destination := start + direction * 4.6
    if region_map != null:
        destination = region_map.clamp_player(destination)
    _spawn_hit_flash(start + Vector3(0, 0.65, 0), Color(0.30, 0.62, 1.0), 3.2)
    player.global_position = destination
    if region_map != null:
        region_map.update_streaming(player.position)
    _spawn_hit_flash(destination + Vector3(0, 0.65, 0), Color(0.30, 0.62, 1.0), 3.2)
    ui.set_hint("湛藍裂隙衝刺：快速位移")

func _cast_socket_burst(socket_index: int) -> void:
    var damage := GemSystem.skill_damage(equipped_weapon, socket_index) * (0.85 if _aura_enabled else 1.0)
    var targets := _enemy_ids_in_range(4.2, 99)
    _spawn_hit_flash(player.global_position + Vector3(0, 0.7, 0), Color(1.0, 0.27, 0.10), 5.2)
    for target_id in targets:
        var index := _enemy_index_by_id(target_id)
        if index >= 0:
            _damage_enemy(index, damage)
    ui.set_hint("緋紅爆裂：範圍傷害 %.1f" % damage)

func _cast_socket_bolts(socket_index: int) -> void:
    var damage := GemSystem.skill_damage(equipped_weapon, socket_index) * (0.85 if _aura_enabled else 1.0)
    var supports := GemSystem.support_ids(equipped_weapon, socket_index)
    var count := 3 if supports.has("multishot") else 1
    var chains := 2 if supports.has("chain") else 0
    var targets := _enemy_ids_in_range(_weapon_range(), count)
    var fired := 0
    for target_id in targets:
        var index := _enemy_index_by_id(target_id)
        if index >= 0:
            _fire_gem_bolt(target_id, enemies[index]["node"] as CharacterBody3D, damage, chains, [target_id], player.global_position + Vector3(0, 1.02, 0))
            fired += 1
    for extra in range(fired, count):
        var angle := (float(extra) - float(count - 1) * 0.5) * 0.22
        var direction := last_aim_direction.rotated(Vector3.UP, angle)
        _spawn_miss_projectile(player.global_position + direction * _weapon_range() + Vector3(0, 1.0, 0))
    ui.set_hint("緋紅火球：單發 %.1f｜%d 顆｜連鎖 %d" % [damage, count, chains])

func debug_hotbar_state() -> Dictionary:
    var entries := _hotbar_entries()
    var ids: Array[String] = ["", "", "", "", ""]
    for i in range(entries.size()):
        ids[i] = String((entries[i]["gem"] as Dictionary).get("id", ""))
    var gameplay_ui := ui as RiftPoEInventoryUI
    return {"ids": ids, "active": entries.size(), "cooldowns": skill_cooldowns.duplicate(), "inventory": gameplay_ui.debug_inventory_ui() if gameplay_ui != null else {}, "basic_attack":"left_click", "flasks":["Q", "E"]}
