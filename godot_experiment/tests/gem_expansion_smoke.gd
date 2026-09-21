extends SceneTree
const Gems = preload("res://scripts/linked_gem_system.gd")
const Builds = preload("res://scripts/build_catalog.gd")
var game
var checks := 0
var finished := false
var failed := false

func _init() -> void:
    call_deferred("run")
    call_deferred("watchdog")

func watchdog() -> void:
    await create_timer(50).timeout
    if not finished:
        push_error("GEM_EXPANSION_FAIL timeout")
        quit(1)

func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failed = true
        push_error("GEM_EXPANSION_FAIL " + message)
        quit(1)
        assert(ok, message)

func gear(ids: Array) -> Dictionary:
    var item: Dictionary = game.equipped_weapon.duplicate(true)
    item.sockets = []
    item.links = []
    for id in ids:
        var gem: Dictionary = game._make_gem(id)
        item.sockets.append({"color":gem.color, "gem":gem})
        if item.sockets.size() > 1:
            item.links.append(true)
    return item

func equip(item: Dictionary) -> void:
    game.equipped_weapon = item
    game.weapon_inventory[game._equipped_weapon_index] = item.duplicate(true)
    game.hotbar_assignments[0] = {"kind":"gem", "uid":int(item.sockets[0].gem.uid)}
    game._last_cast_frame = -1
    game._next_cast_ms.clear()
    game.player_mana = game.player_max_mana
    game._refresh_gameplay_ui()

func run() -> void:
    game = load("res://main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    await process_frame
    game.set_physics_process(false)
    game.gem_effects.set_physics_process(false)
    game._v5_force_mobile = true
    game.player.position = game.region_map.clamp_player(Vector3(0, 0, -60))
    for enemy in game.enemies:
        enemy.node.position = Vector3(18, 0, -130)
    var victim: Dictionary = game.enemies[0]
    victim.hp = 1000000.0
    victim.max_hp = 1000000.0
    var victim_id := int(victim.id)
    var origin: Vector3 = game.player.position
    check(Gems.GEMS.size() == 57 and Gems.drop_pool().size() == 57, "catalog/pool size")
    for original in ["ember_bolt", "crimson_burst", "multishot", "chain", "swift_aura", "rift_trail", "rift_dash"]:
        check(Gems.GEMS.has(original), "original ID lost")
    for title in Builds.RECIPES:
        var item := gear(Builds.RECIPES[title])
        check(Gems.support_ids(item, 0).size() == item.sockets.size() - 1, "invalid recipe " + title)
        item.links[0] = false
        check(Gems.support_ids(item, 0).is_empty(), "unlinked recipe works " + title)
    # Exercise each added active via actual hotbar + mana path, not just helper calls.
    var active_count := 0
    for id in Gems.GEMS:
        var info: Dictionary = Gems.GEMS[id]
        if not bool(info.get("expansion", false)):
            continue
        active_count += 1
        game.gem_effects.clear()
        victim.node.position = origin + Vector3(2, 0, 0)
        var item := gear([id])
        equip(item)
        game.last_aim_direction = Vector3.RIGHT
        game._aim_direction = Vector3.RIGHT
        game._aim_point = origin + Vector3(2, 0, 0)
        game._aim_override = true
        var mana: float = game.player_mana
        var hp: float = victim.hp
        game._use_skill(0)
        check(is_equal_approx(game.player_mana, mana - Gems.skill_mana(item, 0)), "mana charged wrong " + id)
        var after: float = game.player_mana
        game._use_skill(0)
        check(is_equal_approx(game.player_mana, after), "duplicate same-frame cast " + id)
        for step in range(15):
            game.gem_effects.advance(0.1)
        if info.behavior == "projectile":
            await create_timer(0.7).timeout
        check(float(victim.hp) < hp, "skill did not damage " + id)
        game.gem_effects.clear()
        equip(item)
        game.player_mana = 0
        hp = float(victim.hp)
        game._use_skill(0)
        game.gem_effects.advance(1.5)
        check(is_zero_approx(game.player_mana) and is_equal_approx(float(victim.hp), hp), "no-mana skill executed " + id)
        # All new gems use the real ground pickup path and stable UID.
        var stash_before: int = game.gem_inventory.size()
        game._spawn_gem_ground(origin, id)
        game._update_gem_ground()
        check(game.gem_inventory.size() == stash_before + 1, "new gem not picked up " + id)
    check(active_count == 18, "new active count")
    # Every new support is meaningful; forbidden combinations stay inactive.
    for id in Gems.GEMS:
        var info: Dictionary = Gems.GEMS[id]
        if not info.has("damage_multiplier"):
            continue
        var compatible := "spark"
        if id in ["concentrated_effect_support", "area_economy_support", "increased_duration_support", "swift_affliction_support", "brutality_support"]:
            compatible = "cyclone"
        if id == "vicious_projectiles_support":
            compatible = "barrage"
        if id == "minion_damage_support":
            compatible = "summon_sentinel"
        if id == "multiple_totems_support":
            compatible = "flame_totem"
        var plain := gear([compatible])
        var modified := gear([compatible, id])
        check(Gems.support_ids(modified, 0).has(id), "support cannot activate " + id)
        if float(info.damage_multiplier) != 1.0:
            check(not is_equal_approx(Gems.skill_damage(plain, 0), Gems.skill_damage(modified, 0)), "support damage unchanged " + id)
        var incompatible := gear(["rift_dash", id])
        check(Gems.support_ids(incompatible, 0).is_empty(), "invalid movement support " + id)
    check(not Gems.support_ids(gear(["cleave", "brutality_support", "added_fire_support"]), 0).has("added_fire_support"), "brutality permits elemental addition")
    var base := gear(["cyclone"])
    var duration := gear(["cyclone", "increased_duration_support"])
    check(is_equal_approx(game.gem_effects.profile(duration.sockets[0].gem, duration, 0).duration, 3.0), "duration did not extend actual runtime")
    var concentrated := gear(["cyclone", "concentrated_effect_support"])
    check(Gems.skill_radius(concentrated, 0, 4) < Gems.skill_radius(base, 0, 4), "concentrated radius unchanged")
    var efficient := gear(["cyclone", "mana_efficiency_support"])
    check(Gems.skill_mana(efficient, 0) < Gems.skill_mana(base, 0), "efficiency did not save mana")
    var duplicated := gear(["cyclone", "inspiration_support", "inspiration_support"])
    check(Gems.support_ids(duplicated, 0).size() == 1, "duplicate support stacks")
    # Duration cannot send the travelling orb beyond its fixed maximum range.
    var orb := gear(["ball_lightning", "increased_duration_support"])
    game.gem_effects.cast(orb.sockets[0].gem, orb, 0)
    for step in range(26):
        game.gem_effects.advance(0.1)
    check(game.gem_effects.effects.is_empty(), "duration increased orb beyond maximum range")
    # Real volley/echo emissions, minion cap, expiry and modal pause.
    var echo := gear(["spark", "echo_support", "volley_support"])
    game._aim_shot_history.clear()
    game.gem_effects.cast(echo.sockets[0].gem, echo, 0)
    check(game._aim_shot_history.size() == 7, "volley not emitted")
    game.gem_effects.advance(0.2)
    check(game._aim_shot_history.size() == 14, "echo not emitted")
    await create_timer(0.8).timeout
    for id in ["summon_sentinel", "flame_totem"]:
        game.gem_effects.clear()
        var item := gear([id, "multiple_totems_support"] if id == "flame_totem" else [id])
        for n in range(6):
            game.gem_effects.cast(item.sockets[0].gem, item, 0)
        check(game.gem_effects.effects.size() == 3, "construct cap " + id)
        for step in range(70):
            game.gem_effects.advance(0.1)
        check(game.gem_effects.effects.is_empty(), "construct expiry " + id)
    game.gem_effects.cast(base.sockets[0].gem, base, 0)
    game._open_gem_ui()
    var duration_before: float = game.gem_effects.effects[0].left
    game.gem_effects._physics_process(0.2)
    check(is_equal_approx(game.gem_effects.effects[0].left, duration_before), "inventory did not pause effects")
    check(game.gem_ui.build_choice.item_count == 24, "guide missing recipes")
    game.gem_ui.build_choice.select(22)
    game.gem_ui._show_build()
    check(game.gem_ui.build_details.text.contains("寒霜領域"), "guide not displaying selected recipe")
    game.gem_ui.search_gems.text = "寒霜領域"
    game.gem_ui._filter_stash()
    for button in game.gem_ui.stash_list.get_children():
        if button is Button and not button.is_queued_for_deletion() and button.visible:
            check(button.text.contains("寒霜領域"), "stash search exposes unrelated item")
    game.gem_effects.clear()
    check(game.gem_effects.effects.is_empty(), "effect cleanup failed")
    finished = true
    if failed:
        quit(1)
        return
    print("GEM_EXPANSION_OK checks=", checks, " actives=18 catalog=57 builds=23")
    game.queue_free()
    await process_frame
    quit(0)
