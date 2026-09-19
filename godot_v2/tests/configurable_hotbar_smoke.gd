extends SceneTree

var finished := false

func _init() -> void:
    call_deferred("_run")
    call_deferred("_watchdog")

func _watchdog() -> void:
    await create_timer(24.0).timeout
    if not finished:
        _fail("timeout")

func _fail(message: String) -> void:
    if finished:
        return
    finished = true
    push_error("CONFIGURABLE_HOTBAR_FAIL: " + message)
    quit(1)

func _check(yes: bool, message: String) -> bool:
    if not yes:
        _fail(message)
    return yes

func _run() -> void:
    var game := (load("res://main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    await process_frame
    await process_frame
    var hud := game.get_node_or_null("MobileUI") as RiftConfigurableHotbarHUD
    var bag := game.get_node_or_null("ArmorEquipment") as RiftV5EquipmentUI
    if not _check(hud != null and bag != null and game.has_method("debug_configurable_hotbar"), "real main scene has no configurable 5-slot hotbar"):
        return
    var state: Dictionary = game.debug_configurable_hotbar()
    var assignments: Array = state["assignments"]
    print("HOTBAR_INITIAL slots=", assignments, " primary=", state["primary"])
    if not _check(assignments.size() == 5 and String((assignments[4] as Dictionary).get("kind", "")) == "basic" and String((state["primary"] as Dictionary).get("primary_text", "")).contains("普攻"), "slot five is not the initially equipped basic attack"):
        return
    var first_gem: Dictionary = ((state["entries"] as Array)[0] as Dictionary).get("gem", {})
    var uid := int(first_gem.get("uid", 0))
    if not _check(uid > 0, "starter gem does not have a stable UID"):
        return
    game._pick_hotbar_source("gem", uid)
    game._choose_hotbar_slot(4)
    state = game.debug_configurable_hotbar()
    var entries: Array = state["entries"]
    if not _check(String((entries[0] as Dictionary).get("kind", "")) == "basic" and int(((entries[4] as Dictionary).get("gem", {}) as Dictionary).get("uid", 0)) == uid and String((state["primary"] as Dictionary).get("primary_text", "")).contains(String(first_gem["name"])), "assigning gem to slot five didn't move basic attack to its previous slot"):
        return
    game.debug_set_mana(100.0)
    var mana_before := float(game.player_mana)
    hud.attack_button.pressed.emit()
    if not _check(float(game.player_mana) < mana_before, "large button did not cast the assigned gem"):
        return
    var enemy := (game.enemies[0] as Dictionary).get("node") as CharacterBody3D
    enemy.global_position = game.player.global_position + Vector3(2.0, 0.0, 0.0)
    game.attack_cooldown = 0.0
    var projectiles_before := int(game.projectile_serial)
    hud.skill_buttons[0].pressed.emit()
    if not _check(int(game.projectile_serial) == projectiles_before + 1, "basic attack in slot one didn't fire exactly once"):
        return
    game._choose_hotbar_slot(0)
    game._choose_hotbar_slot(1)
    entries = (game.debug_configurable_hotbar()["entries"] as Array)
    if not _check(String((entries[1] as Dictionary).get("kind", "")) == "basic" and String((entries[0] as Dictionary).get("kind", "")) != "basic", "tapping two slots did not swap their actions"):
        return
    game._pick_hotbar_source("clear")
    game._choose_hotbar_slot(4)
    game._refresh_gameplay_ui()
    entries = (game.debug_configurable_hotbar()["entries"] as Array)
    if not _check(String((entries[4] as Dictionary).get("kind", "")) == "empty" and hud.attack_button.disabled, "manual clear reinstalled a gem or kept an empty primary enabled"):
        return
    game._pick_hotbar_source("gem", uid)
    game._choose_hotbar_slot(4)
    entries = (game.debug_configurable_hotbar()["entries"] as Array)
    if not _check(int(((entries[4] as Dictionary).get("gem", {}) as Dictionary).get("uid", 0)) == uid, "manual reassign did not restore gem"):
        return
    game._open_armor_ui()
    (bag.panel.get_node("HotbarTab") as Button).pressed.emit()
    if not _check(bag.is_open() and bool(game.debug_configurable_hotbar().get("page", false)) and bool(game.debug_configurable_hotbar().get("editor", false)) and (bag.panel.get_node("HotbarEditor") as ScrollContainer).visible, "shortcut editor is not inside the same inventory window"):
        return
    bag.close()
    if not _check(not bool(game.debug_configurable_hotbar().get("page", true)), "closing inventory kept shortcut editor open"):
        return
    finished = true
    print("RIFTFORGED_CONFIGURABLE_HOTBAR_OK five-slots/assign/swap/basic/mana/clear/restore/single-window")
    quit(0)
