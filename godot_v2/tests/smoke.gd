extends SceneTree

const FONT_PATH := "res://fonts/NotoSansTC-Riftforged.ttf"
const LootSystem = preload("res://scripts/loot_system.gd")
const WeaponSkillSystem = preload("res://scripts/weapon_skill_system.gd")
const GemSystem = preload("res://scripts/linked_gem_system.gd")
const REQUIRED_GLYPHS := ["攻", "擊", "寶", "石", "裂", "隙", "獸", "菁", "英", "獵", "犬", "衛", "士", "咒", "徒", "裝", "備", "武", "器", "技", "能", "衝", "刺", "爆", "全", "螢", "幕", "◆", "◇"]

var _finished := false
var _last_stage := "boot"

func _init() -> void:
    call_deferred("_watchdog")
    call_deferred("_run")

func _stage(name: String) -> void:
    _last_stage = name
    print("RIFTFORGED_SMOKE_STAGE ", name)

func _watchdog() -> void:
    await create_timer(14.0).timeout
    if not _finished:
        _fail("Smoke test timed out at stage: %s" % _last_stage)

func _fail(message: String) -> void:
    _finished = true
    push_error(message)
    quit(1)

func _run() -> void:
    _stage("font")
    var file := FileAccess.open(FONT_PATH, FileAccess.READ)
    if file == null:
        _fail("Missing bundled Traditional Chinese TTF")
        return
    var magic := file.get_buffer(4)
    file.close()
    if magic.size() != 4 or magic[0] != 0 or magic[1] != 1 or magic[2] != 0 or magic[3] != 0:
        _fail("Traditional Chinese font is not a TrueType file")
        return
    var imported_resource := ResourceLoader.load(FONT_PATH, "FontFile", ResourceLoader.CACHE_MODE_REUSE)
    var imported_font := imported_resource as FontFile
    if imported_font == null or imported_font.data.is_empty():
        _fail("Godot could not load the imported Traditional Chinese FontFile")
        return
    imported_font.allow_system_fallback = false
    for sample in REQUIRED_GLYPHS:
        if not imported_font.has_char(sample.unicode_at(0)):
            _fail("Imported font missing required glyph: %s" % sample)
            return

    _stage("scene")
    var packed := load("res://main.tscn") as PackedScene
    if packed == null:
        _fail("Unable to load main.tscn")
        return
    var scene := packed.instantiate()
    root.add_child(scene)
    await process_frame
    await process_frame
    for path in ["Player", "Enemies", "Projectiles", "Loot", "MobileUI", "LinkedGemInventory"]:
        if scene.get_node_or_null(path) == null:
            _fail("Missing required runtime node: %s" % path)
            return

    _stage("region")
    if not scene.has_method("debug_region_state"):
        _fail("Large-region runtime contract is missing")
        return
    var region_state: Dictionary = scene.call("debug_region_state")
    var region_name := String(region_state.get("region", ""))
    var region_root := scene.get_node_or_null(NodePath(region_name)) as Node3D
    if region_name.is_empty() or region_root == null or region_root.get_node_or_null("Ground") == null:
        _fail("Large playable region ground hierarchy is incomplete")
        return
    var north_edge := float(region_state.get("north_edge", 0.0))
    var south_edge := float(region_state.get("south_edge", 0.0))
    var half_width := float(region_state.get("half_width", 0.0))
    if south_edge - north_edge < 290.0 or half_width * 2.0 < 60.0:
        _fail("Large playable region dimensions regressed")
        return
    if int(region_state.get("zones", 0)) != 6 or int(region_state.get("landmarks", 0)) < 7 or not bool(region_state.get("region02_exit", false)):
        _fail("Region zones, landmarks, or Region 02 exit regressed")
        return

    _stage("terrain_stream")
    if not bool(region_state.get("terrain_root", false)) or int(region_state.get("chunk_total", 0)) != 15 or absf(float(region_state.get("chunk_length", 0.0)) - 20.0) > 0.01:
        _fail("Seamless terrain streaming contract regressed")
        return
    var initial_stream: Dictionary = scene.call("debug_streaming_state")
    var initial_loaded := int(initial_stream.get("loaded", 0))
    if initial_loaded < 2 or initial_loaded > 5:
        _fail("Initial terrain stream loaded wrong chunk count")
        return
    var initial_active: Array = initial_stream.get("active", [])
    region_root.call("update_streaming", Vector3(0, 0, -122))
    var north_stream: Dictionary = scene.call("debug_streaming_state")
    if int(north_stream.get("loaded", 0)) > 5 or int(north_stream.get("center", -1)) < 10 or (north_stream.get("active", []) as Array) == initial_active:
        _fail("Terrain stream did not move its active window north")
        return
    region_root.call("update_streaming", Vector3(0, 0, 128))

    _stage("perf")
    var perf: Dictionary = scene.call("debug_perf_pass2")
    var pool: Dictionary = perf.get("pool", {})
    if int(perf.get("ai_phases", 0)) != 2 or int(perf.get("loot_cap", 0)) != 24 or int(pool.get("player_projectiles", 0)) < 10 or int(pool.get("enemy_projectiles", 0)) < 10 or int(pool.get("flashes", 0)) < 14:
        _fail("Second performance layer or combat pool regressed")
        return

    _stage("desktop")
    var desktop: Dictionary = scene.call("debug_desktop_profile")
    if not bool(desktop.get("enabled", false)) or desktop.get("content_scale_size", Vector2i.ZERO) != Vector2i(1280, 720):
        _fail("Desktop landscape profile regressed")
        return
    if bool(desktop.get("joystick_visible", true)) or bool(desktop.get("attack_button_visible", true)) or not bool(desktop.get("fullscreen_button", false)):
        _fail("Desktop controls visibility regressed")
        return
    var player := scene.get_node("Player") as CharacterBody3D
    var expected_spawn: Vector3 = region_state.get("player_spawn", Vector3.ZERO)
    if player == null or player.global_position.distance_to(expected_spawn) > 0.25:
        _fail("Player did not spawn at south camp")
        return
    var camera := player.get_node_or_null("Camera3D") as Camera3D
    var player_visual := player.get_node_or_null("Visual") as Sprite3D
    if camera == null or camera.projection != Camera3D.PROJECTION_ORTHOGONAL or camera.keep_aspect != Camera3D.KEEP_HEIGHT or player_visual == null or player_visual.texture == null:
        _fail("Player camera or sprite regressed")
        return
    var enemies := scene.get_node("Enemies") as Node3D
    if enemies == null or enemies.get_child_count() < 7:
        _fail("Combat enemies did not spawn")
        return
    var archetypes: Array = scene.call("debug_archetypes")
    for expected in ["rift_stalker", "rift_warden", "rift_hexer", "rift_champion"]:
        if not archetypes.has(expected):
            _fail("Missing enemy archetype: %s" % expected)
            return
    var first_enemy := enemies.get_child(0) as CharacterBody3D
    var enemy_label := first_enemy.get_node_or_null("NameLabel") as Label3D
    var enemy_visual := first_enemy.get_node_or_null("Visual") as Sprite3D
    if enemy_label == null or enemy_label.font == null or not enemy_label.text.contains("裂隙") or enemy_visual == null or enemy_visual.texture == null:
        _fail("Enemy visual or Traditional Chinese labels regressed")
        return

    _stage("ui")
    var ui_root := scene.get_node("MobileUI/Root") as Control
    var attack := ui_root.get_node_or_null("AttackButton") as Button
    var gem := ui_root.get_node_or_null("GemButton") as Button
    var equipment := ui_root.get_node_or_null("EquipmentButton") as Button
    var fullscreen := ui_root.get_node_or_null("FullscreenButton") as Button
    var skill0 := ui_root.get_node_or_null("SkillButton0") as Button
    var skill1 := ui_root.get_node_or_null("SkillButton1") as Button
    var skill2 := ui_root.get_node_or_null("SkillButton2") as Button
    var hint := ui_root.get_node_or_null("Hint") as Label
    if attack == null or gem == null or equipment == null or fullscreen == null or skill0 == null or skill1 == null or skill2 == null or hint == null:
        _fail("Weapon/skill desktop UI did not mount")
        return
    if attack.text != "攻擊" or gem.text != "寶石" or equipment.text != "裝備" or fullscreen.text != "全螢幕" or attack.visible:
        _fail("Traditional Chinese desktop controls changed")
        return
    if not hint.text.contains("WASD") or not hint.text.contains("1/2/3") or not hint.text.contains("M 全地圖") or ui_root.theme == null or ui_root.theme.default_font != imported_font:
        _fail("Desktop controls help or imported font regressed")
        return

    _stage("full_map")
    var map_key := InputEventKey.new()
    map_key.keycode = KEY_M
    map_key.pressed = true
    scene.call("_unhandled_input", map_key)
    await process_frame
    var map_state: Dictionary = scene.call("debug_map_state")
    if not bool(map_state.get("open", false)) or not bool(map_state.get("launcher", false)) or not bool(map_state.get("screen", false)) or not bool(map_state.get("player_marker", false)) or (map_state.get("map_size", Vector2.ZERO) as Vector2).y < 300.0:
        _fail("Full region map did not open correctly")
        return
    scene.call("_unhandled_input", map_key)
    await process_frame
    if bool((scene.call("debug_map_state") as Dictionary).get("open", true)):
        _fail("Full region map did not close")
        return

    var weapon: Dictionary = scene.call("debug_weapon_state")
    if String(weapon.get("weapon_type", "")) != "bow" or float(weapon.get("damage", 0.0)) <= 0.0 or not skill0.text.contains("緋紅火球"):
        _fail("Starter weapon and installed attack gem did not activate")
        return
    var skill_ids: Array = scene.call("debug_skill_ids")
    if skill_ids != ["weapon_skill", "burst", "rift_dash"]:
        _fail("Playable skill hotkeys regressed")
        return

    _stage("basic_attack")
    var before_mobile := enemy_label.text
    first_enemy.global_position = player.global_position + Vector3(2.0, 0.0, 0.0)
    scene.call("_attack")
    await process_frame
    if int(scene.call("debug_projectile_count")) < 1:
        _fail("Basic attack did not activate a pooled projectile")
        return
    await create_timer(0.36).timeout
    await process_frame
    if is_instance_valid(enemy_label) and enemy_label.text == before_mobile:
        _fail("Basic projectile neither damaged nor defeated target")
        return

    _stage("mouse_attack")
    var mouse_target := enemies.get_child(0) as CharacterBody3D
    if mouse_target == first_enemy and enemies.get_child_count() > 1:
        mouse_target = enemies.get_child(1) as CharacterBody3D
    if mouse_target == null:
        _fail("Fresh mouse attack target missing")
        return
    var mouse_label := mouse_target.get_node_or_null("NameLabel") as Label3D
    if mouse_label == null:
        _fail("Mouse target label missing")
        return
    mouse_target.global_position = player.global_position + Vector3(3.0, 0.0, 0.0)
    var before_mouse := mouse_label.text
    var mouse_event := InputEventMouseButton.new()
    mouse_event.button_index = MOUSE_BUTTON_LEFT
    mouse_event.pressed = true
    mouse_event.position = camera.unproject_position(mouse_target.global_position + Vector3(0, 1.0, 0))
    scene.call("_unhandled_input", mouse_event)
    await process_frame
    var release_event := InputEventMouseButton.new()
    release_event.button_index = MOUSE_BUTTON_LEFT
    release_event.pressed = false
    release_event.position = mouse_event.position
    scene.call("_unhandled_input", release_event)
    if int(scene.call("debug_projectile_count")) < 1:
        _fail("Desktop left click did not activate a pooled projectile")
        return
    await create_timer(0.36).timeout
    await process_frame
    if is_instance_valid(mouse_label) and mouse_label.text == before_mouse:
        _fail("Desktop cursor-targeted projectile neither damaged nor defeated target")
        return

    _stage("skill")
    var skill_enemy := enemies.get_child(0) as CharacterBody3D
    skill_enemy.global_position = player.global_position + Vector3(3.0, 0.0, 0.0)
    scene.call("_use_skill", 0)
    await process_frame
    var cds: Array = scene.call("debug_skill_cooldowns")
    if cds.size() != 3 or float(cds[0]) <= 0.0 or int(scene.call("debug_projectile_count")) < 1:
        _fail("Linked starter fireball failed to cast projectiles or enter cooldown")
        return

    _stage("region_runtime")
    var cooldown_before_tick := float(cds[0])
    skill_enemy.global_position = expected_spawn + Vector3(20.0, 0.0, 0.0)
    await create_timer(0.16).timeout
    await process_frame
    var cooldown_after_tick := float((scene.call("debug_skill_cooldowns") as Array)[0])
    if cooldown_after_tick >= cooldown_before_tick - 0.05:
        _fail("Large region stopped ticking skill cooldowns")
        return
    scene.call("debug_set_mana", 20.0)
    var mana_before := float((scene.call("debug_resource_state") as Dictionary).get("mana", 0.0))
    await create_timer(0.16).timeout
    await process_frame
    var mana_after := float((scene.call("debug_resource_state") as Dictionary).get("mana", 0.0))
    if mana_after <= mana_before + 0.5:
        _fail("Large region stopped regenerating mana")
        return
    player.global_position = expected_spawn
    player.velocity = Vector3.ZERO
    scene.set("last_aim_direction", Vector3(0.0, 0.0, -1.0))
    var dash_start := player.global_position
    scene.call("_use_skill", 2)
    await process_frame
    var dash_end := player.global_position
    if dash_start.distance_to(dash_end) < 4.0 or (absf(dash_start.z) > 18.5 and absf(dash_end.z) <= 18.5):
        _fail("Region dash failed or snapped into old arena bounds")
        return
    scene.call("_damage_player", 10000.0)
    await process_frame
    if player.global_position.distance_to(expected_spawn) > 0.25:
        _fail("Region death did not respawn at south camp")
        return

    _stage("equipment")
    scene.call("debug_add_test_weapon", "blade")
    if int(scene.call("debug_weapon_inventory_count")) < 2:
        _fail("Weapon inventory did not accept test weapon")
        return
    scene.call("_equip_weapon_index", 1)
    var blade: Dictionary = scene.call("debug_weapon_state")
    if String(blade.get("weapon_type", "")) != "blade" or not blade.has("sockets") or not skill0.text.contains("未插技能"):
        _fail("Weapon sockets must define active skills; empty blade cannot inherit fake socket skill")
        return
    var starter := WeaponSkillSystem.starter_weapon()
    if float(starter.get("range", 0.0)) < 10.0 or float(starter.get("cooldown", 0.0)) <= 0.0:
        _fail("Weapon stat normalization failed")
        return

    _stage("loot")
    scene.call("debug_force_loot_drop")
    await process_frame
    if int(scene.call("debug_loot_count")) < 1:
        _fail("Loot system did not create a ground drop")
        return
    var rolled: Array[Dictionary] = LootSystem.roll_master("champion", 4, true, true)
    if rolled.is_empty() or not rolled[0].has("rarity") or not rolled[0].has("prefix") or not rolled[0].has("suffix"):
        _fail("Dynamic weighted loot/affix record incomplete")
        return

    _finished = true
    print("RIFTFORGED_V2_SMOKE_OK desktop/full-map/terrain-stream/linked-gems/weapon/pools/loot ready")
    quit(0)
