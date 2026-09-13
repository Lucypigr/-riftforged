extends SceneTree

const FONT_PATH := "res://fonts/NotoSansTC-Riftforged.ttf"
const REQUIRED_GLYPHS := ["攻", "擊", "寶", "石", "裂", "隙", "獸", "菁", "英", "◆", "◇"]

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
    if imported_font == null:
        _fail("Godot could not load the imported Traditional Chinese FontFile")
        return
    if imported_font.data.is_empty():
        _fail("Imported Traditional Chinese FontFile has no embedded source data")
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

    for path in ["Player", "Enemies", "Projectiles", "Ground", "MobileUI"]:
        if scene.get_node_or_null(path) == null:
            _fail("Missing required v2 node: %s" % path)
            return

    var player := scene.get_node("Player")
    var camera := player.get_node_or_null("Camera3D") as Camera3D
    if camera == null or camera.projection != Camera3D.PROJECTION_ORTHOGONAL:
        _fail("Clean rebuild camera is not orthographic")
        return
    if camera.keep_aspect != Camera3D.KEEP_WIDTH:
        _fail("Clean rebuild portrait camera must keep width")
        return

    var player_visual := player.get_node_or_null("Visual") as Sprite3D
    if player_visual == null or player_visual.texture == null:
        _fail("Player is not using an upright Sprite3D visual")
        return
    if player.get_node_or_null("Body") != null:
        _fail("Legacy capsule body visual is still present on player")
        return

    var enemies := scene.get_node("Enemies")
    if enemies.get_child_count() < 5:
        _fail("Clean rebuild did not spawn the initial combat pack")
        return

    var ui_root := scene.get_node("MobileUI/Root")
    var attack := ui_root.get_node_or_null("AttackButton") as Button
    var gem := ui_root.get_node_or_null("GemButton") as Button
    var title := ui_root.get_node_or_null("Title") as Label
    var hint := ui_root.get_node_or_null("Hint") as Label
    if attack == null or gem == null or title == null or hint == null:
        _fail("Clean rebuild mobile UI did not mount")
        return
    if attack.text != "攻擊" or gem.text != "寶石" or title.text != "裂隙遠征 · 重製版":
        _fail("Traditional Chinese UI strings changed unexpectedly")
        return
    if not hint.text.contains("WASD") or not hint.text.contains("左鍵射擊"):
        _fail("Desktop keyboard/mouse controls are not documented in the HUD")
        return
    if ui_root.theme == null or ui_root.theme.default_font == null:
        _fail("Clean rebuild UI is not using the shared imported font theme")
        return
    if ui_root.theme.default_font != imported_font:
        _fail("UI theme is not using the cached imported FontFile")
        return

    var first_enemy := enemies.get_child(0)
    var enemy_visual := first_enemy.get_node_or_null("Visual") as Sprite3D
    if enemy_visual == null or enemy_visual.texture == null:
        _fail("Enemy is not using an upright Sprite3D visual")
        return
    var enemy_label := first_enemy.get_node_or_null("NameLabel") as Label3D
    if enemy_label == null or enemy_label.font == null:
        _fail("Enemy Label3D does not use the imported Traditional Chinese font")
        return
    if not enemy_label.text.contains("裂隙獸"):
        _fail("Enemy Traditional Chinese label is missing")
        return

    var runtime_font := scene.call("debug_font") as FontFile
    if runtime_font == null or runtime_font.data.is_empty():
        _fail("Runtime imported Traditional Chinese font is not active")
        return
    for sample in REQUIRED_GLYPHS:
        if not runtime_font.has_char(sample.unicode_at(0)):
            _fail("Runtime font lost required glyph: %s" % sample)
            return

    if int(scene.call("debug_enemy_count")) < 5:
        _fail("Runtime enemy state is incomplete")
        return

    first_enemy.position = Vector3(2.0, 0.0, 0.0)
    scene.call("_attack")
    await process_frame
    if int(scene.call("debug_projectile_count")) < 1:
        _fail("Mobile attack did not spawn a visible projectile")
        return

    await create_timer(0.36).timeout
    await process_frame
    if int(scene.call("debug_projectile_count")) != 0:
        _fail("Projectile did not resolve after travel")
        return
    if enemy_label.text.ends_with("60"):
        _fail("Projectile impact did not damage its target")
        return

    first_enemy.position = Vector3(3.0, 0.0, 0.0)
    var mouse_event := InputEventMouseButton.new()
    mouse_event.button_index = MOUSE_BUTTON_LEFT
    mouse_event.pressed = true
    mouse_event.position = camera.unproject_position(first_enemy.global_position + Vector3(0, 1.0, 0))
    scene.call("_unhandled_input", mouse_event)
    await process_frame
    if int(scene.call("debug_projectile_count")) < 1:
        _fail("Desktop left click did not spawn a projectile toward the cursor")
        return

    await create_timer(0.36).timeout
    await process_frame
    if int(scene.call("debug_projectile_count")) != 0:
        _fail("Desktop mouse projectile did not resolve")
        return
    if not enemy_label.text.ends_with("4"):
        _fail("Desktop left-click shot did not damage the aimed enemy")
        return

    print("RIFTFORGED_V2_SMOKE_OK imported-ttf/sprite-actors/mobile+desktop-projectile-combat ready")
    quit(0)
