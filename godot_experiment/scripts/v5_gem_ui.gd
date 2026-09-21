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

const BuildCatalog = preload("res://scripts/build_catalog.gd")
var build_choice: OptionButton
var build_details: Label
var search_gems: LineEdit

func setup(font: FontFile) -> void:
    super.setup(font)
    var content := panel.get_node("Scroll/Content") as VBoxContainer
    search_gems = LineEdit.new()
    search_gems.name = "GemSearch"
    search_gems.placeholder_text = "搜尋背包寶石名稱"
    search_gems.custom_minimum_size.y = 42
    content.add_child(search_gems)
    content.move_child(search_gems, stash_list.get_index())
    search_gems.text_changed.connect(func(_value: String): _filter_stash())
    build_choice = OptionButton.new()
    build_choice.name = "BuildGuide"
    build_choice.custom_minimum_size.y = 44
    build_choice.add_item("流派搭配指南（不會自動換裝）")
    for title in BuildCatalog.RECIPES:
        build_choice.add_item(title)
    content.add_child(build_choice)
    content.move_child(build_choice, 2)
    build_details = Label.new()
    build_details.name = "BuildDetails"
    build_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    build_details.add_theme_font_size_override("font_size", 14)
    content.add_child(build_details)
    content.move_child(build_details, 3)
    build_choice.item_selected.connect(func(_index: int): _show_build())
    _show_build()

func _render() -> void:
    super._render()
    _filter_stash()
    _show_build()

func _filter_stash() -> void:
    if search_gems == null:
        return
    var query := search_gems.text.strip_edges().to_lower()
    for child in stash_list.get_children():
        if child is Button:
            child.visible = query.is_empty() or child.text.to_lower().contains(query)

func _show_build() -> void:
    if build_choice == null or build_details == null:
        return
    if build_choice.selected <= 0:
        build_details.text = "57 顆寶石 · 23 種參考搭配\n先取得寶石，再裝進同色且互相連線的孔。可跨不同裝備配置多種主動技能。"
        return
    var title := build_choice.get_item_text(build_choice.selected)
    var ids: Array = BuildCatalog.RECIPES[title]
    var lines := PackedStringArray()
    for id in ids:
        var info: Dictionary = RiftLinkedGemSystem.GEMS[id]
        var owned := false
        for gem in _stash:
            owned = owned or String(gem.get("id", "")) == id
        var installed := false
        for socket in _weapon.get("sockets", []):
            installed = installed or String(socket.get("gem", {}).get("id", "")) == id
        lines.append("%s｜%s孔｜%s" % [info.name, {"red":"紅", "green":"綠", "blue":"藍"}[info.color], "目前裝備已安裝" if installed else ("背包持有" if owned else "請檢查其他裝備或探索掉落")])
    lines.append(String(RiftLinkedGemSystem.GEMS[ids[0]].text))
    lines.append("此為簡化原創技能；輔助效果只作用於同一連線群組。")
    build_details.text = "\n".join(lines)
