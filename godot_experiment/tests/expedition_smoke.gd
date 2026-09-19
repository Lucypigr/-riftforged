extends SceneTree

const Gems = preload("res://scripts/linked_gem_system.gd")
var game
var done := false
var checks := 0

func _init() -> void:
    call_deferred("_run")
    call_deferred("_watchdog")

func _watchdog() -> void:
    await create_timer(50).timeout
    if not done:
        push_error("EXPEDITION_FAIL watchdog")
        quit(1)

func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        push_error("EXPEDITION_FAIL " + message)
        quit(1)
        assert(ok, message)

func gear(ids: Array) -> Dictionary:
    var item: Dictionary = game.equipped_weapon.duplicate(true)
    item["sockets"] = []
    item["links"] = []
    for id in ids:
        var gem: Dictionary = game._make_gem(id)
        item["sockets"].append({"color":gem["color"], "gem":gem})
        if item["sockets"].size() > 1:
            item["links"].append(true)
    return item

func equip(item: Dictionary) -> void:
    game.equipped_weapon = item
    game.weapon_inventory[game._equipped_weapon_index] = item.duplicate(true)
    game.hotbar_assignments[0] = {"kind":"gem", "uid":int(item["sockets"][0]["gem"]["uid"])}
    game._last_cast_frame = -1
    game._next_cast_ms.clear()
    game.player_mana = game.player_max_mana
    game._refresh_gameplay_ui()

func _run() -> void:
    game = (load("res://main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    await process_frame
    await process_frame
    check(Gems.GEMS.size() == 27, "gem catalog lost IDs")
    for value in game.gem_currency.values():
        check(int(value) == 0, "currency minted at spawn")
    var spawn: Vector3 = game.player.position
    game.move_input = Vector2(1, 0)
    await create_timer(0.16).timeout
    check(game.player.position.distance_to(spawn) > 0.1, "movement did not move physical player")
    game.move_input = Vector2.ZERO
    game.set_physics_process(false)
    game._v5_force_mobile = true
    game.player.position = game.region_map.clamp_player(Vector3(0, 0, -60))
    for entry in game.enemies:
        (entry["node"] as Node3D).position = game.region_map.clamp_player(Vector3(18, 0, -135))
    var victim: Dictionary = game.enemies[0]
    var victim_id := int(victim["id"])
    var origin: Vector3 = game.player.position
    victim["node"].position = origin + Vector3(2, 0, 0)
    victim["hp"] = 10000.0
    victim["max_hp"] = 10000.0
    game.enemies[0] = victim
    var none: Array[String] = []
    game.last_aim_direction = Vector3.RIGHT
    game.attack_cooldown = 0
    var hp := float(game.enemies[0]["hp"])
    game._attack()
    await create_timer(0.48).timeout
    check(float(game.enemies[game._enemy_index_by_id(victim_id)]["hp"]) < hp, "manual basic projectile failed to damage")
    var shots_before: int = game._aim_shot_history.size()
    var pierce: Array[String] = ["pierce_support"]
    game._v3_projectiles(origin, 1, 1, 11.5, pierce, 0, false, Color.WHITE)
    check(game._aim_shot_history.size() == shots_before + 1, "pierce incorrectly adds projectile")
    var multi: Array[String] = ["multishot"]
    shots_before = game._aim_shot_history.size()
    game._v3_projectiles(origin, 1, 1, 11.5, multi, 0, false, Color.WHITE)
    check(game._aim_shot_history.size() == shots_before + 3, "multishot did not add projectiles")
    await create_timer(0.5).timeout
    game._colder_until[victim_id] = Time.get_ticks_msec() + 1000
    check(is_equal_approx(game._enemy_speed_multiplier(victim_id), 0.65), "chill has no movement effect")
    # Actual melee hit region, rather than only checking a radius helper.
    victim["node"].position = origin + Vector3(4.2, 0, 0)
    equip(gear(["cleave"]))
    hp = float(game.enemies[game._enemy_index_by_id(victim_id)]["hp"])
    game.last_aim_direction = Vector3.RIGHT
    game._use_skill(0)
    check(is_equal_approx(float(game.enemies[game._enemy_index_by_id(victim_id)]["hp"]), hp), "unmodified cleave reached too far")
    equip(gear(["cleave", "increased_area_support"]))
    game._use_skill(0)
    check(float(game.enemies[game._enemy_index_by_id(victim_id)]["hp"]) < hp, "area support did not expand actual melee hits")
    for pair in [["cleave", "faster_attacks_support"], ["ember_bolt", "faster_casting_support"]]:
        var plain := gear([pair[0]])
        var linked := gear(pair)
        check(game._action_seconds(linked, 0, Gems.data(linked["sockets"][0]["gem"])) < game._action_seconds(plain, 0, Gems.data(plain["sockets"][0]["gem"])), "speed support has no action effect")
    var inspired := gear(["ember_bolt", "inspiration_support"])
    check(Gems.skill_mana(inspired, 0) < Gems.skill_mana(gear(["ember_bolt"]), 0), "inspiration has no mana effect")
    # Exercise every damage active through the real hotbar/mana/cast dispatcher.
    for id in ["ember_bolt", "crimson_burst", "cleave", "ground_slam", "molten_strike", "burning_arrow", "split_arrow", "ice_shot", "galvanic_arrow", "freezing_pulse", "arc", "frost_nova"]:
        victim["node"].position = origin + Vector3(2, 0, 0)
        equip(gear([id]))
        game.last_aim_direction = Vector3.RIGHT
        hp = float(game.enemies[game._enemy_index_by_id(victim_id)]["hp"])
        var mana: float = game.player_mana
        game._use_skill(0)
        await create_timer(0.48).timeout
        check(float(game.enemies[game._enemy_index_by_id(victim_id)]["hp"]) < hp, id + " has no real damage")
        check(game.player_mana < mana, id + " did not spend mana")
    equip(gear(["ember_bolt"]))
    game.player_mana = 0
    shots_before = game._aim_shot_history.size()
    game._use_skill(0)
    check(game._aim_shot_history.size() == shots_before, "zero mana still casts")
    # OS cancellation of an in-progress real touch must not fire.
    var hud := game.ui as RiftSkillAimHUD
    hud._test_touch_mode = true
    hud.set_desktop_mode(false)
    hud._layout_mobile_portrait(Vector2(390, 844))
    game.player_mana = 100
    game._refresh_gameplay_ui()
    var press := InputEventScreenTouch.new()
    press.index = 12
    press.position = hud.skill_buttons[0].get_global_rect().get_center()
    press.pressed = true
    hud._input(press)
    check(hud._aim_touch == 12, "touch aim failed to start")
    var release := InputEventScreenTouch.new()
    release.index = 12
    release.position = press.position + Vector2(50, 0)
    release.canceled = true
    var releases: int = game._aim_releases
    hud._input(release)
    check(game._aim_releases == releases and game.player_mana == 100, "canceled OS touch cast/spent mana")
    # Real item floor -> pickup -> equipment -> gem installation.
    var item := gear(["ember_bolt", "inspiration_support", "faster_casting_support"])
    item["instance_uid"] = 990001
    item["sockets"][0]["gem"] = {}
    game._spawn_loot_visual(origin + Vector3(0, 0, 6), item)
    var bag_before: int = game.weapon_inventory.size()
    game._last_floor_scan_ms = -9999
    game._update_loot()
    check(game.weapon_inventory.size() == bag_before, "remote item pickup")
    var floor_item: Dictionary = game.loot_drops.back()
    game.player.position = floor_item["node"].position
    game._last_floor_scan_ms = -9999
    game._update_loot()
    check(game.weapon_inventory.size() == bag_before + 1, "floor pickup failed")
    game._equip_weapon_index(game.weapon_inventory.size() - 1)
    check(game.equipped_weapon["instance_uid"] == 990001, "equipment lost stable UID")
    game.gem_inventory.append(game._make_gem("ember_bolt"))
    game._select_gem(game.gem_inventory.size() - 1)
    game._use_socket(0)
    check(game.equipped_weapon["sockets"][0]["gem"]["id"] == "ember_bolt", "gem install failed")
    check(Gems.support_ids(game.equipped_weapon, 0).size() == 2, "linked support lost on equip")
    # Failed chromatic craft on closed sockets cannot consume earned currency.
    game._spawn_loot_visual(game.player.position, {"slot":"通貨", "currency":"chromatic", "name":"幻色石"})
    game._last_floor_scan_ms = -9999
    game._update_loot()
    var currency: int = game.gem_currency["chromatic"]
    game.equipped_weapon["sockets"] = []
    game.equipped_weapon["links"] = []
    game._save_weapon(game.equipped_weapon)
    game._use_currency("chromatic")
    check(game.gem_currency["chromatic"] == currency, "failed currency operation consumed resource")
    # Defeat the real 1250 HP boss with legal mana-paid casts and action intervals.
    var boss_id: int = game._boss_id
    var boss_index: int = game._enemy_index_by_id(boss_id)
    var boss: Node3D = game.enemies[boss_index]["node"]
    game.player.position = boss.position + Vector3(1.5, 0, 0)
    equip(gear(["frost_nova", "controlled_destruction_support", "increased_area_support"]))
    for n in range(40):
        if game._boss_defeated:
            break
        game.player_mana = game.player_max_mana # Test resource fixture; combat stays real.
        game._use_skill(0)
        await create_timer(0.32).timeout
    check(game._boss_defeated and game._enemy_index_by_id(boss_id) < 0, "boss not defeated by real casts")
    check(game.loot_drops.size() + game.gem_ground.size() > 0, "boss left no ground reward")
    var kills_before: int = game.kills
    game._spawn_region_boss()
    check(game._enemy_index_by_id(boss_id) < 0 and game.kills == kills_before, "boss respawned")
    check(not game._boss_layer.get_node("BossName").visible, "boss title survived victory")
    game._rolling_boss_reward = true
    game._spawn_loot_visual(game.player.position, item)
    game._rolling_boss_reward = false
    var reward: Dictionary = game.loot_drops.back()["item"]
    check(reward["rarity"] == "稀有" and int(reward["prefix"]["value"]) == 24, "boss quality only changed name")
    game.player_hp = 1
    game._damage_player(10000)
    check(game.expedition_deaths == 1 and game.player_hp > 0 and game.player.position.distance_to(game.region_map.spawn_position()) < 0.1, "death/recovery failed")
    done = true
    print("RIFTFORGED_EXPEDITION_OK checks=", checks, " movement/manual-combat/all-damage-actives/support-effects/cancel/loot/equip/socket/boss/death")
    quit(0)
