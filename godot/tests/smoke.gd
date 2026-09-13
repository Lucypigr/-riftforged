extends SceneTree

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

    var required := ["Player", "Enemy", "MobileUI", "Ground"]
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

    print("GODOT_SMOKE_OK player/enemy/ui/camera ready")
    quit(0)
