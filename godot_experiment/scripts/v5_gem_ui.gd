extends "res://scripts/v4_gem_ui.gd"
class_name RiftV5GemUI

# Keep the actual gem/socket/currency controls and their existing signals.
# Only move their visible panel into the real equipment window, as an inner page.
var _embedded := false

func embed(host: Control) -> void:
    if panel == null or host == null:
        return
    if panel.get_parent() != null:
        panel.get_parent().remove_child(panel)
    host.add_child(panel)
    _embedded = true
    root.hide()
    panel.hide()
    var back := panel.get_node_or_null("Close") as Button
    if back != null:
        back.text = "← 返回裝備"
        back.focus_mode = Control.FOCUS_NONE
    _layout()

func _layout() -> void:
    if not _embedded:
        super._layout()
        return
    if panel == null or panel.get_parent() == null:
        return
    var host := panel.get_parent() as Control
    if host == null:
        return
    panel.position = Vector2(9.0, 80.0)
    panel.size = Vector2(maxf(160.0, host.size.x - 18.0), maxf(145.0, host.size.y - 88.0))
    var back := panel.get_node_or_null("Close") as Button
    if back != null:
        back.position = Vector2(10.0, 5.0)
        back.size = Vector2(133.0, 36.0)
    var scroll := panel.get_node_or_null("Scroll") as ScrollContainer
    if scroll != null:
        scroll.position = Vector2(10.0, 47.0)
        scroll.size = Vector2(maxf(120.0, panel.size.x - 20.0), maxf(90.0, panel.size.y - 54.0))
        var content := scroll.get_node_or_null("Content") as VBoxContainer
        if content != null:
            content.custom_minimum_size.x = maxf(110.0, scroll.size.x - 18.0)

func open() -> void:
    if not _embedded:
        super.open()
        return
    _layout()
    panel.show()
    _render()

func close() -> void:
    if not _embedded:
        super.close()
        return
    panel.hide()
    closed.emit()

func is_open() -> bool:
    if not _embedded:
        return super.is_open()
    return panel != null and panel.visible

func debug_embedded() -> Dictionary:
    return {"embedded":_embedded, "parent":panel.get_parent().name if panel != null and panel.get_parent() != null else "", "visible":is_open()}
