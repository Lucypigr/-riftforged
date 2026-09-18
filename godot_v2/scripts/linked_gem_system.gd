extends RefCounted
class_name RiftLinkedGemSystem

# Original Riftforged names and effects; socket colours and linked support rules
# are inspired by the equipment puzzle specified for this project.
const MAX_SOCKETS := 6
const COLORS := ["red", "green", "blue"]
const GEMS := {
    "ember_bolt": {"name":"緋紅火球", "color":"red", "role":"attack", "tags":["projectile", "spell"], "base_damage":32.0, "cooldown":2.4, "mana":12.0, "text":"發射火球，命中造成火焰傷害並小範圍爆炸。"},
    "crimson_burst": {"name":"緋紅爆裂", "color":"red", "role":"attack", "tags":["area", "spell"], "base_damage":55.0, "cooldown":4.0, "mana":12.0, "text":"對附近敵人釋放範圍爆炸。"},
    "multishot": {"name":"翠綠多重投射", "color":"green", "role":"support", "tags":["projectile"], "text":"連線並符合投射物標籤時，投射物增加至三發；單發傷害降低。"},
    "chain": {"name":"翠綠連鎖", "color":"green", "role":"support", "tags":["projectile"], "text":"連線並符合投射物標籤時，命中後可跳至另外兩名附近敵人。"},
    "swift_aura": {"name":"湛藍疾行光環", "color":"blue", "role":"aura", "tags":["aura"], "text":"可切換：移動速度提升 20%，造成傷害降低 15%。不必與其他寶石連線。"},
    "rift_trail": {"name":"湛藍裂隙足跡", "color":"blue", "role":"attack", "tags":["area", "movement"], "base_damage":20.0, "cooldown":1.0, "mana":12.0, "text":"啟動後移動時留下短暫裂隙傷害痕跡，再按一次關閉。"},
}

static func make_gem(id: String, uid: int) -> Dictionary:
    var data: Dictionary = GEMS.get(id, {})
    if data.is_empty():
        return {}
    return {"id":id, "uid":uid, "name":String(data["name"]), "color":String(data["color"]), "level":1, "refine":0}

static func data(gem: Dictionary) -> Dictionary:
    return GEMS.get(String(gem.get("id", "")), {})

static func normalize_weapon_sockets(weapon: Dictionary, starter: bool = false) -> Dictionary:
    var item := weapon.duplicate(true)
    if item.has("sockets") and item.has("links"):
        return item
    var count := 2 if starter else randi_range(1, 4)
    var sockets: Array[Dictionary] = []
    for i in range(count):
        sockets.append({"color":COLORS[i % COLORS.size()] if starter else COLORS[randi_range(0, COLORS.size() - 1)], "gem":{}})
    var links: Array[bool] = []
    for i in range(count - 1):
        links.append(true if starter else randf() < 0.55)
    item["sockets"] = sockets
    item["links"] = links
    return item

static func connected(weapon: Dictionary, from_index: int, to_index: int) -> bool:
    var sockets: Array = weapon.get("sockets", [])
    var links: Array = weapon.get("links", [])
    if from_index < 0 or to_index < 0 or from_index >= sockets.size() or to_index >= sockets.size():
        return false
    if from_index == to_index:
        return true
    for i in range(mini(from_index, to_index), maxi(from_index, to_index)):
        if i >= links.size() or not bool(links[i]):
            return false
    return true

static func support_ids(weapon: Dictionary, active_index: int) -> Array[String]:
    var result: Array[String] = []
    var sockets: Array = weapon.get("sockets", [])
    if active_index < 0 or active_index >= sockets.size():
        return result
    var active: Dictionary = sockets[active_index].get("gem", {})
    var active_data := data(active)
    if String(active_data.get("role", "")) != "attack":
        return result
    var tags: Array = active_data.get("tags", [])
    for i in range(sockets.size()):
        if i == active_index or not connected(weapon, active_index, i):
            continue
        var gem: Dictionary = sockets[i].get("gem", {})
        var gem_data := data(gem)
        if String(gem_data.get("role", "")) != "support":
            continue
        var matches := false
        for tag in gem_data.get("tags", []):
            if tags.has(tag):
                matches = true
        if matches:
            result.append(String(gem["id"]))
    return result

static func active_socket(weapon: Dictionary) -> int:
    var sockets: Array = weapon.get("sockets", [])
    for i in range(sockets.size()):
        var gem: Dictionary = sockets[i].get("gem", {})
        if String(data(gem).get("role", "")) == "attack":
            return i
    return -1

static func has_aura(weapon: Dictionary) -> bool:
    for socket in weapon.get("sockets", []):
        var gem: Dictionary = (socket as Dictionary).get("gem", {})
        if String(data(gem).get("role", "")) == "aura":
            return true
    return false

static func skill_damage(weapon: Dictionary, active_index: int) -> float:
    var sockets: Array = weapon.get("sockets", [])
    if active_index < 0 or active_index >= sockets.size():
        return 0.0
    var gem: Dictionary = sockets[active_index].get("gem", {})
    var info := data(gem)
    var damage := (float(info.get("base_damage", 0.0)) + float(weapon.get("damage", 0.0)) * 0.78) * (1.0 + float(gem.get("refine", 0)) * 0.05)
    var supports := support_ids(weapon, active_index)
    if supports.has("multishot"):
        damage *= 0.80
    if supports.has("chain"):
        damage *= 0.85
    return snappedf(damage, 0.1)

static func add_socket(weapon: Dictionary) -> bool:
    var sockets: Array = weapon.get("sockets", [])
    if sockets.size() >= MAX_SOCKETS:
        return false
    sockets.append({"color":COLORS[randi_range(0, COLORS.size() - 1)], "gem":{}})
    var links: Array = weapon.get("links", [])
    if sockets.size() > 1:
        links.append(false)
    weapon["sockets"] = sockets
    weapon["links"] = links
    return true

static func reroll_links(weapon: Dictionary) -> bool:
    var sockets: Array = weapon.get("sockets", [])
    if sockets.size() < 2:
        return false
    var links: Array[bool] = []
    for i in range(sockets.size() - 1):
        links.append(randf() < 0.68)
    if not links.has(true):
        links[0] = true
    weapon["links"] = links
    return true

static func recolor(weapon: Dictionary) -> Array[Dictionary]:
    var removed: Array[Dictionary] = []
    var sockets: Array = weapon.get("sockets", [])
    for i in range(sockets.size()):
        var socket: Dictionary = sockets[i]
        var old_color := String(socket.get("color", "red"))
        var new_color := COLORS[randi_range(0, COLORS.size() - 1)]
        if new_color == old_color:
            new_color = COLORS[(COLORS.find(old_color) + 1) % COLORS.size()]
        socket["color"] = new_color
        var gem: Dictionary = socket.get("gem", {})
        if not gem.is_empty() and String(gem.get("color", "")) != new_color:
            removed.append(gem.duplicate(true))
            socket["gem"] = {}
        sockets[i] = socket
    weapon["sockets"] = sockets
    return removed
