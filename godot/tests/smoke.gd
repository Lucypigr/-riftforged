extends SceneTree

const WebTextFallback = preload("res://scripts/web_text_fallback.gd")

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    var packed := load("res://main.tscn") as PackedScene
    if packed == null:
        push_error("Unable to load main.tscn")
        quit(1)
        return

    var scene := packed.instantiate()
    root.add_child(scene)
    await process_frame
    await process_frame

    var required := ["Player", "Enemies", "Loot", "MobileUI", "Ground"]
    for path in required:
        if scene.get_node_or_null(path) == null:
            push_error("Missing required node: %s" % path)
            quit(1)
            return

    var player_node = scene.get_node("Player")
    var camera_node = player_node.get_node_or_null("Camera3D") as Camera3D
    if camera_node == null or camera_node.projection != Camera3D.PROJECTION_ORTHOGONAL:
        push_error("Prototype camera is not orthographic")
        quit(1)
        return
    if camera_node.keep_aspect != Camera3D.KEEP_WIDTH:
        push_error("Portrait camera must use KEEP_WIDTH")
        quit(1)
        return

    var enemies_node := scene.get_node("Enemies")
    if enemies_node.get_child_count() < 5:
        push_error("Expected an initial combat pack")
        quit(1)
        return

    var ui := scene.get_node("MobileUI")
    if ui.get_node_or_null("GemButton") == null or ui.get_node_or_null("GemPanel") == null:
        push_error("Gem UI did not mount")
        quit(1)
        return

    var before: Dictionary = scene.call("debug_build_profile")
    if int(before.get("chain", -1)) != 0:
        push_error("Starter build unexpectedly has chain")
        quit(1)
        return

    scene.call("debug_install_gem", "verdant_chain", 1)
    var after: Dictionary = scene.call("debug_build_profile")
    if int(after.get("chain", 0)) != 1:
        push_error("Linked chain support did not modify the active gem")
        quit(1)
        return
    if String(after.get("active_id", "")) != "crimson_bolt":
        push_error("Starter active gem changed unexpectedly")
        quit(1)
        return

    var ascii_attack := WebTextFallback.sanitize_text("攻擊")
    var ascii_gem := WebTextFallback.sanitize_text("翠綠連鎖")
    var ascii_hud := WebTextFallback.sanitize_text("生命 100/100   擊殺 3")
    if ascii_attack != "ATTACK" or ascii_gem != "Verdant Chain" or ascii_hud != "HP 100/100   KILLS 3":
        push_error("Web ASCII text fallback failed")
        quit(1)
        return

    for sample in [ascii_attack, ascii_gem, ascii_hud]:
        for index in range(sample.length()):
            if sample.unicode_at(index) > 126:
                push_error("Web text fallback still contains non-ASCII glyphs")
                quit(1)
                return

    print("GODOT_SMOKE_OK player/enemies/loot/ui/camera/gem-link/web-text ready")
    quit(0)
