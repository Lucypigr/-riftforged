extends SceneTree

const Gems = preload("res://scripts/linked_gem_system.gd")
const Loot = preload("res://scripts/loot_system.gd")
var _done := false

func _init() -> void:
    call_deferred("_run")
    call_deferred("_watchdog")

func _watchdog() -> void:
    await create_timer(19.0).timeout
    if not _done:
        _fail("watchdog")

func _fail(reason: String) -> void:
    if _done:
        return
    _done = true
    push_error("V4_INTEGRITY_FAIL: " + reason)
    quit(1)

func _check(ok: bool, reason: String) -> bool:
    if not ok:
        _fail(reason)
    return ok

func _run() -> void:
    var game := (load("res://main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    await process_frame
    await process_frame
    var builds: Dictionary = game.call("debug_v4_builds")
    if not _check(builds.size() == 5, "five independently selectable builds missing"):
        return
    for build_name in builds.keys():
        var ids: Array = builds[build_name]
        if not _check(ids.size() == 3, "build must be one active and two supports: " + String(build_name)):
            return
        var sockets := []
        for n in range(3):
            var gem: Dictionary = Gems.make_gem(String(ids[n]), 50000 + n)
            if not _check(not gem.is_empty(), "unregistered build gem: " + String(ids[n])):
                return
            sockets.append({"color":gem["color"], "gem":gem})
        var gear := {"damage":34.0, "sockets":sockets, "links":[true, true]}
        var supports := Gems.support_ids(gear, 0)
        if not _check(supports.has(String(ids[1])) and supports.has(String(ids[2])) and Gems.skill_mana(gear, 0) >= 0.0 and Gems.skill_damage(gear, 0) > 0.0, "build has incompatible or inactive support: " + String(build_name)):
            return
    # The originally proposed Added Fire gem has no matching attack tag on
    # fireball. Preserve its original record and use Inspiration instead.
    var invalid := {"damage":30.0, "sockets":[{"color":"red", "gem":Gems.make_gem("ember_bolt", 101)}, {"color":"red", "gem":Gems.make_gem("added_fire_support", 102)}], "links":[true]}
    if not _check(Gems.support_ids(invalid, 0).is_empty(), "invalid spell support was forcibly enabled"):
        return
    var player := game.get("player") as CharacterBody3D
    var source := (Loot.BASE_ITEMS[0] as Dictionary).duplicate(true)
    source["rarity"] = "普通"
    source["prefix"] = {}
    source["suffix"] = {}
    source["level"] = 2
    source["color"] = Color.WHITE
    var place := game.get("region_map").call("clamp_player", Vector3(0, 0, -62)) as Vector3
    player.global_position = game.get("region_map").call("clamp_player", place + Vector3(0, 0, 12))
    var before_weapon := (game.get("weapon_inventory") as Array).size()
    game.call("_spawn_loot_visual", place, source)
    var ground: Array = game.get("loot_drops")
    var dropped: Dictionary = (ground.back() as Dictionary)["item"]
    if not _check((dropped.get("sockets", []) as Array).size() > 0 and dropped.has("links") and int(dropped.get("instance_uid", 0)) > 0, "weapon sockets/links/UID must be rolled at death, not pickup"):
        return
    var sockets_before := (dropped["sockets"] as Array).duplicate(true)
    var links_before := (dropped["links"] as Array).duplicate(true)
    var uid_before := int(dropped["instance_uid"])
    await create_timer(0.12).timeout
    game.call("_update_loot")
    if not _check((game.get("weapon_inventory") as Array).size() == before_weapon, "weapon picked up remotely"):
        return
    player.global_position = (ground.back()["node"] as Node3D).global_position
    await create_timer(0.12).timeout
    game.call("_update_loot")
    var bag: Array = game.get("weapon_inventory")
    if not _check(bag.size() == before_weapon + 1 and (bag.back() as Dictionary).get("sockets", []) == sockets_before and (bag.back() as Dictionary).get("links", []) == links_before and int((bag.back() as Dictionary).get("instance_uid", 0)) == uid_before, "weapon identity/sockets/links changed after pickup"):
        return
    # Oracle summons cannot grow unbounded and die with their owner.
    var owner_id := -1
    var center := Vector3.ZERO
    for entry_value in game.get("enemies"):
        var entry: Dictionary = entry_value
        if String((entry["archetype"] as Dictionary).get("id", "")) == "rift_oracle":
            owner_id = int(entry["id"])
            center = (entry["node"] as CharacterBody3D).global_position
            break
    if not _check(owner_id > 0, "oracle absent"):
        return
    player.global_position = game.get("region_map").call("clamp_player", center + Vector3(18, 0, 0))
    game.call("_summon_minions", owner_id, center, 2)
    game.call("_summon_minions", owner_id, center, 2)
    var owned := 0
    for entry_value in game.get("enemies"):
        if int((entry_value as Dictionary).get("summoned_by", -1)) == owner_id:
            owned += 1
    if not _check(owned > 0 and owned <= 2, "summoner cap failed"):
        return
    var owner_index := int(game.call("_enemy_index_by_id", owner_id))
    game.call("_damage_enemy", owner_index, 9999999.0)
    for entry_value in game.get("enemies"):
        if not _check(int((entry_value as Dictionary).get("summoned_by", -1)) != owner_id, "orphan minion remains after summoner death"):
            return
    # A dangerous attack first places a live telegraph in the world and then
    # resolves once. Avoid evaluating real-device rendering in headless tests.
    game.call("_warning_blast", Vector3(0, 0, -120), 3.0, 9.0, 0.25, -1)
    var danger := 0
    for child in (game.get("projectiles_root") as Node3D).get_children():
        if child.name == "DangerTelegraph" and not child.is_queued_for_deletion():
            danger += 1
    if not _check(danger > 0, "telegraph not spawned"):
        return
    await create_timer(0.35).timeout
    danger = 0
    for child in (game.get("projectiles_root") as Node3D).get_children():
        if child.name == "DangerTelegraph" and not child.is_queued_for_deletion():
            danger += 1
    if not _check(danger == 0, "warning did not resolve and clean up"):
        return
    _done = true
    print("RIFTFORGED_V4_INTEGRITY_OK builds5/weapon-identity/floor/proximity/minion-cap/telegraph")
    quit(0)
