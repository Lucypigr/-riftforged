extends "res://scripts/app_configurable_hotbar.gd"

# Legacy V4 refresh and debug expect a gem key on every indexed slot. An
# unassigned action must be structurally safe without becoming a castable gem.
func _hotbar_entries() -> Array[Dictionary]:
    var entries := super._hotbar_entries()
    for i in range(entries.size()):
        if entries[i].is_empty():
            entries[i] = {"kind":"empty", "gem":{}, "info":{}}
    return entries

func _use_skill(slot: int) -> void:
    if slot >= 0 and slot < 5:
        var entry := _hotbar_entries()[slot]
        if String(entry.get("kind", "")) == "empty":
            if not _inventory_open() and ui != null:
                ui.set_hint("快捷欄 %d 尚未配置；請到背包 → 快捷欄指定動作。" % (slot + 1))
            return
    super._use_skill(slot)
