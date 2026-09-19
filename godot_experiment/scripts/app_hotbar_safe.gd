extends "res://scripts/app_configurable_hotbar.gd"

# Empty slots keep the shape expected by older V4 inventory/skill readers.
# Newly equipped or re-equipped gems occupy a free shortcut automatically;
# an explicit player clear is remembered until the player assigns it again.
var _manually_cleared_gems: Dictionary = {}

func _synchronize_hotbar() -> void:
    super._synchronize_hotbar()
    if hotbar_assignments.size() != SLOT_COUNT:
        return
    for entry in _available_actions():
        var uid := int((entry.get("gem", {}) as Dictionary).get("uid", 0))
        if uid <= 0 or _manually_cleared_gems.has(uid) or _find_assignment({"kind":"gem", "uid":uid}) >= 0:
            continue
        for slot in range(SLOT_COUNT):
            if hotbar_assignments[slot].is_empty():
                hotbar_assignments[slot] = {"kind":"gem", "uid":uid}
                break

func _choose_hotbar_slot(slot: int) -> void:
    if slot >= 0 and slot < hotbar_assignments.size() and String(_hotbar_selection.get("kind", "")) == "clear":
        var old: Dictionary = hotbar_assignments[slot]
        if String(old.get("kind", "")) == "gem":
            _manually_cleared_gems[int(old.get("uid", 0))] = true
    elif String(_hotbar_selection.get("kind", "")) == "gem":
        _manually_cleared_gems.erase(int(_hotbar_selection.get("uid", 0)))
    super._choose_hotbar_slot(slot)

func _hotbar_entries() -> Array[Dictionary]:
    var entries := super._hotbar_entries()
    for i in range(entries.size()):
        if entries[i].is_empty():
            entries[i] = {"kind":"empty", "gem":{}, "info":{}}
    return entries

func _use_skill(slot: int) -> void:
    if slot >= 0 and slot < SLOT_COUNT:
        var entry := _hotbar_entries()[slot]
        if String(entry.get("kind", "")) == "empty":
            if not _inventory_open() and ui != null:
                ui.set_hint("快捷欄 %d 尚未配置；請到背包 → 快捷欄指定動作。" % (slot + 1))
            return
    super._use_skill(slot)
