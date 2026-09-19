extends "res://scripts/linked_gem_ui.gd"
class_name RiftV4GemUI

var _action_interval: Callable

func set_action_interval(calculator: Callable) -> void:
    _action_interval = calculator

func _draw_skill_info() -> void:
    super._draw_skill_info()
    if description == null:
        return
    var sockets: Array = _weapon.get("sockets", [])
    var index := RiftLinkedGemSystem.active_socket(_weapon)
    if _selected >= 0 and _selected < _stash.size():
        var gem: Dictionary = _stash[_selected]
        var data: Dictionary = RiftLinkedGemSystem.data(gem)
        if String(data.get("role", "")) == "attack":
            description.text += "\n基礎魔力消耗：%.1f（實際消耗依裝備連線計算）" % float(data.get("mana", 0.0))
        return
    if index < 0 or index >= sockets.size():
        return
    var gem: Dictionary = (sockets[index] as Dictionary).get("gem", {})
    var info: Dictionary = RiftLinkedGemSystem.data(gem)
    var mana := RiftLinkedGemSystem.skill_mana(_weapon, index)
    if String(info.get("role", "")) != "attack":
        return
    var tags: Array = info.get("tags", [])
    var kind := "攻擊" if tags.has("attack") else ("位移" if tags.has("movement") else "施法")
    description.text += "\n實際魔力：%.1f" % mana
    if _action_interval.is_valid():
        var seconds := float(_action_interval.call(_weapon, index, info))
        if seconds > 0.0:
            description.text += "｜%s動作間隔 %.2f 秒（每秒 %.2f 次）" % [kind, seconds, 1.0 / seconds]
