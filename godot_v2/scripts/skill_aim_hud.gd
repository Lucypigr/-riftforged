extends "res://scripts/configurable_hotbar_hud.gd"
class_name RiftSkillAimHUD

signal aim_finished(slot: int, drag_pixels: Vector2)

const DRAG_THRESHOLD := 16.0
const PIXELS_PER_WORLD_UNIT := 22.0

var _aim_modes: Array[Dictionary] = []
var _aim_touch := -1
var _aim_slot := -1
var _aim_start := Vector2.ZERO
var _aim_position := Vector2.ZERO
var _aim_line: Line2D
var _aim_marker: ColorRect
var _aim_cancel: Panel
var _aim_caption: Label

func setup(font: FontFile) -> void:
    super.setup(font)
    # The touch path below owns aiming; GUI's synthetic mouse press cannot
    # additionally cast a skill. Desktop mouse keeps the normal button signal.
    for i in range(skill_buttons.size()):
        for connection in skill_buttons[i].pressed.get_connections():
            skill_buttons[i].pressed.disconnect(connection["callable"])
        skill_buttons[i].pressed.connect(_pointer_skill.bind(i))
    for connection in attack_button.pressed.get_connections():
        attack_button.pressed.disconnect(connection["callable"])
    attack_button.pressed.connect(_pointer_skill.bind(4))
    _aim_line = Line2D.new()
    _aim_line.name = "AimGuide"
    _aim_line.width = 5.0
    _aim_line.default_color = Color(0.24, 0.86, 1.0, 0.93)
    _aim_line.visible = false
    root_control.add_child(_aim_line)
    _aim_marker = ColorRect.new()
    _aim_marker.name = "AimTarget"
    _aim_marker.size = Vector2(20, 20)
    _aim_marker.color = Color(0.24, 0.86, 1.0, 0.8)
    _aim_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _aim_marker.visible = false
    root_control.add_child(_aim_marker)
    _aim_cancel = Panel.new()
    _aim_cancel.name = "AimCancel"
    _aim_cancel.size = Vector2(200, 48)
    _aim_cancel.add_theme_stylebox_override("panel", _round_style(Color(0.61, 0.10, 0.12, 0.90), 18))
    _aim_cancel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _aim_cancel.visible = false
    root_control.add_child(_aim_cancel)
    _aim_caption = Label.new()
    _aim_caption.name = "AimCancelText"
    _aim_caption.text = "拖到此處放開：取消"
    _aim_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _aim_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _aim_caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _aim_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _aim_cancel.add_child(_aim_caption)
    get_viewport().size_changed.connect(_layout_aim_overlay, CONNECT_DEFERRED)
    _layout_aim_overlay()

func _pointer_skill(slot: int) -> void:
    # Existing headless V5 tests inject Button.pressed directly while forcing
    # touch mode. Real touch events never invoke this path twice: their owning
    # _input() event is marked handled, and non-test mobile signals are ignored.
    if not _controls_locked and (not _touch_runtime() or _test_touch_mode):
        skill_requested.emit(slot)

func set_aim_modes(modes: Array[Dictionary]) -> void:
    _aim_modes = modes.duplicate(true)
    if _aim_slot >= 0 and (_aim_slot >= _aim_modes.size() or not RiftSkillAimRules.needs_drag(String(_aim_modes[_aim_slot].get("mode", "none")))):
        cancel_aim()

func _touch_slot(point: Vector2) -> int:
    if attack_button.visible and attack_button.get_global_rect().has_point(point):
        return 4
    for i in range(mini(4, skill_buttons.size())):
        if skill_buttons[i].visible and skill_buttons[i].get_global_rect().has_point(point):
            return i
    return -1

func _input(event: InputEvent) -> void:
    if _controls_locked:
        cancel_aim()
        super._input(event)
        return
    if event is InputEventScreenTouch:
        var touch := event as InputEventScreenTouch
        if touch.pressed and _aim_touch == -1 and touch.index != joystick_touch_id:
            var slot := _touch_slot(touch.position)
            if slot >= 0:
                get_viewport().set_input_as_handled()
                var button := attack_button if slot == 4 and attack_button.visible else skill_buttons[slot]
                if button.disabled:
                    return
                var mode := String(_aim_modes[slot].get("mode", "none")) if slot < _aim_modes.size() else "none"
                if not RiftSkillAimRules.needs_drag(mode):
                    # Legacy test uses a direct pressed.emit() afterward; live
                    # touch owns exactly one press here and never repeats it.
                    if not _test_touch_mode:
                        skill_requested.emit(slot)
                    return
                _aim_touch = touch.index
                _aim_slot = slot
                _aim_start = touch.position
                _aim_position = touch.position
                _aim_cancel.visible = true
                _render_aim()
                return
        elif not touch.pressed and touch.index == _aim_touch and _aim_touch >= 0:
            _aim_position = touch.position
            var cancelled := _aim_cancel.get_global_rect().has_point(_aim_position)
            var slot := _aim_slot
            var drag := _aim_position - _aim_start
            cancel_aim()
            get_viewport().set_input_as_handled()
            if not cancelled:
                aim_finished.emit(slot, drag if drag.length() >= DRAG_THRESHOLD else Vector2.ZERO)
            return
    elif event is InputEventScreenDrag:
        var drag := event as InputEventScreenDrag
        if drag.index == _aim_touch and _aim_touch >= 0:
            _aim_position = drag.position
            _render_aim()
            get_viewport().set_input_as_handled()
            return
    super._input(event)

func _render_aim() -> void:
    if _aim_slot < 0 or _aim_slot >= _aim_modes.size():
        return
    _layout_aim_overlay()
    var spec: Dictionary = _aim_modes[_aim_slot]
    var mode := String(spec.get("mode", "direction"))
    var reach := float(spec.get("range", 0.0))
    var drag := _aim_position - _aim_start
    var direction := drag.normalized() if drag.length() >= DRAG_THRESHOLD else Vector2(1.0, 0.0)
    var visual_length := reach * PIXELS_PER_WORLD_UNIT
    var end := _aim_start + direction * visual_length
    if mode == "point":
        end = _aim_start + drag.limit_length(visual_length)
    _aim_line.points = PackedVector2Array([_aim_start, end])
    _aim_line.visible = true
    _aim_marker.position = end - _aim_marker.size * 0.5
    _aim_marker.visible = true
    _aim_marker.color = Color(0.32, 0.97, 0.61, 0.9) if mode == "point" else Color(0.24, 0.86, 1.0, 0.8)
    _aim_line.default_color = _aim_marker.color

func _layout_aim_overlay() -> void:
    if _aim_cancel == null:
        return
    var size := get_viewport().get_visible_rect().size
    _aim_cancel.position = Vector2((size.x - _aim_cancel.size.x) * 0.5, clampf(size.y * 0.12, 65.0, 120.0))
    if _aim_touch >= 0:
        _aim_cancel.modulate = Color(1.0, 0.53, 0.48) if _aim_cancel.get_global_rect().has_point(_aim_position) else Color.WHITE

func cancel_aim() -> void:
    _aim_touch = -1
    _aim_slot = -1
    if _aim_line != null:
        _aim_line.hide()
    if _aim_marker != null:
        _aim_marker.hide()
    if _aim_cancel != null:
        _aim_cancel.hide()

func set_controls_locked(locked: bool) -> void:
    if locked:
        cancel_aim()
    super.set_controls_locked(locked)

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_EXIT_TREE:
        cancel_aim()

func debug_aim() -> Dictionary:
    return {"touch_id":_aim_touch, "slot":_aim_slot, "guide":_aim_line != null and _aim_line.visible, "cancel":_aim_cancel != null and _aim_cancel.visible, "modes":_aim_modes.duplicate(true)}
