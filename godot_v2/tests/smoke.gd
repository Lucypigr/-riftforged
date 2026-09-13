extends SceneTree

const FONT_PATH := "res://fonts/NotoSansTC-Riftforged.ttf"
const LootSystem = preload("res://scripts/loot_system.gd")
const REQUIRED_GLYPHS := ["攻", "擊", "寶", "石", "裂", "隙", "獸", "菁", "英", "獵", "犬", "衛", "士", "咒", "徒", "◆", "◇"]

func _init() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error(message)
    quit(1)

func _run() -> void:
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

    var packed := load("res://main.tscn") as PackedScene
    if packed == null:
        _fail("Unable to load main.tscn")
        return
    var scene := packed.instantiate()
    root.add_child(scene)
    await process_frame
    await process_frame

    for path in ["Player", "Enemies", "Projectiles", "Loot", "Ground", "MobileUI"]:
        if scene.get_node_or_null(path) == null:
            _fail("Missing required runtime node: %s" % path)
            return

    var player := scene.get_node("Player")
    var camera := player.get_node_or_null("Camera3D") as Camera3D
    if camera == null or camera.projection != Camera3D.PROJECTION_ORTHOGONAL or camera.keep_aspect != Camera3D.KEEP_WIDTH:
        _fail("Portrait-safe orthographic camera is not active")
        return
    var player_visual := player.get_node_or_null("Visual") as Sprite3D
    if player_visual == null or player_visual.texture == null:
        _fail("Player Sprite3D visual is missing")
        return

    var enemies := scene.get_node("Enemies")
    if enemies.get_child_count() < 7:
        _fail("Grim-inspired combat pack did not spawn")
        return
    var archetypes: Array = scene.call("debug_archetypes")
    for expected in ["rift_stalker", "rift_warden", "rift_hexer", "rift_champion"]:
        if not archetypes.has(expected):
            _fail("Missing data-driven enemy archetype: %s" % expected)
            return

    var first_enemy := enemies.get_child(0)
    var enemy_visual := first_enemy.get_node_or_null("Visual") as Sprite3D
    var enemy_label := first_enemy.get_node_or_null("NameLabel") as Label3D
    if enemy_visual == null or enemy_visual.texture == null or enemy_label == null or enemy_label.font == null:
        _fail("Enemy visual/Traditional Chinese label is incomplete")
        return
    if not enemy_label.text.contains("裂隙"):
        _fail("Enemy Traditional Chinese archetype name is missing")
        return

    var ui_root := scene.get_node("MobileUI/Root")
    var attack := ui_root.get_node_or_null("AttackButton") as Button
    var gem := ui_root.get_node_or_null("GemButton") as Button
    var hint := ui_root.get_node_or_null("Hint") as Label
    if attack == null or gem == null or hint == null:
        _fail("Mobile/desktop UI did not mount")
        return
    if attack.text != "攻擊" or gem.text != "寶石":
        _fail("Traditional Chinese controls changed unexpectedly")
        return
    if not hint.text.contains("WASD") or not hint.text.contains("按住左鍵"):
        _fail("Desktop hold-to-fire controls are not documented")
        return
    if ui_root.theme == null or ui_root.theme.default_font != imported_font:
        _fail("Shared imported Traditional Chinese theme is not active")
        return

    var before_mobile := enemy_label.text
    first_enemy.position = Vector3(2.0, 0.0, 0.0)
    scene.call("_attack")
    await process_frame
    if int(scene.call("debug_projectile_count")) < 1:
        _fail("Mobile attack did not spawn a visible projectile")
        return
    await create_timer(0.36).timeout
    await process_frame
    if enemy_label.text == before_mobile:
        _fail("Mobile projectile did not damage its target")
        return

    first_enemy.position = Vector3(3.0, 0.0, 0.0)
    var before_mouse := enemy_label.text
    var mouse_event := InputEventMouseButton.new()
    mouse_event.button_index = MOUSE_BUTTON_LEFT
    mouse_event.pressed = true
    mouse_event.position = camera.unproject_position(first_enemy.global_position + Vector3(0, 1.0, 0))
    scene.call("_unhandled_input", mouse_event)
    await process_frame
    var release_event := InputEventMouseButton.new()
    release_event.button_index = MOUSE_BUTTON_LEFT
    release_event.pressed = false
    release_event.position = mouse_event.position
    scene.call("_unhandled_input", release_event)
    if int(scene.call("debug_projectile_count")) < 1:
        _fail("Desktop left click did not spawn a projectile")
        return
    await create_timer(0.36).timeout
    await process_frame
    if enemy_label.text == before_mouse:
        _fail("Desktop cursor-targeted projectile did not damage its target")
        return

    scene.call("debug_force_loot_drop")
    await process_frame
    if int(scene.call("debug_loot_count")) < 1:
        _fail("Hierarchical loot system did not create a ground drop")
        return
    var rolled: Array[Dictionary] = LootSystem.roll_master("champion", 4, true, true)
    if rolled.is_empty() or not rolled[0].has("rarity") or not rolled[0].has("prefix") or not rolled[0].has("suffix"):
        _fail("Dynamic weighted loot/affix record is incomplete")
        return

    print("RIFTFORGED_V2_SMOKE_OK data-driven-archetypes/skills/hierarchical-loot/mobile+desktop ready")
    quit(0)
