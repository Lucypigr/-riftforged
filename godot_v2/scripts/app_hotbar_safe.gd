extends "res://scripts/app_configurable_hotbar.gd"

# Existing V4 code indexes every action by slot, even if an action has been
# cleared. Keep placeholders structurally compatible with legacy consumers.
var _known_active_uids: Dictionary = {}

func _synchronize_hotbar() -> void:
    super._synchronize_hotbar()
    if hotbar_assignments.size() != SLOT_COUNT:
        return
    var live := _available_actions()
    for entry in live:
        var uid := int((entry.get("gem", {}) as Dictionary).get("uid", 0))
        if uid <= 0:
            continue
        if not _known_active_uids.has(uid) and _find_assignment({"kind":"gem", "uid":uid}) < 0:
            for slot in range(SLOT_COUNT):
                if hotbar_assignments[slot].is_empty():
                    hotbar_assignments[slot] = {"kind":"gem", "uid":uid}
                    break
        _known_active_uids[uid] = true

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
