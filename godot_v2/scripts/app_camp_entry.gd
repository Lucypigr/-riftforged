extends "res://scripts/app_camp.gd"

# Existing pre-CAMP regression scripts assume gameplay begins inside the
# encounter. A CI-only, opt-in command-line flag enters via the REAL portal;
# normal desktop/Web/mobile launches never set this flag and begin in camp.
# The CAMP-01 startup regression intentionally runs without the flag.
func _ready() -> void:
    super._ready()
    if OS.has_feature("headless") and OS.get_cmdline_user_args().has("--camp01-legacy-combat"):
        if player != null and _region_state == STATE_CAMP:
            player.global_position = PORTAL_POSITION + Vector3(0.0, 0.0, 1.5)
            _interact_portal()
