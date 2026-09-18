extends SceneTree

const FONT_PATH := "res://fonts/NotoSansTC-Riftforged.ttf"
const LootSystem = preload("res://scripts/loot_system.gd")
const WeaponSkillSystem = preload("res://scripts/weapon_skill_system.gd")
const GemSystem = preload("res://scripts/linked_gem_system.gd")
const REQUIRED_GLYPHS := ["攻", "擊", "寶", "石", "裂", "隙", "獸", "菁", "英", "獵", "犬", "衛", "士", "咒", "徒", "裝", "備", "武", "器", "技", "能", "衝", "刺", "爆", "全", "螢", "幕", "◆", "◇"]

var _finished := false
var _stage_name := "boot"

func _init() -> void:
    call_deferred("_watchdog")
    call_deferred("_run")

func _stage(name: String) -> void:
    _stage_name = name
    print("RIFTFORGED_SMOKE_STAGE ", name)

func _watchdog() -> void:
    await create_timer(16.0).timeout
    if not _finished:
        _fail("Smoke timed out at " + _stage_name)

func _fail(message: String) -> void:
    _finished = true
    push_error("RIFTFORGED_SMOKE_FAIL [%s] %s" % [_stage_name, message])
    quit(1)

func _run() -> void:
    _stage("font")
    var file := FileAccess.open(FONT_PATH, FileAccess.READ)
    if file == null:
        _fail("Traditional Chinese font missing")
        return
    var magic := file.get_buffer(4)
    file.close()
    if magic.size() != 4 or magic[0] != 0 or magic[1] != 1 or magic[2] != 0 or magic[3] != 0:
        _fail("Traditional Chinese font is not TrueType")
        return
    var imported := ResourceLoader.load(FONT_PATH, "FontFile", ResourceLoader.CACHE_MODE_REUSE) as FontFile
    if imported == null or imported.data.is_empty():
        _fail("Imported Chinese FontFile missing")
        return
    imported.allow_system_fallback = false
    for glyph in REQUIRED_GLYPHS:
        if not imported.has_char(glyph.unicode_at(0)):
            _fail("Font missing glyph: " + glyph)
            return

    _stage("scene")
    var packed := load("res://main.tscn") as PackedScene
    if packed == null:
        _fail("Main scene missing")
        return
    var game := packed.instantiate()
    root.add_child(game)
    await process_frame
    await process_frame
    for path in ["Player", "Enemies", "Projectiles", "Loot", "MobileUI", "LinkedGemInventory"]:
        if game.get_node_or_null(path) == null:
            _fail("Missing runtime node: " + path)
            return

    _stage("region")
    var world: Dictionary = game.call("debug_region_state")
    var region := game.get_node_or_null(NodePath(String(world.get("region", "")))) as Node3D
    if region == null or region.get_node_or_null("Ground") == null:
        _fail("Region ground hierarchy missing")
        return
    if float(world.get("south_edge", 0.0)) - float(world.get("north_edge", 0.0)) < 290.0 or float(world.get("half_width", 0.0)) * 2.0 < 60.0:
        _fail("Large playable map dimensions regressed")
        return
    if int(world.get("zones", 0)) != 6 or int(world.get("landmarks", 0)) < 7 or not bool(world.get("region02_exit", false)):
        _fail("Zones, landmarks or north exit missing")
        return

    _stage("terrain_stream")
    if not bool(world.get("terrain_root", false)) or int(world.get("chunk_total", 0)) != 15 or absf(float(world.get("chunk_length", 0.0)) - 20.0) > 0.01:
        _fail("Terrain streaming contract regressed")
        return
    var initial: Dictionary = game.call("debug_streaming_state")
    if int(initial.get("loaded", 0)) < 2 or int(initial.get("loaded", 0)) > 5:
        _fail("Initial chunk budget invalid")
        return
    region.call("update_streaming", Vector3(0, 0, -122))
    var north: Dictionary = game.call("debug_streaming_state")
    if int(north.get("loaded", 0)) > 5 or int(north.get("center", -1)) < 10 or (north.get("active", []) as Array) == (initial.get("active", []) as Array):
        _fail("Terrain streaming did not move north")
        return
    region.call("update_streaming", Vector3(0, 0, 128))

    _stage("perf_desktop")
    var perf: Dictionary = game.call("debug_perf_pass2")
    var pool: Dictionary = perf.get("pool", {})
    if int(perf.get("ai_phases", 0)) != 2 or int(perf.get("loot_cap", 0)) != 24 or int(pool.get("player_projectiles", 0)) < 10 or int(pool.get("enemy_projectiles", 0)) < 10 or int(pool.get("flashes", 0)) < 14:
        _fail("Combat effects pool or performance settings regressed")
        return
    var desktop: Dictionary = game.call("debug_desktop_profile")
    if not bool(desktop.get("enabled", false)) or desktop.get("content_scale_size", Vector2i.ZERO) != Vector2i(1280, 720) or bool(desktop.get("joystick_visible", true)) or bool(desktop.get("attack_button_visible", true)) or not bool(desktop.get("fullscreen_button", false)):
        _fail("Desktop profile regressed")
        return
    var player := game.get_node("Player") as CharacterBody3D
    var spawn: Vector3 = world.get("player_spawn", Vector3.ZERO)
    if player == null or player.global_position.distance_to(spawn) > 0.25:
        _fail("Player south-camp spawn missing")
        return
    var camera := player.get_node_or_null("Camera3D") as Camera3D
    var visual := player.get_node_or_null("Visual") as Sprite3D
    if camera == null or camera.projection != Camera3D.PROJECTION_ORTHOGONAL or camera.keep_aspect != Camera3D.KEEP_HEIGHT or visual == null or visual.texture == null:
        _fail("Player sprite/camera regressed")
        return
    var enemies := game.get_node("Enemies") as Node3D
    if enemies == null or enemies.get_child_count() < 7:
        _fail("Enemy pack missing")
        return
    var archetypes: Array = game.call("debug_archetypes")
    for name in ["rift_stalker", "rift_warden", "rift_hexer", "rift_champion"]:
        if not archetypes.has(name):
            _fail("Enemy archetype missing: " + name)
            return
    var first := enemies.get_child(0) as CharacterBody3D
    var first_label := first.get_node_or_null("NameLabel") as Label3D
    var enemy_visual := first.get_node_or_null("Visual") as Sprite3D
    if first_label == null or first_label.font == null or not first_label.text.contains("裂隙") or enemy_visual == null or enemy_visual.texture == null:
        _fail("Enemy visual/Chinese label missing")
        return

    _stage("ui_inventory")
    var ui_root := game.get_node("MobileUI/Root") as Control
    var ui := game.get_node("MobileUI") as RiftPoEInventoryUI
    var attack := ui_root.get_node_or_null("AttackButton") as Button
    var gem_button := ui_root.get_node_or_null("GemButton") as Button
    var equipment := ui_root.get_node_or_null("EquipmentButton") as Button
    var fullscreen := ui_root.get_node_or_null("FullscreenButton") as Button
    var hint := ui_root.get_node_or_null("Hint") as Label
    if ui == null or attack == null or gem_button == null or equipment == null or fullscreen == null or hint == null or attack.text != "攻擊" or gem_button.text != "寶石" or equipment.text != "裝備" or fullscreen.text != "全螢幕" or attack.visible or ui_root.theme == null or ui_root.theme.default_font != imported:
        _fail("Chinese UI, desktop attack button or imported font regressed")
        return
    if not hint.text.contains("WASD") or not hint.text.contains("1–5") or not hint.text.contains("Q/E"):
        _fail("New skill/flask input help missing")
        return
    var hotbar: Dictionary = game.call("debug_hotbar_state")
    var ids: Array = hotbar.get("ids", [])
    var bag: Dictionary = hotbar.get("inventory", {})
    if ids != ["ember_bolt", "", "", "", ""] or int(bag.get("skill_buttons", 0)) != 5 or not bool(bag.get("grid_ready", false)) or int(bag.get("columns", 0)) != 8:
        _fail("Only socketed active gems should fill five slots and weapon grid must mount")
        return
    for i in range(5):
        var button := ui_root.get_node_or_null("SkillButton%d" % i) as Button
        if button == null or not button.visible or not button.text.contains(str(i + 1)) or (i > 0 and (not button.disabled or button.icon != null)):
            _fail("Inactive skill must display an empty disabled shortcut: %d" % (i + 1))
            return
    if ui_root.get_node_or_null("BasicAttackSlot") == null or not hotbar.get("flasks", []).has("Q"):
        _fail("Left-click basic attack or new flask hotkeys missing")
        return

    _stage("full_map")
    var map_key := InputEventKey.new()
    map_key.keycode = KEY_M
    map_key.pressed = true
    game.call("_unhandled_input", map_key)
    await process_frame
    var map: Dictionary = game.call("debug_map_state")
    if not bool(map.get("open", false)) or not bool(map.get("launcher", false)) or not bool(map.get("screen", false)) or not bool(map.get("player_marker", false)) or (map.get("map_size", Vector2.ZERO) as Vector2).y < 300.0:
        _fail("Full region map failed to open")
        return
    game.call("_unhandled_input", map_key)
    await process_frame
    if bool((game.call("debug_map_state") as Dictionary).get("open", true)):
        _fail("M did not close full map")
        return

    _stage("basic_attack")
    first.global_position = player.global_position + Vector3(2, 0, 0)
    var old_text := first_label.text
    game.call("_attack")
    await process_frame
    if int(game.call("debug_projectile_count")) < 1:
        _fail("Basic attack did not fire a pooled projectile")
        return
    await create_timer(0.36).timeout
    await process_frame
    if is_instance_valid(first_label) and first_label.text == old_text:
        _fail("Basic attack neither damaged nor defeated target")
        return
    _stage("mouse_attack")
    var target := enemies.get_child(0) as CharacterBody3D
    if target == first and enemies.get_child_count() > 1:
        target = enemies.get_child(1) as CharacterBody3D
    var target_label := target.get_node_or_null("NameLabel") as Label3D
    if target_label == null:
        _fail("Mouse target missing")
        return
    target.global_position = player.global_position + Vector3(3, 0, 0)
    var old_mouse_text := target_label.text
    var mouse := InputEventMouseButton.new()
    mouse.button_index = MOUSE_BUTTON_LEFT
    mouse.pressed = true
    mouse.position = camera.unproject_position(target.global_position + Vector3(0, 1, 0))
    game.call("_unhandled_input", mouse)
    await process_frame
    mouse.pressed = false
    game.call("_unhandled_input", mouse)
    if int(game.call("debug_projectile_count")) < 1:
        _fail("Left mouse button failed to fire basic attack")
        return
    await create_timer(0.36).timeout
    await process_frame
    if is_instance_valid(target_label) and target_label.text == old_mouse_text:
        _fail("Mouse attack neither damaged nor defeated target")
        return

    _stage("active_skills")
    var skill_enemy := enemies.get_child(0) as CharacterBody3D
    skill_enemy.global_position = player.global_position + Vector3(3, 0, 0)
    var empty_mana := float((game.call("debug_resource_state") as Dictionary).get("mana", 0.0))
    var empty_position := player.global_position
    game.call("_use_skill", 2)
    if absf(float((game.call("debug_resource_state") as Dictionary).get("mana", 0.0)) - empty_mana) > 0.001 or empty_position.distance_to(player.global_position) > 0.01 or float((game.call("debug_skill_cooldowns") as Array)[2]) > 0.01:
        _fail("Empty slot incorrectly granted free dash or spent mana")
        return
    game.call("_use_skill", 0)
    await process_frame
    var cds: Array = game.call("debug_skill_cooldowns")
    if cds.size() != 5 or float(cds[0]) <= 0.0 or int(game.call("debug_projectile_count")) < 1:
        _fail("Installed fireball did not fire or enter cooldown")
        return
    var before_tick := float(cds[0])
    skill_enemy.global_position = spawn + Vector3(20, 0, 0)
    await create_timer(0.16).timeout
    await process_frame
    if float((game.call("debug_skill_cooldowns") as Array)[0]) >= before_tick - 0.05:
        _fail("Skill cooldown stopped ticking")
        return
    game.call("debug_set_mana", 20.0)
    var before_regen := float((game.call("debug_resource_state") as Dictionary).get("mana", 0.0))
    await create_timer(0.16).timeout
    await process_frame
    if float((game.call("debug_resource_state") as Dictionary).get("mana", 0.0)) <= before_regen + 0.5:
        _fail("Mana regeneration stopped")
        return

    _stage("installed_dash")
    var starter_weapon: Dictionary = game.call("debug_weapon_state")
    var modified := starter_weapon.duplicate(true)
    var sockets: Array = modified.get("sockets", [])
    sockets.append({"color":"red", "gem":GemSystem.make_gem("crimson_burst", 790001)})
    sockets.append({"color":"blue", "gem":GemSystem.make_gem("rift_dash", 790002)})
    modified["sockets"] = sockets
    modified["links"] = [true, false, false]
    game.call("_save_weapon", modified)
    var added: Dictionary = game.call("debug_hotbar_state")
    if added.get("ids", []) != ["ember_bolt", "crimson_burst", "rift_dash", "", ""]:
        _fail("Installed active gems did not populate shortcuts in socket order")
        return
    player.global_position = spawn
    player.velocity = Vector3.ZERO
    game.set("last_aim_direction", Vector3(0, 0, -1))
    var dash_start := player.global_position
    game.call("_use_skill", 2)
    await process_frame
    if dash_start.distance_to(player.global_position) < 4.0:
        _fail("Socketed dash did not move the player")
        return
    game.call("_save_weapon", starter_weapon)
    game.call("_damage_player", 10000.0)
    await process_frame
    if player.global_position.distance_to(spawn) > 0.25:
        _fail("Death did not respawn at south camp")
        return

    _stage("equipment")
    game.call("debug_add_test_weapon", "blade")
    if int(game.call("debug_weapon_inventory_count")) < 2:
        _fail("Picked weapon missing from inventory")
        return
    ui.call("_toggle_equipment_panel")
    var panel := ui_root.get_node_or_null("EquipmentPanel") as Panel
    var grid := panel.get_node_or_null("PoEInventory/Backpack/ItemGrid") as Control
    if panel == null or not panel.visible or grid == null or grid.get_node_or_null("Weapon_1") == null:
        _fail("Grid backpack did not show unequipped weapon")
        return
    ui.call("_toggle_equipment_panel")
    game.call("_equip_weapon_index", 1)
    var blade: Dictionary = game.call("debug_weapon_state")
    if String(blade.get("weapon_type", "")) != "blade" or not blade.has("sockets") or int((game.call("debug_hotbar_state") as Dictionary).get("active", 99)) != 0:
        _fail("Empty blade incorrectly inherits free combat skills")
        return
    var starter := WeaponSkillSystem.starter_weapon()
    if float(starter.get("range", 0.0)) < 10.0 or float(starter.get("cooldown", 0.0)) <= 0.0:
        _fail("Weapon stat normalization regressed")
        return

    _stage("loot")
    game.call("debug_force_loot_drop")
    await process_frame
    if int(game.call("debug_loot_count")) < 1:
        _fail("Ground loot failed to spawn")
        return
    var rolled: Array[Dictionary] = LootSystem.roll_master("champion", 4, true, true)
    if rolled.is_empty() or not rolled[0].has("rarity") or not rolled[0].has("prefix") or not rolled[0].has("suffix"):
        _fail("Weighted affix loot record invalid")
        return

    _finished = true
    print("RIFTFORGED_V2_SMOKE_OK region/terrain/combat/poe-inventory/gem-only-five-slots/loot ready")
    quit(0)
