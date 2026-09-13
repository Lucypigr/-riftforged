extends "res://scripts/app_gameplay.gd"

const DesktopGameplayUIScript = preload("res://scripts/desktop_gameplay_ui.gd")
const DESKTOP_BASE_SIZE := Vector2i(1280, 720)

var desktop_layout_enabled := false

func _enter_tree() -> void:
    desktop_layout_enabled = _is_desktop_runtime()
    if desktop_layout_enabled:
        _apply_desktop_window_profile()

func _ready() -> void:
    super._ready()
    if desktop_layout_enabled and camera != null:
        camera.keep_aspect = Camera3D.KEEP_HEIGHT
        camera.size = 16.8
        camera.position = Vector3(0.0, 11.2, 12.4)
    var gameplay_ui := ui as RiftDesktopGameplayUI
    if gameplay_ui != null:
        gameplay_ui.set_desktop_mode(desktop_layout_enabled)
    _refresh_gameplay_ui()

func _build_ui() -> void:
    ui = DesktopGameplayUIScript.new()
    ui.name = "MobileUI"
    add_child(ui)
    ui.setup(ui_font)
    ui.movement_changed.connect(func(value: Vector2): move_input = value)
    ui.attack_requested.connect(_attack)
    var gameplay_ui := ui as RiftDesktopGameplayUI
    gameplay_ui.skill_requested.connect(_use_skill)
    gameplay_ui.weapon_equip_requested.connect(_equip_weapon_index)
    gameplay_ui.fullscreen_requested.connect(_toggle_fullscreen)
    gameplay_ui.set_desktop_mode(desktop_layout_enabled)
    ui.set_hp(player_hp, player_max_hp)
    if desktop_layout_enabled:
        ui.set_hint("WASD 移動｜按住左鍵射擊｜1/2/3 技能｜右上可切換全螢幕")
    else:
        ui.set_hint("手機：搖桿＋攻擊／技能｜拾取武器可直接換裝")

func _unhandled_input(event: InputEvent) -> void:
    if desktop_layout_enabled and event is InputEventKey:
        var key := event as InputEventKey
        if key.pressed and not key.echo and (key.keycode == KEY_F or key.keycode == KEY_F11):
            _toggle_fullscreen()
            get_viewport().set_input_as_handled()
            return
    super._unhandled_input(event)

func _apply_desktop_window_profile() -> void:
    var window := get_window()
    window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
    window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
    window.content_scale_size = DESKTOP_BASE_SIZE
    if not OS.has_feature("web") and not OS.has_feature("headless"):
        DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _toggle_fullscreen() -> void:
    var mode := DisplayServer.window_get_mode()
    var is_fullscreen := mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
    DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if is_fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)

func _is_desktop_runtime() -> bool:
    if OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios"):
        return false
    if OS.has_feature("web_android") or OS.has_feature("web_ios"):
        return false
    return true

func debug_desktop_profile() -> Dictionary:
    var gameplay_ui := ui as RiftDesktopGameplayUI
    return {
        "enabled": desktop_layout_enabled,
        "content_scale_size": get_window().content_scale_size,
        "camera_keep_aspect": camera.keep_aspect if camera != null else -1,
        "joystick_visible": gameplay_ui.joystick_back.visible if gameplay_ui != null and gameplay_ui.joystick_back != null else true,
        "attack_button_visible": gameplay_ui.attack_button.visible if gameplay_ui != null and gameplay_ui.attack_button != null else true,
        "fullscreen_button": gameplay_ui.fullscreen_button != null if gameplay_ui != null else false,
    }
