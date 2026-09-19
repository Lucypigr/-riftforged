extends "res://scripts/mobile_landscape_hud.gd"
class_name RiftV4HUD

# The five gem slots show availability, not an obsolete cooldown countdown.
var flask_maximums: Array[int] = [40, 40]
var flask_costs: Array[int] = [10, 10]

func set_flask_config(maximums: Array[int], costs: Array[int]) -> void:
    flask_maximums = maximums.duplicate()
    flask_costs = costs.duplicate()
    set_flask_charges(_flask_charges)

func set_flask_charges(charges: Array[int]) -> void:
    _flask_charges = charges.duplicate()
    for i in range(mini(flask_buttons.size(), charges.size())):
        var cost := flask_costs[i] if i < flask_costs.size() else 1
        var cap := flask_maximums[i] if i < flask_maximums.size() else 1
        flask_buttons[i].text = "%s\n%s %d/%d" % ["Q" if i == 0 else "E", "生命" if i == 0 else "魔力", charges[i], cap]
        flask_buttons[i].tooltip_text = "每次消耗 %d 充能" % cost
        flask_buttons[i].disabled = charges[i] < cost

func set_skill_cooldowns(_cooldowns: Array[float]) -> void:
    for i in range(skill_buttons.size()):
        var active := i < _hotbar.size() and not _hotbar[i].is_empty()
        skill_buttons[i].disabled = not active
        skill_buttons[i].text = "%d\n%s" % [i + 1, _skill_names[i] if active and i < _skill_names.size() else ""]
