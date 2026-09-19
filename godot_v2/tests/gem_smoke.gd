extends SceneTree

const GemSystem = preload("res://scripts/linked_gem_system.gd")
var _finished := false
var _stage := "boot"

func _init() -> void:
    call_deferred("_watchdog")
    call_deferred("_run")

func _watchdog() -> void:
    await create_timer(12.0).timeout
    if not _finished:
        _fail("Gem smoke timed out: " + _stage)

func _fail(message: String) -> void:
    _finished = true
    push_error("GEM_SMOKE_FAIL [%s] %s" % [_stage, message])
    quit(1)

func _run() -> void:
    _stage = "boot"
    var packed := load("res://main.tscn") as PackedScene
    if packed == null:
        _fail("Main game missing")
        return
    var game := packed.instantiate()
    root.add_child(game)
    await process_frame
    await process_frame
    if not game.has_method("debug_gem_state"):
        _fail("Actual game does not mount linked gems")
        return
    var initial: Dictionary = game.call("debug_gem_state")
    var sockets: Array = initial.get("sockets", [])
    var links: Array = initial.get("links", [])
    if sockets.size() != 2 or links.size() != 1 or not bool(links[0]) or String(sockets[0].get("color", "")) != "red" or String(sockets[1].get("color", "")) != "green":
        _fail("Starter must have exactly two opened and connected red-green sockets")
        return
    if int(initial.get("active_index", -1)) != 0 or not (initial.get("supports", []) as Array).has("multishot") or float(initial.get("damage", 0.0)) <= 0.0 or not bool(initial.get("ui_ready", false)):
        _fail("Linked starter fireball, compatible support or real UI not ready")
        return

    _stage = "touch_panel"
    game.call("_open_gem_ui")
    await process_frame
    if not bool((game.call("debug_gem_state") as Dictionary).get("ui_open", false)):
        _fail("Gem button cannot open actual inventory")
        return
    var board := game.get_node_or_null("ArmorEquipment/ArmorRoot/ArmorPanel/LinkedGemPanel/Scroll/Content/SocketBoard") as Control
    if board == null:
        _fail("Live embedded socket board missing")
        return
    if not game.armor_ui.is_open() or not bool((game.call("debug_v5_state") as Dictionary).get("inventory", {}).get("gem_page", false)):
        _fail("Gem editor is not an inner page of the existing equipment inventory")
        return
    var rendered_sockets := 0
    for child in board.get_children():
        if child is Button and child.name.begins_with("Socket_"):
            rendered_sockets += 1
    if rendered_sockets != 2 or game.get_node("MobileUI/Root/GemPanel").visible:
        _fail("Unopened slots or old fake gem panel are visible")
        return
    game.get_node("LinkedGemInventory").call("close")

    _stage = "install_and_color"
    var stash: Array = initial.get("stash", [])
    var chain_index := -1
    for i in range(stash.size()):
        if String(stash[i].get("id", "")) == "chain":
            chain_index = i
    if chain_index < 0:
        _fail("Test chain gem missing")
        return
    game.call("_select_gem", chain_index)
    game.call("_use_socket", 0)
    var rejected: Dictionary = game.call("debug_gem_state")
    if String((rejected["sockets"][0] as Dictionary)["gem"].get("id", "")) != "ember_bolt" or (rejected["stash"] as Array).size() != stash.size():
        _fail("Wrong-colour socket accepted gem or deleted an item")
        return
    game.call("_use_socket", 1)
    var installed: Dictionary = game.call("debug_gem_state")
    if not (installed.get("supports", []) as Array).has("chain") or (installed.get("supports", []) as Array).has("multishot") or (installed.get("stash", []) as Array).size() != stash.size():
        _fail("Linked green support replacement did not recompute effects/conserve gems")
        return
    game.call("_use_socket", 1)
    var extracted: Dictionary = game.call("debug_gem_state")
    if not (extracted.get("supports", []) as Array).is_empty() or (extracted.get("stash", []) as Array).size() != stash.size() + 1:
        _fail("Extract did not return gem or remove support effects")
        return

    _stage = "link_and_tags"
    var weapon: Dictionary = game.call("debug_weapon_state")
    var weapon_sockets: Array = weapon.get("sockets", [])
    weapon_sockets[1]["gem"] = GemSystem.make_gem("multishot", 88881)
    weapon["sockets"] = weapon_sockets
    weapon["links"] = [false]
    game.call("_save_weapon", weapon)
    if not ((game.call("debug_gem_state") as Dictionary).get("supports", []) as Array).is_empty():
        _fail("Unlinked support activated")
        return
    weapon["links"] = [true]
    game.call("_save_weapon", weapon)
    if not ((game.call("debug_gem_state") as Dictionary).get("supports", []) as Array).has("multishot"):
        _fail("Linked and tagged projectile support did not activate")
        return
    var unrelated := weapon.duplicate(true)
    var unrelated_sockets: Array = unrelated.get("sockets", [])
    unrelated_sockets[0]["gem"] = GemSystem.make_gem("crimson_burst", 88882)
    unrelated["sockets"] = unrelated_sockets
    if not GemSystem.support_ids(unrelated, 0).is_empty():
        _fail("Projectile-only support affected area-only skill")
        return

    _stage = "currency"
    var before_currency: Dictionary = game.call("debug_gem_state")
    var currency: Dictionary = before_currency.get("currency", {})
    game.call("_use_currency", "jeweller")
    var opened: Dictionary = game.call("debug_gem_state")
    if (opened.get("sockets", []) as Array).size() != 3 or int((opened.get("currency", {}) as Dictionary).get("jeweller", -1)) != int(currency.get("jeweller", 0)) - 1:
        _fail("Jeweller did not consume currency and open exactly one real socket")
        return
    var old_currency := int((opened.get("currency", {}) as Dictionary).get("fusing", 0))
    game.call("_use_currency", "fusing")
    var fused: Dictionary = game.call("debug_gem_state")
    if (fused.get("links", []) as Array).size() != 2 or int((fused.get("currency", {}) as Dictionary).get("fusing", 0)) != old_currency - 1:
        _fail("Fusing did not reroll graph or consume one item")
        return
    var count_before := _total_gems(fused)
    game.call("_use_currency", "chromatic")
    var recolored: Dictionary = game.call("debug_gem_state")
    if _total_gems(recolored) != count_before:
        _fail("Chromatic deleted socketed gems instead of returning them to stash")
        return
    var refined_stash: Array = recolored.get("stash", [])
    if refined_stash.is_empty():
        _fail("No stash gems left to refine")
        return
    var refine_before := int(refined_stash[0].get("refine", 0))
    game.call("_select_gem", 0)
    game.call("_use_currency", "refine")
    var refined: Dictionary = game.call("debug_gem_state")
    if int((refined.get("stash", []) as Array)[0].get("refine", 0)) != refine_before + 1:
        _fail("Selected gem refine value did not increase")
        return

    _stage = "ground_pickup"
    var player := game.get_node("Player") as CharacterBody3D
    var pickup := GemSystem.make_gem("ember_bolt", 989898)
    var item := {"id":"gem_ember_bolt", "slot":"寶石", "name":String(pickup["name"]), "rarity":"寶石", "color":Color(0.99, 0.32, 0.26), "gem":pickup}
    var stash_before := (refined.get("stash", []) as Array).size()
    game.call("_spawn_loot_visual", player.global_position, item)
    await create_timer(0.12).timeout
    game.call("_update_loot")
    var picked: Dictionary = game.call("debug_gem_state")
    if (picked.get("stash", []) as Array).size() != stash_before + 1:
        _fail("Walk-over ground gem did not enter unified inventory")
        return

    _stage = "aura"
    var aura_weapon: Dictionary = game.call("debug_weapon_state")
    var aura_sockets: Array = aura_weapon.get("sockets", [])
    aura_sockets[2] = {"color":"blue", "gem":GemSystem.make_gem("swift_aura", 989899)}
    aura_weapon["sockets"] = aura_sockets
    game.call("_save_weapon", aura_weapon)
    game.call("_toggle_aura")
    var aura_state: Dictionary = game.call("debug_gem_state")
    if not bool(aura_state.get("aura_on", false)):
        _fail("Installed blue aura cannot toggle on")
        return
    # A stash selection means replacement, not extraction. Clear it first.
    game.call("_select_gem", 0)
    game.call("_use_socket", 2)
    if bool((game.call("debug_gem_state") as Dictionary).get("aura_on", true)):
        _fail("Removing equipped aura did not disable its effect")
        return

    _finished = true
    print("RIFTFORGED_GEM_SMOKE_OK embedded-sockets/links/tags/install/extract/currency/refine/ground-loot/aura")
    quit(0)

func _total_gems(state: Dictionary) -> int:
    var count := (state.get("stash", []) as Array).size()
    for socket in state.get("sockets", []):
        if not ((socket as Dictionary).get("gem", {}) as Dictionary).is_empty():
            count += 1
    return count
