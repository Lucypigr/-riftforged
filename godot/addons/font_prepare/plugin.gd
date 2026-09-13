@tool
extends EditorPlugin

const GENERATED_FONT := "res://fonts/NotoSansTC-Riftforged.ttf"
const PREPARE_SCRIPT := "res://tools/prepare_tc_font.py"

func _enter_tree() -> void:
    if FileAccess.file_exists(GENERATED_FONT):
        return

    var script_path := ProjectSettings.globalize_path(PREPARE_SCRIPT)
    var project_path := ProjectSettings.globalize_path("res://")
    var executables := ["python3", "python"]

    for executable in executables:
        var output: Array = []
        var exit_code := OS.execute(
            executable,
            [script_path, "--project", project_path],
            output,
            true
        )
        for line in output:
            print("[font-prepare] ", line)
        if exit_code == 0 and FileAccess.file_exists(GENERATED_FONT):
            print("[font-prepare] Traditional Chinese TrueType font is ready")
            return

    push_error("Unable to prepare the Traditional Chinese TrueType font before import")
