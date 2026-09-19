extends "res://scripts/app_camp.gd"

# Pre-CAMP suites opt in to the REAL portal transition via an explicit CLI
# flag. Normal PC/Web/mobile startup supplies no flag and always begins in
# camp. CAMP-01 smoke deliberately runs with no fixture flag.
func _ready() -> void:
    super._ready()
    var legacy_fixture := OS.get_cmdline_user_args().has("--camp01-legacy-combat") or OS.get_cmdline_args().has("--camp01-legacy-combat")
    if legacy_fixture and player != null and _region_state == STATE_CAMP:
        player.global_position = PORTAL_POSITION + Vector3(0.0, 0.0, 1.5)
        _interact_portal()
        print("CAMP01_LEGACY_ARENA_FIXTURE portal=", _portal_uses, " state=", _region_state)
