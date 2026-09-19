extends SceneTree

const LootSystem = preload("res://scripts/loot_system.gd")
const GemSystem = preload("res://scripts/linked_gem_system.gd")
const ArmorSystem = preload("res://scripts/armor_equipment.gd")
const FONT_PATH := "res://fonts/NotoSansTC-Riftforged.ttf"
const GLYPHS := ["攻", "擊", "寶", "石", "裂", "隙", "獸", "菁", "英", "裝", "備", "頭", "身", "腿", "鞋", "孔", "洞", "法", "全", "螢", "幕", "◆", "◇"]
var _done := false
var _stage := "boot"

func _init() -> void:
    call_deferred("_watchdog")
    call_deferred("_run")

func _watchdog() -> void:
    await create_timer(19.0).timeout
    if not _done:
        _fail("Timed out")

func _fail(message: String) -> void:
    _done = true
    push_error("RIFTFORGED_SMOKE_FAIL [%s] %s" % [_stage, message])
    quit(1)

func _check_stage(name: String) -> void:
    _stage = name
    print("RIFTFORGED_SMOKE_STAGE ", name)

func _run() -> void:
    _check_stage("font")
    var file := FileAccess.open(FONT_PATH, FileAccess.READ)
    if file == null:
        _fail("Bundled Traditional Chinese font missing")
        return
    var header := file.get_buffer(4)
    file.close()
    if header.size() != 4 or header[0] != 0 or header[1] != 1 or header[2] != 0 or header[3] != 0:
        _fail("Font source is not TrueType")
        return
    var imported := ResourceLoader.load(FONT_PATH, "FontFile", ResourceLoader.CACHE_MODE_REUSE) as FontFile
    if imported == null or imported.data.is_empty():
        _fail("Imported font resource missing")
        return
    imported.allow_system_fallback = false
    for glyph in GLYPHS:
        if not imported.has_char(glyph.unicode_at(0)):
            _fail("Missing Chinese glyph " + glyph)
            return
    _check_stage("scene")
    var packed := load("res://main.tscn") as PackedScene
    if packed == null:
        _fail("Main scene could not load")
        return
    var game := packed.instantiate()
    root.add_child(game)
    await process_frame
    await process_frame
    for path in ["Player", "Enemies", "Projectiles", "Loot", "MobileUI", "LinkedGemInventory", "ArmorEquipment"]:
        if game.get_node_or_null(path) == null:
            _fail("Missing runtime node " + path)
            return
    var world: Dictionary = game.call("debug_region_state")
    var region := game.get_node_or_null(NodePath(String(world.get("region", "")))) as Node3D
    if region == null or region.get_node_or_null("Ground") == null or float(world.get("south_edge", 0)) - float(world.get("north_edge", 0)) < 290.0 or int(world.get("zones", 0)) != 6 or int(world.get("landmarks", 0)) < 7 or not bool(world.get("region02_exit", false)):
        _fail("Large region/exit contract changed")
        return
    _check_stage("terrain_stream")
    var initial: Dictionary = game.call("debug_streaming_state")
    if int(initial.get("loaded", 0)) < 2 or int(initial.get("loaded", 0)) > 5 or int(world.get("chunk_total", 0)) != 15:
        _fail("Terrain stream budget invalid")
        return
    region.call("update_streaming", Vector3(0, 0, -122))
    var north: Dictionary = game.call("debug_streaming_state")
    if int(north.get("center", -1)) < 10 or int(north.get("loaded", 0)) > 5 or (north.get("active", []) as Array) == (initial.get("active", []) as Array):
        _fail("Terrain chunks did not move north")
        return
    region.call("update_streaming", Vector3(0, 0, 128))
    _check_stage("perf_desktop")
    var perf: Dictionary = game.call("debug_perf_pass2")
    var pool: Dictionary = perf.get("pool", {})
    var desktop: Dictionary = game.call("debug_desktop_profile")
    if int(perf.get("ai_phases", 0)) != 2 or int(perf.get("loot_cap", 0)) != 24 or int(pool.get("player_projectiles", 0)) < 10 or int(pool.get("enemy_projectiles", 0)) < 10 or not bool(desktop.get("enabled", false)) or desktop.get("content_scale_size", Vector2i.ZERO) != Vector2i(1280, 720):
        _fail("Pool, mobile performance or desktop profile regressed")
        return
    var player := game.get_node("Player") as CharacterBody3D
    var spawn: Vector3 = world.get("player_spawn", Vector3.ZERO)
    if player.global_position.distance_to(spawn) > 0.25:
        _fail("South camp spawn missing")
        return
    var camera := player.get_node("Camera3D") as Camera3D
    if camera == null or camera.projection != Camera3D.PROJECTION_ORTHOGONAL or camera.keep_aspect != Camera3D.KEEP_HEIGHT or (player.get_node("Visual") as Sprite3D).texture == null:
        _fail("Player camera/art missing")
        return
    _check_stage("monster_diversity")
    var enemies := game.get_node("Enemies") as Node3D
    var types: Array = game.call("debug_archetypes")
    var expected_types := ["rift_stalker", "rift_warden", "rift_hexer", "rift_champion", "bone_runner", "rift_bulwark", "crystal_archer", "swamp_sapper", "rift_oracle"]
    if enemies.get_child_count() < 19:
        _fail("Only a few monsters spawned")
        return
    for name in expected_types:
        if not types.has(name):
            _fail("Distinct enemy archetype absent: " + name)
            return
    var first := enemies.get_child(0) as CharacterBody3D
    var first_label := first.get_node_or_null("NameLabel") as Label3D
    if first_label == null or first_label.font == null or not first_label.text.contains("裂隙") or (first.get_node("Visual") as Sprite3D).texture == null:
        _fail("Enemy sprite or Chinese label regressed")
        return
    _check_stage("ui_hotbar")
    var ui_root := game.get_node("MobileUI/Root") as Control
    var ui := game.get_node("MobileUI") as RiftPoEInventoryUI
    var hint := ui_root.get_node_or_null("Hint") as Label
    if ui == null or hint == null or not hint.text.contains("WASD") or not hint.text.contains("1–5") or ui_root.theme.default_font != imported or (ui_root.get_node("AttackButton") as Button).visible:
        _fail("Font, help or desktop HUD regressed")
        return
    var hotbar: Dictionary = game.call("debug_hotbar_state")
    var inventory_state: Dictionary = hotbar.get("inventory", {})
    if hotbar.get("ids", []) != ["ember_bolt", "", "", "", ""] or int(inventory_state.get("columns", 0)) != 8 or int(inventory_state.get("skill_buttons", 0)) != 5 or not bool(inventory_state.get("grid_ready", false)):
        _fail("Only installed active gems may fill slots 1–5")
        return
    for i in range(5):
        var button := ui_root.get_node_or_null("SkillButton%d" % i) as Button
        if button == null or not button.visible or (i > 0 and (not button.disabled or button.icon != null)):
            _fail("Empty hotbar slot is not disabled")
            return
    if ui_root.get_node_or_null("BasicAttackSlot") == null or hotbar.get("basic_attack", "") != "left_click" or not hotbar.get("flasks", []).has("Q"):
        _fail("Left-click basic attack and Q/E flasks missing")
        return
    _check_stage("full_map")
    var map_key := InputEventKey.new()
    map_key.keycode = KEY_M
    map_key.pressed = true
    game.call("_unhandled_input", map_key)
    await process_frame
    if not bool((game.call("debug_map_state") as Dictionary).get("open", false)):
        _fail("M did not open region map")
        return
    game.call("_unhandled_input", map_key)
    await process_frame
    if bool((game.call("debug_map_state") as Dictionary).get("open", true)):
        _fail("M did not close region map")
        return
    _check_stage("basic_attack")
    # With 19 living enemies, isolate targets; don't assume the first child is
    # nearest by accident. Other enemies are moved away only in this test.
    for i in range(1, enemies.get_child_count()):
        var other := enemies.get_child(i) as CharacterBody3D
        other.global_position = spawn + Vector3(26.0 + float(i), 0, -36.0)
    first.global_position = player.global_position + Vector3(2, 0, 0)
    var old_label := first_label.text
    game.call("_attack")
    await process_frame
    if int(game.call("debug_projectile_count")) < 1:
        _fail("Basic attack did not fire")
        return
    await create_timer(0.43).timeout
    await process_frame
    if is_instance_valid(first_label) and first_label.text == old_label:
        _fail("Basic attack did not hurt nearest enemy")
        return
    _check_stage("mouse_attack")
    var mouse_target := enemies.get_child(1) as CharacterBody3D
    mouse_target.global_position = player.global_position + Vector3(3, 0, 0)
    var mouse_label := mouse_target.get_node("NameLabel") as Label3D
    var old_mouse := mouse_label.text
    var click := InputEventMouseButton.new()
    click.button_index = MOUSE_BUTTON_LEFT
    click.pressed = true
    click.position = camera.unproject_position(mouse_target.global_position + Vector3(0, 1, 0))
    game.call("_unhandled_input", click)
    await process_frame
    click.pressed = false
    game.call("_unhandled_input", click)
    await create_timer(0.42).timeout
    await process_frame
    if is_instance_valid(mouse_label) and mouse_label.text == old_mouse:
        _fail("Desktop left click did not hit chosen enemy")
        return
    _check_stage("gem_skills")
    var mana_before := float((game.call("debug_resource_state") as Dictionary).get("mana", 0.0))
    game.call("_use_skill", 2)
    if absf(mana_before - float((game.call("debug_resource_state") as Dictionary).get("mana", 0.0))) > 0.001:
        _fail("Empty slot spent mana")
        return
    game.call("_use_skill", 0)
    await process_frame
    var cds: Array = game.call("debug_skill_cooldowns")
    if cds.size() != 5 or float(cds[0]) <= 0.0:
        _fail("Installed fireball has no cooldown")
        return
    var before_tick := float(cds[0])
    await create_timer(0.15).timeout
    if float((game.call("debug_skill_cooldowns") as Array)[0]) >= before_tick - 0.05:
        _fail("Cooldown stopped ticking")
        return
    _check_stage("armor_equipment")
    var armor: Dictionary = game.call("debug_armor_state")
    var slots: Dictionary = armor.get("slots", {})
    if not bool(armor.get("panel_ready", false)) or int(slots.get("頭部", 0)) < 1 or int(slots.get("身體", 0)) < 1 or int(slots.get("腿部", 0)) < 1 or int(slots.get("鞋子", 0)) < 1 or float(armor.get("defense", 0)) < 30.0:
        _fail("Head/chest/legs/boots lack independent sockets or armor")
        return
    game.call("_open_armor_ui")
    await process_frame
    if not bool((game.call("debug_armor_state") as Dictionary).get("panel_open", false)):
        _fail("Wearable equipment screen cannot open")
        return
    for slot in ArmorSystem.SLOTS:
        if game.get_node_or_null("ArmorEquipment/ArmorRoot/ArmorPanel/GearScroll/GearList/Gear_" + slot) == null:
            _fail("Missing editable armor slot row: " + slot)
            return
    game.call("_open_equipment_sockets", "頭部")
    await process_frame
    if String((game.call("debug_armor_state") as Dictionary).get("editing", "")) != "頭部" or not bool((game.call("debug_gem_state") as Dictionary).get("ui_open", false)):
        _fail("Head slot cannot enter live socket editor")
        return
    var stash: Array = (game.call("debug_gem_state") as Dictionary).get("stash", [])
    var crimson := -1
    for i in range(stash.size()):
        if String((stash[i] as Dictionary).get("id", "")) == "crimson_burst":
            crimson = i
    if crimson < 0:
        _fail("Starter bag missing red skill for helmet installation")
        return
    game.call("_select_gem", crimson)
    game.call("_use_socket", 0)
    var head: Dictionary = (game.get("equipped_armor") as Dictionary).get("頭部", {})
    if String(((head.get("sockets", []) as Array)[0] as Dictionary).get("gem", {}).get("id", "")) != "crimson_burst" or (game.call("debug_hotbar_state") as Dictionary).get("ids", [])[1] != "crimson_burst":
        _fail("Helmet gem did not become genuine hotbar skill")
        return
    if (game.call("debug_weapon_state") as Dictionary).get("sockets", []).size() != 2:
        _fail("Helmet gem editing mutated weapon sockets")
        return
    game.call("_use_currency", "jeweller")
    head = (game.get("equipped_armor") as Dictionary).get("頭部", {})
    if (head.get("sockets", []) as Array).size() != 2:
        _fail("Armor jeweller did not open a new real socket")
        return
    game.get_node("LinkedGemInventory").call("close")
    game.call("_equip_armor", 0)
    var swapped: Dictionary = game.call("debug_armor_state")
    if (game.call("debug_hotbar_state") as Dictionary).get("ids", [])[1] != "" or int(swapped.get("bag", 0)) != 1:
        _fail("Replacing helmet did not unbind skill or preserve old item")
        return
    game.call("_equip_armor", 0)
    if (game.call("debug_hotbar_state") as Dictionary).get("ids", [])[1] != "crimson_burst":
        _fail("Restored helmet lost installed gem")
        return
    _check_stage("armor_pickup")
    var bag_before := int((game.call("debug_armor_state") as Dictionary).get("bag", 0))
    var loot := {"id":"test_legguards", "slot":"腿部", "name":"測試護腿", "rarity":"魔法", "level":2, "armor":17.0, "prefix":{}, "suffix":{}, "color":Color(0.4, 0.7, 1.0)}
    game.call("_spawn_loot_visual", player.global_position, loot)
    game.call("_update_loot")
    if int((game.call("debug_armor_state") as Dictionary).get("bag", 0)) != bag_before + 1:
        _fail("Walk-over armor loot was not collected")
        return
    if not LootSystem.BASE_ITEMS.any(func(item: Dictionary): return String(item.get("slot", "")) == "頭部"):
        _fail("Monster loot table has no new armor bases")
        return
    _check_stage("old_weapon_and_region")
    game.call("debug_add_test_weapon", "blade")
    if int(game.call("debug_weapon_inventory_count")) < 2:
        _fail("Old weapon inventory no longer accepts items")
        return
    ui.call("_toggle_equipment_panel")
    var weapon_panel := ui_root.get_node("EquipmentPanel") as Panel
    if not weapon_panel.visible or weapon_panel.get_node_or_null("PoEInventory/Backpack/ItemGrid/Weapon_1") == null:
        _fail("PoE grid weapon inventory missing")
        return
    ui.call("_toggle_equipment_panel")
    game.call("_damage_player", 10000.0)
    await process_frame
    if player.global_position.distance_to(spawn) > 0.25:
        _fail("Death no longer respawns at south camp")
        return
    _done = true
    print("RIFTFORGED_V2_SMOKE_OK region/terrain/19-enemies/9-archetypes/armor-sockets/loot/poe-hotbar")
    quit(0)
