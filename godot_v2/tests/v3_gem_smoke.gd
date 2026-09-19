extends SceneTree

const Gems = preload("res://scripts/linked_gem_system.gd")
const ACTIVE := ["cleave", "ground_slam", "molten_strike", "burning_arrow", "split_arrow", "ice_shot", "galvanic_arrow", "freezing_pulse", "arc", "frost_nova"]
const SUPPORT := ["melee_physical_support", "added_fire_support", "inspiration_support", "pierce_support", "faster_attacks_support", "faster_projectiles_support", "hypothermia_support", "controlled_destruction_support", "increased_area_support", "faster_casting_support"]
var _done := false

func _init() -> void:
    call_deferred("_run")
    call_deferred("_watchdog")

func _watchdog() -> void:
    await create_timer(24.0).timeout
    if not _done:
        _fail("timeout")

func _fail(reason: String) -> void:
    if _done:
        return
    _done = true
    push_error("V3_GEM_FAIL: " + reason)
    quit(1)

func _check(condition: bool, reason: String) -> bool:
    if not condition:
        _fail(reason)
    return condition

func _run() -> void:
    var pool := Gems.drop_pool()
    if not _check(pool.size() == Gems.GEMS.size() and pool.size() == 27, "registered/drop pool must include all old seven and 20 new gems"):
        return
    for id in ACTIVE + SUPPORT:
        if not _check(pool.has(id) and not Gems.make_gem(id, 9001).is_empty(), "missing from registry or pool: " + id):
            return
    for id in pool:
        var item := Gems.make_gem(id, 16001)
        if not _check(String(item.get("id", "")) == id and int(item.get("uid", 0)) == 16001 and int(item.get("level", 0)) == 1 and int(item.get("refine", -1)) == 0 and ["red", "green", "blue"].has(String(item.get("color", ""))), "malformed gem instance: " + id):
            return
    var rng := RandomNumberGenerator.new()
    rng.seed = 4042026
    var observed := {}
    for i in range(8000):
        observed[Gems.roll_drop_id(rng)] = true
    for id in pool:
        if not _check(observed.has(id), "controlled RNG cannot select gem: " + id):
            return
    if not _check(is_equal_approx(Gems.gem_drop_chance(false, false), 0.05) and is_equal_approx(Gems.gem_drop_chance(true, false), 0.38) and is_equal_approx(Gems.gem_drop_chance(true, true), 0.78), "drop rates changed"):
        return
    var gear := {"damage":40.0, "sockets":[{"color":"red", "gem":Gems.make_gem("cleave", 1)}, {"color":"red", "gem":Gems.make_gem("melee_physical_support", 2)}], "links":[true]}
    if not _check(Gems.support_ids(gear, 0).has("melee_physical_support"), "linked compatible melee support inactive"):
        return
    var powered := Gems.skill_damage(gear, 0)
    gear["links"] = [false]
    if not _check(Gems.support_ids(gear, 0).is_empty() and powered > Gems.skill_damage(gear, 0), "unlinked support applied or linked one inert"):
        return
    gear["links"] = [true]
    gear["sockets"][1] = {"color":"red", "gem":Gems.make_gem("inspiration_support", 3)}
    if not _check(Gems.skill_mana(gear, 0) < 10.0 and Gems.skill_damage(gear, 0) > 0, "inspiration support absent"):
        return

    var game := (load("res://main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    await process_frame
    await process_frame
    if not _check(game.has_method("debug_gem_ground_state"), "live game lacks V3 floor implementation"):
        return
    var before: Dictionary = game.call("debug_gem_ground_state")
    var stash_before := int(before["stash"])
    var enemy: Dictionary = (game.get("enemies") as Array)[0]
    var monster := enemy["node"] as CharacterBody3D
    var death_pos := monster.global_position
    var player := game.get("player") as CharacterBody3D
    player.global_position = game.get("region_map").call("clamp_player", death_pos + Vector3(0, 0, 10))
    rng = game.get("_gem_rng") as RandomNumberGenerator
    var winning_seed := -1
    for seed in range(1000):
        rng.seed = seed
        if Gems.should_drop(rng, false, false):
            winning_seed = seed
            break
    if not _check(winning_seed >= 0, "no deterministic 5-percent success seed"):
        return
    rng.seed = winning_seed
    # Exercise the actual enemy-death path, not an isolated model-only roll.
    game.call("_damage_enemy", 0, 9999999.0)
    var after_death: Dictionary = game.call("debug_gem_ground_state")
    if not _check((after_death["world"] as Array).size() == 1 and int(after_death["stash"]) == stash_before, "death must spawn one world gem, never directly give it to the player"):
        return
    var one: Dictionary = (after_death["world"] as Array)[0]
    var world_pos: Vector3 = one["world_position"]
    if not _check(world_pos.distance_to(death_pos) < 2.0 and int(one["uid"]) > 0 and is_instance_valid((game.get("gem_ground") as Array)[0]["node"]), "gem lacks real reachable world object"):
        return
    game.call("_update_gem_ground")
    if not _check(int((game.call("debug_gem_ground_state") as Dictionary)["stash"]) == stash_before, "remote pickup occurred"):
        return
    player.global_position = world_pos
    game.call("_update_gem_ground")
    var picked: Dictionary = game.call("debug_gem_ground_state")
    if not _check((picked["world"] as Array).is_empty() and int(picked["stash"]) == stash_before + 1, "approaching gem did not transfer object exactly once"):
        return
    var stash: Array = game.get("gem_inventory")
    if not _check(int((stash.back() as Dictionary)["uid"]) == int(one["uid"]) and String((stash.back() as Dictionary)["id"]) == String(one["id"]), "gem UID/id changed at pickup"):
        return
    game.call("_update_gem_ground")
    if not _check((game.get("gem_inventory") as Array).size() == stash_before + 1, "duplicate pickup"):
        return

    # Multiple ground gems are independent, and world cap applies only to equipment.
    player.global_position = game.get("region_map").call("clamp_player", world_pos + Vector3(12, 0, 0))
    game.call("_spawn_gem_ground", world_pos, "cleave")
    game.call("_spawn_gem_ground", world_pos + Vector3(3, 0, 0), "arc")
    var ground: Array = game.get("gem_ground")
    if not _check(ground.size() == 2 and int(ground[0]["uid"]) != int(ground[1]["uid"]), "multi-gem identity or world spawn failed"):
        return
    player.global_position = (ground[0]["node"] as Node3D).global_position
    game.call("_update_gem_ground")
    if not _check((game.get("gem_ground") as Array).size() == 1, "picked more than one gem"):
        return
    ground = game.get("gem_ground")
    player.global_position = (ground[0]["node"] as Node3D).global_position
    game.call("_update_gem_ground")
    if not _check((game.get("gem_ground") as Array).is_empty() and (game.get("gem_inventory") as Array).size() == stash_before + 3, "second independent gem not received"):
        return

    # Cast all 10 new actives via the actual 1-5 shortcut path, check mana and CD.
    var armor: Dictionary = (game.get("equipped_armor") as Dictionary)["身體"]
    for i in range(ACTIVE.size()):
        var id: String = ACTIVE[i]
        var gem := Gems.make_gem(id, 30000 + i)
        armor["sockets"] = [{"color":gem["color"], "gem":gem}]
        armor["links"] = []
        (game.get("equipped_armor") as Dictionary)["身體"] = armor.duplicate(true)
        # Weapon's preexisting fireball is first shortcut; new chest skill second.
        game.set("player_mana", 500.0)
        game.call("_refresh_gameplay_ui")
        game.call("_use_skill", 1)
        var timers: Array = game.get("skill_cooldowns")
        if not _check(float(timers[1]) > 0.0 and float(game.get("player_mana")) < 500.0, "active gem did not cast: " + id):
            return
        timers[1] = 0.0
        game.set("skill_cooldowns", timers)
        await process_frame
    _done = true
    print("RIFTFORGED_V3_GEMS_OK pool=27 RNG/all-IDs/rates/death-floor/proximity/UID/multiple/10-casts")
    quit(0)
