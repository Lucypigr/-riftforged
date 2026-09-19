extends SceneTree

const Gems = preload("res://scripts/linked_gem_system.gd")
const ACTIVE := ["cleave", "ground_slam", "molten_strike", "burning_arrow", "split_arrow", "ice_shot", "galvanic_arrow", "freezing_pulse", "arc", "frost_nova"]
var _done := false
var _stage := "boot"

func _init() -> void:
    call_deferred("_run")
    call_deferred("_watchdog")

func _watchdog() -> void:
    await create_timer(25.0).timeout
    if not _done:
        _fail("timeout")

func _fail(message: String) -> void:
    if _done:
        return
    _done = true
    push_error("V4_SMOKE_FAIL [%s] %s" % [_stage, message])
    quit(1)

func _check(condition: bool, message: String) -> bool:
    if not condition:
        _fail(message)
    return condition

func _run() -> void:
    var scene := load("res://main.tscn") as PackedScene
    if not _check(scene != null, "main scene absent"):
        return
    var game := scene.instantiate()
    root.add_child(game)
    await process_frame
    await process_frame
    var state: Dictionary = game.call("debug_v4_state")
    _stage = "density_boss"
    if not _check(int(state.get("enemy_count", 0)) >= 36 and int(state.get("enemy_count", 0)) <= int(state.get("cap", 0)) and bool(state.get("boss_bar", false)) and int(state.get("boss_id", -1)) > 0, "V4 density or boss failed to spawn"):
        return
    var types: Array = game.call("debug_archetypes")
    for id in ["bone_runner", "rift_bulwark", "crystal_archer", "swamp_sapper", "frost_wraith", "rift_oracle", "rift_lord"]:
        if not _check(types.has(id), "special archetype absent: " + id):
            return
    var player := game.get("player") as CharacterBody3D
    for enemy_value in game.get("enemies"):
        var enemy: Dictionary = enemy_value
        var body := enemy.get("node") as CharacterBody3D
        if not bool(enemy.get("boss", false)) and not _check(body.global_position.distance_to(player.global_position) >= 4.0, "enemy spawned on the player"):
            return
    _stage = "skill_mana"
    var hud := game.get_node("MobileUI")
    if not _check(((game.call("debug_hotbar_state") as Dictionary).get("ids", []) as Array)[0] == "ember_bolt", "starter skill missing"):
        return
    game.call("debug_set_mana", 100.0)
    var start_mana := float(game.get("player_mana"))
    game.call("_use_skill", 0)
    var first_mana := float(game.get("player_mana"))
    if not _check(first_mana < start_mana and is_zero_approx(float((game.get("skill_cooldowns") as Array)[0])) and not (hud.skill_buttons[0] as Button).disabled, "mana cast must not start time cooldown"):
        return
    await create_timer(0.48).timeout
    game.call("_use_skill", 0)
    if not _check(float(game.get("player_mana")) < first_mana, "second cast blocked despite enough mana"):
        return
    await create_timer(0.48).timeout
    game.call("debug_set_mana", 0.0)
    game.call("_use_skill", 0)
    if not _check(is_zero_approx(float(game.get("player_mana"))), "insufficient mana cast or spend"):
        return
    _stage = "flasks"
    game.call("debug_set_hp", 45.0)
    var first_charge := int((game.get("flask_charges") as Array)[0])
    game.call("_use_flask", 0)
    if not _check(int((game.get("flask_charges") as Array)[0]) == first_charge - 10 and float(game.get("player_hp")) > 45.0, "life flask didn't consume charge and heal"):
        return
    var after_life := int((game.get("flask_charges") as Array)[0])
    game.call("debug_set_hp", float(game.get("player_max_hp")))
    game.call("_use_flask", 0)
    if not _check(int((game.get("flask_charges") as Array)[0]) == after_life, "full health spent flask"):
        return
    var ordinary: Dictionary = (game.get("enemies") as Array)[0]
    game.call("_damage_enemy", 0, 9999999.0)
    if not _check(int((game.get("flask_charges") as Array)[0]) == mini(40, after_life + 2), "ordinary kill did not refund 2 charges"):
        return
    game.call("_grant_kill_charges", ordinary)
    if not _check(int((game.get("flask_charges") as Array)[0]) == mini(40, after_life + 2), "same monster refunded twice"):
        return
    _stage = "persistent_floor"
    var original := int((game.call("debug_v4_state") as Dictionary)["floor"])
    for i in range(30):
        game.call("_spawn_loot_visual", Vector3(0, 0, -75.0 + float(i) * 0.7), {"id":"currency_jeweller", "slot":"通貨", "currency":"jeweller", "name":"開孔石", "rarity":"通貨", "color":Color.GOLD})
    if not _check(int((game.call("debug_v4_state") as Dictionary)["floor"]) >= original + 30, "ground cap silently deleted unpicked loot"):
        return
    var stored_currency := int((game.get("gem_currency") as Dictionary)["jeweller"])
    var floor: Array = game.get("loot_drops")
    var pickup_node := floor.back()["node"] as Node3D
    player.global_position = pickup_node.global_position + Vector3(0, 0, 8)
    await create_timer(0.11).timeout
    game.call("_update_loot")
    if not _check(int((game.get("gem_currency") as Dictionary)["jeweller"]) == stored_currency, "remote pickup occurred"):
        return
    player.global_position = pickup_node.global_position
    await create_timer(0.11).timeout
    game.call("_update_loot")
    if not _check(int((game.get("gem_currency") as Dictionary)["jeweller"]) > stored_currency, "ground currency didn't enter wallet"):
        return
    _stage = "boss_rewards"
    var boss_id := int((game.call("debug_v4_state") as Dictionary)["boss_id"])
    var boss_index := int(game.call("_enemy_index_by_id", boss_id))
    if not _check(boss_index >= 0, "region boss missing before encounter"):
        return
    var boss: Dictionary = (game.get("enemies") as Array)[boss_index]
    var before_boss: Dictionary = game.call("debug_v4_state")
    game.call("_damage_enemy", boss_index, 9999999.0)
    var dead: Dictionary = game.call("debug_v4_state")
    if not _check(bool(dead.get("boss_defeated", false)) and int(game.call("_enemy_index_by_id", boss_id)) < 0 and int(dead["floor"]) + int(dead["gems"]) > int(before_boss["floor"]) + int(before_boss["gems"]), "boss did not die uniquely and drop floor reward"):
        return
    game.call("_grant_kill_charges", boss)
    if not _check(int((game.get("flask_charges") as Array)[0]) <= 40, "boss rewards exceeded flask charge cap"):
        return
    _stage = "v3_gems"
    if not _check(Gems.drop_pool().size() == 27, "V3 full 27-gem pool missing"):
        return
    for id in ACTIVE:
        if not _check(Gems.drop_pool().has(id), "active gem not drop eligible: " + id):
            return
    var armor: Dictionary = (game.get("equipped_armor") as Dictionary)["身體"]
    for i in range(ACTIVE.size()):
        var gem := Gems.make_gem(ACTIVE[i], 40000 + i)
        armor["sockets"] = [{"color":gem["color"], "gem":gem}]
        armor["links"] = []
        (game.get("equipped_armor") as Dictionary)["身體"] = armor.duplicate(true)
        game.call("debug_set_mana", 100.0)
        game.call("_refresh_gameplay_ui")
        var mana_start := float(game.get("player_mana"))
        game.call("_use_skill", 1)
        if not _check(float(game.get("player_mana")) < mana_start and is_zero_approx(float((game.get("skill_cooldowns") as Array)[1])), "V3 active failed without cooldown: " + ACTIVE[i]):
            return
        await create_timer(0.41).timeout
    _done = true
    print("RIFTFORGED_V4_OK combat/mana/flask/loot-30/density/special/boss/ten-actives")
    quit(0)
