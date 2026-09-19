extends "res://scripts/app_v5.gd"

const ConfigurableHUD = preload("res://scripts/configurable_hotbar_hud.gd")
const SLOT_COUNT := 5

# Only action identities are stored here; equipment, gems and sockets remain
# in their existing single authoritative inventories.
var hotbar_assignments: Array[Dictionary] = []
var _hotbar_page := false
var _hotbar_tab: Button
var _hotbar_editor: ScrollContainer
var _hotbar_contents: VBoxContainer
var _hotbar_selection: Dictionary = {}

func _build_ui() -> void:
    ui = ConfigurableHUD.new()
    ui.name = "MobileUI"
    add_child(ui)
    ui.setup(ui_font)
    ui.movement_changed.connect(func(value: Vector2): move_input = value)
    ui.attack_requested.connect(_attack)
    var hud := ui as RiftConfigurableHotbarHUD
    hud.skill_requested.connect(_use_skill)
    hud.weapon_equip_requested.connect(_equip_weapon_index)
    hud.fullscreen_requested.connect(_toggle_fullscreen)
    hud.set_desktop_mode(desktop_layout_enabled)
    ui.set_hp(player_hp, player_max_hp)
    _apply_runtime_hint()

func _ready() -> void:
    super._ready()
    if armor_ui == null or ui == null:
        return
    _initialize_hotbar()
    _build_hotbar_editor()
    _refresh_gameplay_ui()
    ui.set_hint("快捷欄 1–5 可自訂：開背包 → 快捷欄，選動作再選欄位；欄位互點交換位置。")

func _basic_entry() -> Dictionary:
    return {"kind":"basic", "gem":{"id":"__basic", "name":"普攻", "uid":0}, "info":{"role":"basic", "mana":0.0}}

func _available_actions() -> Array[Dictionary]:
    var available: Array[Dictionary] = []
    var seen := {}
    var gear: Array[Dictionary] = [equipped_weapon]
    for slot in ArmorSystem.SLOTS:
        if equipped_armor.has(slot):
            gear.append(equipped_armor[slot])
    for item in gear:
        var sockets: Array = item.get("sockets", [])
        for socket_index in range(sockets.size()):
            var gem: Dictionary = (sockets[socket_index] as Dictionary).get("gem", {})
            var info: Dictionary = GemSystem.data(gem)
            var uid := int(gem.get("uid", 0))
            if uid <= 0 or seen.has(uid) or String(info.get("role", "")) not in ["attack", "aura"]:
                continue
            seen[uid] = true
            available.append({"kind":"gem", "socket_index":socket_index, "gem":gem.duplicate(true), "info":info, "equipment":item.duplicate(true)})
    return available

func _initialize_hotbar() -> void:
    if not hotbar_assignments.is_empty():
        return
    var available := _available_actions()
    for i in range(SLOT_COUNT - 1):
        if i < available.size():
            hotbar_assignments.append({"kind":"gem", "uid":int((available[i]["gem"] as Dictionary).get("uid", 0))})
        else:
            hotbar_assignments.append({})
    hotbar_assignments.append({"kind":"basic"})

func _synchronize_hotbar() -> void:
    if hotbar_assignments.size() != SLOT_COUNT:
        return
    var live := {}
    for entry in _available_actions():
        live[int((entry["gem"] as Dictionary).get("uid", 0))] = true
    var assigned := {}
    for i in range(SLOT_COUNT):
        var action: Dictionary = hotbar_assignments[i]
        var kind := String(action.get("kind", ""))
        if kind == "gem":
            var uid := int(action.get("uid", 0))
            if not live.has(uid) or assigned.has(uid):
                hotbar_assignments[i] = {}
            else:
                assigned[uid] = true
        elif kind != "basic":
            hotbar_assignments[i] = {}

func _hotbar_entries() -> Array[Dictionary]:
    var available := _available_actions()
    var by_uid := {}
    for entry in available:
        by_uid[int((entry["gem"] as Dictionary).get("uid", 0))] = entry
    var assignments := hotbar_assignments
    if assignments.size() != SLOT_COUNT:
        assignments = []
        for i in range(SLOT_COUNT - 1):
            assignments.append({"kind":"gem", "uid":int((available[i]["gem"] as Dictionary).get("uid", 0))} if i < available.size() else {})
        assignments.append({"kind":"basic"})
    var result: Array[Dictionary] = []
    for action in assignments:
        var kind := String((action as Dictionary).get("kind", ""))
        if kind == "basic":
            result.append(_basic_entry())
        elif kind == "gem":
            result.append((by_uid.get(int((action as Dictionary).get("uid", 0)), {}) as Dictionary).duplicate(true))
        else:
            result.append({})
    return result

func _refresh_gameplay_ui() -> void:
    _synchronize_hotbar()
    super._refresh_gameplay_ui()
    if _hotbar_editor != null:
        _render_hotbar_editor()

func _use_skill(slot: int) -> void:
    if slot < 0 or slot >= SLOT_COUNT or _inventory_open():
        return
    var entry := _hotbar_entries()[slot]
    if String(entry.get("kind", "")) == "basic":
        _attack()
        return
    if entry.is_empty():
        ui.set_hint("快捷欄 %d 尚未配置；請到背包內的快捷欄指定技能。" % (slot + 1))
        return
    super._use_skill(slot)

func _build_hotbar_editor() -> void:
    var panel := armor_ui.panel
    _hotbar_tab = Button.new()
    _hotbar_tab.name = "HotbarTab"
    _hotbar_tab.text = "快捷欄 1–5"
    _hotbar_tab.focus_mode = Control.FOCUS_NONE
    _hotbar_tab.pressed.connect(func(): _show_hotbar_page(true))
    panel.add_child(_hotbar_tab)
    _hotbar_editor = ScrollContainer.new()
    _hotbar_editor.name = "HotbarEditor"
    _hotbar_editor.mouse_filter = Control.MOUSE_FILTER_STOP
    _hotbar_editor.visible = false
    panel.add_child(_hotbar_editor)
    _hotbar_contents = VBoxContainer.new()
    _hotbar_contents.name = "HotbarContent"
    _hotbar_contents.add_theme_constant_override("separation", 7)
    _hotbar_editor.add_child(_hotbar_contents)
    var gear_tab := panel.get_node("GearTab") as Button
    var gem_tab := panel.get_node("GemTab") as Button
    gear_tab.pressed.connect(func(): _show_hotbar_page(false))
    gem_tab.pressed.connect(func(): _show_hotbar_page(false))
    get_viewport().size_changed.connect(_layout_hotbar_editor, CONNECT_DEFERRED)
    _layout_hotbar_editor()
    _render_hotbar_editor()

func _layout_hotbar_editor() -> void:
    if _hotbar_editor == null or armor_ui == null or not is_instance_valid(armor_ui):
        return
    var panel := armor_ui.panel
    var width := maxf(65.0, (panel.size.x - 40.0) / 3.0)
    var gear_tab := panel.get_node_or_null("GearTab") as Button
    var gem_tab := panel.get_node_or_null("GemTab") as Button
    if gear_tab != null and gem_tab != null:
        gear_tab.position = Vector2(10.0, 44.0)
        gear_tab.size = Vector2(width, 32.0)
        gear_tab.text = "裝備"
        gem_tab.position = Vector2(16.0 + width, 44.0)
        gem_tab.size = Vector2(width, 32.0)
        gem_tab.text = "寶石／孔洞"
    _hotbar_tab.position = Vector2(22.0 + width * 2.0, 44.0)
    _hotbar_tab.size = Vector2(width, 32.0)
    _hotbar_editor.position = Vector2(8.0, 80.0)
    _hotbar_editor.size = Vector2(maxf(140.0, panel.size.x - 16.0), maxf(90.0, panel.size.y - 89.0))
    _hotbar_contents.custom_minimum_size.x = maxf(130.0, _hotbar_editor.size.x - 20.0)

func _show_hotbar_page(enabled: bool) -> void:
    if _hotbar_editor == null or armor_ui == null:
        return
    _hotbar_page = enabled
    if enabled:
        if gem_ui != null and gem_ui.is_open():
            gem_ui.close()
        (armor_ui as RiftV5EquipmentUI).show_gem_page(false)
    var panel := armor_ui.panel
    for name in ["GearScroll", "BagScroll"]:
        var section := panel.get_node_or_null(name) as Control
        if section != null:
            section.visible = not enabled and not (armor_ui as RiftV5EquipmentUI)._gem_page
    _hotbar_editor.visible = enabled and armor_ui.is_open()
    _hotbar_tab.disabled = enabled
    if enabled:
        _hotbar_selection.clear()
        _layout_hotbar_editor()
        _render_hotbar_editor()

func _open_armor_ui() -> void:
    _show_hotbar_page(false)
    super._open_armor_ui()
    _layout_hotbar_editor()

func _open_gem_ui() -> void:
    _show_hotbar_page(false)
    super._open_gem_ui()

func _open_equipment_sockets(slot: String) -> void:
    _show_hotbar_page(false)
    super._open_equipment_sockets(slot)

func _on_equipment_closed() -> void:
    _show_hotbar_page(false)
    _hotbar_selection.clear()
    super._on_equipment_closed()

func _find_assignment(action: Dictionary) -> int:
    for i in range(hotbar_assignments.size()):
        var existing: Dictionary = hotbar_assignments[i]
        if String(existing.get("kind", "")) != String(action.get("kind", "")):
            continue
        if String(action.get("kind", "")) == "basic" or int(existing.get("uid", -1)) == int(action.get("uid", -2)):
            return i
    return -1

func _pick_hotbar_source(kind: String, uid: int = 0) -> void:
    _hotbar_selection = {"kind":kind, "uid":uid}
    _render_hotbar_editor()

func _choose_hotbar_slot(slot: int) -> void:
    if slot < 0 or slot >= SLOT_COUNT:
        return
    if _hotbar_selection.is_empty():
        _hotbar_selection = {"kind":"slot", "slot":slot}
        _render_hotbar_editor()
        return
    var selection := _hotbar_selection.duplicate()
    _hotbar_selection.clear()
    if String(selection.get("kind", "")) == "slot":
        var other := int(selection.get("slot", -1))
        if other >= 0 and other < SLOT_COUNT and other != slot:
            var before := hotbar_assignments[slot].duplicate(true)
            hotbar_assignments[slot] = hotbar_assignments[other].duplicate(true)
            hotbar_assignments[other] = before
    else:
        var chosen: Dictionary = {} if String(selection.get("kind", "")) == "clear" else {"kind":String(selection["kind"])}
        if String(selection.get("kind", "")) == "gem":
            chosen["uid"] = int(selection.get("uid", 0))
        var previous_slot := _find_assignment(chosen) if not chosen.is_empty() else -1
        if previous_slot >= 0 and previous_slot != slot:
            hotbar_assignments[previous_slot] = hotbar_assignments[slot].duplicate(true)
        hotbar_assignments[slot] = chosen
    _synchronize_hotbar()
    _refresh_gameplay_ui()
    ui.set_hint("快捷欄位置已更新。PC 按 1–5；手機右下大按鈕對應第 5 欄。")

func _render_hotbar_editor() -> void:
    if _hotbar_contents == null:
        return
    for child in _hotbar_contents.get_children():
        _hotbar_contents.remove_child(child)
        child.queue_free()
    var instruction := Label.new()
    instruction.text = "先點下方動作，再點 1–5 欄配置；先點一欄再點另一欄可交換位置。"
    instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _hotbar_contents.add_child(instruction)
    var entries := _hotbar_entries()
    for i in range(SLOT_COUNT):
        var entry: Dictionary = entries[i]
        var is_source := String(_hotbar_selection.get("kind", "")) == "slot" and int(_hotbar_selection.get("slot", -1)) == i
        var button := Button.new()
        button.name = "HotbarSlot%d" % (i + 1)
        button.text = "%s%d｜%s" % ["▶ " if is_source else "", i + 1, "普攻" if String(entry.get("kind", "")) == "basic" else String((entry.get("gem", {}) as Dictionary).get("name", "空欄"))]
        button.custom_minimum_size.y = 48.0
        button.focus_mode = Control.FOCUS_NONE
        button.pressed.connect(_choose_hotbar_slot.bind(i))
        _hotbar_contents.add_child(button)
    var title := Label.new()
    title.text = "可配置動作：從已穿戴裝備的主動寶石取得，輔助寶石不會出現。"
    title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _hotbar_contents.add_child(title)
    var basic := Button.new()
    basic.name = "AssignBasic"
    basic.text = "▶ 普攻" if String(_hotbar_selection.get("kind", "")) == "basic" else "普攻（不消耗魔力）"
    basic.custom_minimum_size.y = 46.0
    basic.pressed.connect(_pick_hotbar_source.bind("basic", 0))
    _hotbar_contents.add_child(basic)
    for entry in _available_actions():
        var gem: Dictionary = entry["gem"]
        var button := Button.new()
        var uid := int(gem.get("uid", 0))
        button.text = "%s◆ %s" % ["▶ " if String(_hotbar_selection.get("kind", "")) == "gem" and int(_hotbar_selection.get("uid", -1)) == uid else "", String(gem.get("name", "技能"))]
        button.custom_minimum_size.y = 46.0
        button.focus_mode = Control.FOCUS_NONE
        button.pressed.connect(_pick_hotbar_source.bind("gem", uid))
        _hotbar_contents.add_child(button)
    var clear := Button.new()
    clear.name = "ClearAction"
    clear.text = "清空指定欄位"
    clear.custom_minimum_size.y = 46.0
    clear.pressed.connect(_pick_hotbar_source.bind("clear", 0))
    _hotbar_contents.add_child(clear)

func debug_configurable_hotbar() -> Dictionary:
    return {"assignments":hotbar_assignments.duplicate(true), "entries":_hotbar_entries(), "editor":_hotbar_editor != null, "page":_hotbar_page, "primary":(ui as RiftConfigurableHotbarHUD).debug_primary_slot() if ui is RiftConfigurableHotbarHUD else {}}
