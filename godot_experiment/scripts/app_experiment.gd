extends "res://scripts/app_skill_aim.gd"

# Independent entry point. The inherited baseline is vendored inside this
# project; no resource crosses into godot_v2 or shares its user:// directory.
var gem_effects: Node
var expedition_deaths := 0
var _respawn_shield_until := 0
var _objective: Label

func _ready() -> void:
    super._ready()
    gem_effects = preload("res://scripts/gem_effect_runtime.gd").new()
    gem_effects.host = self
    gem_effects.name = "GemEffects"
    add_child(gem_effects)
    if ui == null:
        return
    _objective = Label.new()
    _objective.name = "ExpeditionObjective"
    _objective.text = "裂隙遠征 · 實驗版｜沿路向北，挑戰裂隙領主"
    _objective.add_theme_font_override("font", ui_font)
    _objective.add_theme_font_size_override("font_size", 15)
    _objective.add_theme_color_override("font_color", Color(0.95, 0.78, 0.43))
    _objective.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui.root_control.add_child(_objective)
    get_viewport().size_changed.connect(_layout_expedition, CONNECT_DEFERRED)
    _layout_expedition()
    _apply_runtime_hint()

func _layout_expedition() -> void:
    var size := get_viewport().get_visible_rect().size
    if _objective != null:
        _objective.position = Vector2(12, 112)
        _objective.size = Vector2(maxf(100.0, size.x - 24), 46)
        _objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    if _boss_bar != null:
        var width := minf(420.0, size.x - 32.0)
        _boss_bar.custom_minimum_size = Vector2(width, 22)
        _boss_bar.size = Vector2(width, 22)
        _boss_bar.position = Vector2((size.x - width) * 0.5, 170)
        var title := _boss_layer.get_node("BossName") as Label
        title.position = Vector2((size.x - width) * 0.5, 144)

func _apply_runtime_hint() -> void:
    if ui != null:
        ui.set_hint("WASD 移動 · 1–5 技能 · 左鍵普攻 · Q/E 藥水 · I 背包 · M 地圖｜觸控：按住瞄準，放開施放")

func _attack_at_screen(screen_position: Vector2) -> void:
    if camera == null or player == null or _inventory_open():
        return
    last_aim_direction = AimRules.valid_direction(_screen_to_ground(screen_position) - player.global_position, last_aim_direction)
    _attack()

func _attack() -> void:
    if player == null or _inventory_open() or attack_cooldown > 0.0:
        return
    # Desktop keyboard shortcut and mouse input use identical aim rules.
    if not _mobile_controls() and camera != null:
        last_aim_direction = AimRules.valid_direction(_screen_to_ground(get_viewport().get_mouse_position()) - player.global_position, last_aim_direction)
    attack_cooldown = _weapon_cooldown()
    var damage := _roll_weapon_damage(1.0)
    var reach := _weapon_range()
    var supports: Array[String] = []
    if String(equipped_weapon.get("weapon_type", "bow")) == "blade":
        _v3_hit_cone(player.global_position, last_aim_direction, reach, 0.3, damage, supports)
        _spawn_hit_flash(player.global_position + last_aim_direction * 1.3 + Vector3(0, 0.8, 0), Color(1.0, 0.82, 0.52), 2.2)
    else:
        _launch_projectiles(player.global_position, damage, 1, reach, supports, 0.0, false, Color(1.0, 0.84, 0.52), 0.0, "basic")

func _enemy_speed_multiplier(id: int) -> float:
    return 0.65 if Time.get_ticks_msec() < int(_colder_until.get(id, 0)) else 1.0

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
        _reset_v5_controls()
        if ui is RiftSkillAimHUD:
            (ui as RiftSkillAimHUD).cancel_aim()

func _damage_player(amount: float) -> void:
    if _inventory_open() or Time.get_ticks_msec() < _respawn_shield_until:
        return
    var reduced := amount * 100.0 / (100.0 + ArmorSystem.defense(equipped_armor))
    var lethal := reduced >= player_hp
    super._damage_player(amount)
    if lethal:
        expedition_deaths += 1
        if gem_effects != null:
            gem_effects.clear()
        _respawn_shield_until = Time.get_ticks_msec() + 2200
        _reset_v5_controls()
        (ui as RiftSkillAimHUD).cancel_aim()
        ui.set_hint("你已倒下並返回營地，獲得短暫保護；裝備與地面戰利品保留。")

func _update_region_boss() -> void:
    super._update_region_boss()
    if _objective != null and _boss_defeated:
        _objective.text = "遠征完成｜裂隙領主已擊敗 · 靠近拾取戰利品"

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_I:
        if armor_ui.is_open():
            armor_ui.close()
        else:
            _open_armor_ui()
        get_viewport().set_input_as_handled()
        return
    super._unhandled_input(event)

var _rolling_boss_reward := false

func _drop_loot(position: Vector3, entry: Dictionary, guaranteed: bool) -> void:
    _rolling_boss_reward = bool(entry.get("boss", false))
    super._drop_loot(position, entry, guaranteed)
    _rolling_boss_reward = false

func _spawn_loot_visual(position: Vector3, item: Dictionary) -> void:
    var reward := item.duplicate(true)
    if _rolling_boss_reward and (String(reward.get("slot", "")) == "武器" or not ArmorSystem.canonical_slot(String(reward.get("slot", ""))).is_empty()):
        reward["rarity"] = "稀有"
        reward["color"] = Color(1.0, 0.82, 0.28)
        reward["prefix"] = {"name":"領主的", "stat":"傷害" if String(reward["slot"]) == "武器" else "生命", "value":24}
        reward["suffix"] = {"name":"之守望", "stat":"護甲", "value":18}
        reward["name"] = "領主的" + String(reward.get("base_name", reward.get("name", "裝備"))) + "之守望"
    super._spawn_loot_visual(position, reward)

func _cast_v3_skill(id: String, gem: Dictionary, gear: Dictionary, socket_index: int) -> void:
    if bool(GemSystem.data(gem).get("expansion", false)):
        gem_effects.cast(gem, gear, socket_index)
        ui.set_hint("%s｜連線輔助 %d" % [String(gem.name), GemSystem.support_ids(gear, socket_index).size()])
        return
    super._cast_v3_skill(id, gem, gear, socket_index)
