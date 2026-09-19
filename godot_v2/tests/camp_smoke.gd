extends SceneTree

var finished := false

func _init() -> void:
    call_deferred("_run")
    call_deferred("_watchdog")

func _watchdog() -> void:
    await create_timer(35.0).timeout
    if not finished:
        _fail("watchdog timeout")

func _fail(reason: String) -> void:
    if finished:
        return
    finished = true
    push_error("CAMP01_FAIL: " + reason)
    quit(1)

func _check(valid: bool, reason: String) -> bool:
    if not valid:
        _fail(reason)
    return valid

func _run() -> void:
    var game := (load("res://main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    await process_frame
    await process_frame
    var state: Dictionary = game.debug_camp_state()
    if not _check(state["region"] == "camp" and state["camp_visible"] and not state["arena_visible"], "new game does not begin in visible safe camp"):
        return
    if not _check(not state["enemy_visible"] and int(state["enemy_count"]) > 0 and not game._boss_defeated, "camp exposed enemy while existing encounters were not preserved"):
        return
    if not _check(game.get_node_or_null("SafeCamp/CampFloorCollision") != null and game.get_node_or_null("SafeCamp/CombatPortal") != null and game.get_node_or_null("CampInteractionHUD/CampOverlay/EnterCombatPortal") != null, "walkable floor or actual portal/button absent"):
        return
    var initial_hp: float = game.player_hp
    var initial_mana: float = game.player_mana
    var initial_shots: int = game.projectile_serial
    var initial_weapon: Dictionary = game.equipped_weapon.duplicate(true)
    var initial_weapons: Array = game.weapon_inventory.duplicate(true)
    var initial_armors: Array = game.armor_inventory.duplicate(true)
    var initial_equipped_armor: Dictionary = game.equipped_armor.duplicate(true)
    var initial_gems: Array = game.gem_inventory.duplicate(true)
    var initial_currency: Dictionary = game.gem_currency.duplicate(true)
    var initial_hotbar: Array = game.hotbar_assignments.duplicate(true)
    var initial_loot_count: int = game.loot_drops.size() + game.gem_ground.size()
    game._damage_player(900.0)
    game._attack()
    game._use_skill(0)
    game._interact_portal()
    if not _check(game.player_hp == initial_hp and game.player_mana == initial_mana and game.projectile_serial == initial_shots and game.debug_camp_state()["region"] == "camp", "safe camp accepted damage, attack or distant interaction"):
        return
    var start: Vector3 = game.player.global_position
    game.move_input = Vector2(0, -1)
    await physics_frame
    await physics_frame
    if not _check(game.player.global_position.z < start.z and game.debug_camp_state()["region"] == "camp", "walking in camp is not functional"):
        return
    game.move_input = Vector2.ZERO
    game.player.global_position = state["portal_position"] + Vector3(0, 0, 2.0)
    game._physics_process(0.0)
    if not _check(game._camp_button.visible, "nearby interaction control did not appear"):
        return
    var key := InputEventKey.new()
    key.keycode = KEY_F
    key.pressed = true
    game._unhandled_input(key)
    state = game.debug_camp_state()
    if not _check(state["region"] == "combat" and state["arena_visible"] and not state["camp_visible"] and state["enemy_visible"] and state["portal_uses"] == 1, "keyboard portal did not switch to existing combat world"):
        return
    if not _check(game.player.global_position.distance_to(game.region_map.spawn_position()) < 0.05 and game.region_map.streaming_state()["loaded"] > 0, "combat destination or terrain streaming is invalid"):
        return
    if not _check(game.equipped_weapon == initial_weapon and game.weapon_inventory == initial_weapons and game.armor_inventory == initial_armors and game.equipped_armor == initial_equipped_armor and game.gem_inventory == initial_gems and game.gem_currency == initial_currency and game.hotbar_assignments == initial_hotbar, "portal reinitialized equipment, sockets, gems, currency, or hotbar"):
        return
    if not _check(game.loot_drops.size() + game.gem_ground.size() == initial_loot_count and game._boss_id > 0 and not game._boss_defeated, "portal deleted world loot or reset boss state"):
        return
    game._interact_portal()
    if not _check(game.debug_camp_state()["portal_uses"] == 1, "portal could enter repeatedly outside camp"):
        return
    game.queue_free()
    await process_frame
    var mobile := (load("res://main.tscn") as PackedScene).instantiate()
    root.add_child(mobile)
    await process_frame
    mobile.player.global_position = mobile.debug_camp_state()["portal_position"] + Vector3(0, 0, 2.0)
    mobile._physics_process(0.0)
    var touch_button := mobile.get_node("CampInteractionHUD/CampOverlay/EnterCombatPortal") as Button
    if not _check(touch_button.visible and touch_button.pressed.is_connected(Callable(mobile, "_interact_portal")), "mobile/Web GUI portal button is not operable"):
        return
    touch_button.pressed.emit()
    if not _check(mobile.debug_camp_state()["region"] == "combat" and mobile.debug_camp_state()["portal_uses"] == 1, "button activation did not enter combat exactly once"):
        return
    finished = true
    print("RIFTFORGED_CAMP01_OK safe-spawn/floor/movement/no-damage/no-attack/proximity/PC-F/touch-button/inventory/boss/loot/streaming")
    quit(0)
