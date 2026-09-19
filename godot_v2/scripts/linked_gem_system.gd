extends RefCounted
class_name RiftLinkedGemSystem

const MAX_SOCKETS := 6
const COLORS := ["red", "green", "blue"]
# Existing gem names/IDs are intentionally unchanged. New names follow POE1 Traditional Chinese;
# numerical balancing and simplified skills remain original to Riftforged.
const GEMS := {
    "ember_bolt": {"name":"緋紅火球", "color":"red", "role":"attack", "tags":["projectile", "spell"], "base_damage":32.0, "cooldown":2.4, "mana":12.0, "text":"發射火球，命中造成火焰傷害並小範圍爆炸。"},
    "crimson_burst": {"name":"緋紅爆裂", "color":"red", "role":"attack", "tags":["area", "spell"], "base_damage":55.0, "cooldown":4.0, "mana":12.0, "text":"對附近敵人釋放範圍爆炸。"},
    "multishot": {"name":"翠綠多重投射", "color":"green", "role":"support", "tags":["projectile"], "text":"連線並符合投射物標籤時，投射物增加至三發；單發傷害降低。"},
    "chain": {"name":"翠綠連鎖", "color":"green", "role":"support", "tags":["projectile"], "text":"連線並符合投射物標籤時，命中後可跳至另外兩名附近敵人。"},
    "swift_aura": {"name":"湛藍疾行光環", "color":"blue", "role":"aura", "tags":["aura"], "cooldown":0.25, "mana":0.0, "text":"可切換：移動速度提升 20%，造成傷害降低 15%。不必與其他寶石連線。"},
    "rift_trail": {"name":"湛藍裂隙足跡", "color":"blue", "role":"attack", "tags":["area", "movement"], "base_damage":20.0, "cooldown":1.0, "mana":12.0, "text":"啟動後移動時留下短暫裂隙傷害痕跡，再按一次關閉。"},
    "rift_dash": {"name":"湛藍裂隙衝刺", "color":"blue", "role":"attack", "tags":["movement"], "base_damage":0.0, "cooldown":5.0, "mana":16.0, "text":"裝備後可配置至 1–5 技能鍵；向移動或瞄準方向快速位移。"},
    "cleave": {"name":"劈砍", "color":"red", "role":"attack", "v3":true, "tags":["attack", "melee", "area", "physical"], "base_damage":43.0, "cooldown":1.5, "mana":10.0, "text":"向前方扇形劈砍。"},
    "ground_slam": {"name":"裂地之擊", "color":"red", "role":"attack", "v3":true, "tags":["attack", "melee", "area", "physical"], "base_damage":58.0, "cooldown":2.8, "mana":16.0, "text":"向前方打出一道範圍衝擊波。"},
    "molten_strike": {"name":"熔岩之擊", "color":"red", "role":"attack", "v3":true, "tags":["attack", "melee", "projectile", "area", "fire"], "base_damage":37.0, "cooldown":2.4, "mana":14.0, "text":"近距離重擊後散射熔岩彈。"},
    "burning_arrow": {"name":"燃燒箭矢", "color":"green", "role":"attack", "v3":true, "tags":["attack", "bow", "projectile", "fire"], "base_damage":43.0, "cooldown":1.4, "mana":10.0, "text":"射出火焰箭，命中造成灼燒追加傷害。"},
    "split_arrow": {"name":"裂化箭矢", "color":"green", "role":"attack", "v3":true, "tags":["attack", "bow", "projectile", "physical"], "base_damage":29.0, "cooldown":1.8, "mana":13.0, "text":"同時射出數支箭矢攻擊不同敵人。"},
    "ice_shot": {"name":"冰霜射擊", "color":"green", "role":"attack", "v3":true, "tags":["attack", "bow", "projectile", "area", "cold"], "base_damage":35.0, "cooldown":2.0, "mana":14.0, "text":"冰箭命中後造成冰冷範圍傷害與冰緩。"},
    "galvanic_arrow": {"name":"電流箭矢", "color":"green", "role":"attack", "v3":true, "tags":["attack", "bow", "projectile", "area", "lightning"], "base_damage":33.0, "cooldown":2.0, "mana":13.0, "text":"電流箭向前方扇形射擊數個目標。"},
    "freezing_pulse": {"name":"冰霜脈衝", "color":"blue", "role":"attack", "v3":true, "tags":["spell", "projectile", "cold"], "base_damage":44.0, "cooldown":1.9, "mana":14.0, "text":"射出冰霜脈衝，命中冰緩敵人。"},
    "arc": {"name":"電弧", "color":"blue", "role":"attack", "v3":true, "tags":["spell", "lightning", "chain"], "base_damage":42.0, "cooldown":2.5, "mana":19.0, "text":"電弧在附近數個目標之間跳躍。"},
    "frost_nova": {"name":"冰霜新星", "color":"blue", "role":"attack", "v3":true, "tags":["spell", "area", "cold"], "base_damage":41.0, "cooldown":3.0, "mana":18.0, "text":"角色周圍爆發冰霜，造成傷害與冰緩。"},
    "melee_physical_support": {"name":"近戰物理傷害輔助", "color":"red", "role":"support", "tags":["melee"], "text":"連線近戰技能造成更多傷害。"},
    "added_fire_support": {"name":"附加火焰傷害輔助", "color":"red", "role":"support", "tags":["attack"], "text":"連線攻擊附加火焰傷害。"},
    "inspiration_support": {"name":"啟發輔助", "color":"red", "role":"support", "tags":["attack", "spell"], "text":"連線技能傷害稍增，魔力消耗降低。"},
    "pierce_support": {"name":"穿透輔助", "color":"green", "role":"support", "tags":["projectile"], "text":"連線投射物可額外穿透一個目標。"},
    "faster_attacks_support": {"name":"快速攻擊輔助", "color":"green", "role":"support", "tags":["attack"], "text":"連線攻擊縮短冷卻時間。"},
    "faster_projectiles_support": {"name":"快速投射輔助", "color":"green", "role":"support", "tags":["projectile"], "text":"連線投射物飛行速度提升。"},
    "hypothermia_support": {"name":"急凍輔助", "color":"green", "role":"support", "tags":["cold"], "text":"連線冰冷技能對冰緩目標造成更多傷害。"},
    "controlled_destruction_support": {"name":"精準破壞輔助", "color":"blue", "role":"support", "tags":["spell"], "text":"連線法術傷害提高但不能暴擊。"},
    "increased_area_support": {"name":"增加範圍輔助", "color":"blue", "role":"support", "tags":["area"], "text":"連線範圍技能作用半徑提高。"},
    "faster_casting_support": {"name":"快速施放輔助", "color":"blue", "role":"support", "tags":["spell"], "text":"連線法術縮短冷卻時間。"},
}

const BUILDS := {
    "近戰劈砍": ["cleave", "melee_physical_support", "faster_attacks_support"],
    "熔岩近戰": ["molten_strike", "added_fire_support", "inspiration_support"],
    "多箭速刷": ["split_arrow", "pierce_support", "faster_projectiles_support"],
    "冰冷控制": ["ice_shot", "hypothermia_support", "increased_area_support"],
    "閃電法術": ["arc", "controlled_destruction_support", "faster_casting_support"],
}

static func drop_pool() -> Array[String]:
    var ids: Array[String] = []
    for id in GEMS.keys():
        var record: Dictionary = GEMS[id]
        if bool(record.get("drop_enabled", true)) and not bool(record.get("test_only", false)) and not bool(record.get("disabled", false)):
            ids.append(String(id))
    ids.sort()
    return ids

static func gem_drop_chance(elite: bool, boss: bool) -> float:
    return 0.78 if boss else (0.38 if elite else 0.05)

static func roll_drop_id(rng: RandomNumberGenerator) -> String:
    var pool := drop_pool()
    if pool.is_empty():
        return ""
    return pool[rng.randi_range(0, pool.size() - 1)]

static func should_drop(rng: RandomNumberGenerator, elite: bool, boss: bool) -> bool:
    return rng.randf() < gem_drop_chance(elite, boss)

static func make_gem(id: String, uid: int) -> Dictionary:
    var record: Dictionary = GEMS.get(id, {})
    if record.is_empty():
        return {}
    return {"id":id, "uid":uid, "name":String(record["name"]), "color":String(record["color"]), "level":1, "refine":0}

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
    damage *= 1.0 + 0.035 * float(maxi(0, int(gem.get("level", 1)) - 1))
    var supports := support_ids(weapon, active_index)
    if supports.has("multishot"):
        damage *= 0.80
    if supports.has("chain"):
        damage *= 0.85
    if supports.has("melee_physical_support"):
        damage *= 1.32
    if supports.has("added_fire_support"):
        damage *= 1.18
    if supports.has("inspiration_support"):
        damage *= 1.08
    if supports.has("controlled_destruction_support"):
        damage *= 1.35
    return snappedf(damage, 0.1)

static func skill_mana(weapon: Dictionary, active_index: int) -> float:
    var sockets: Array = weapon.get("sockets", [])
    if active_index < 0 or active_index >= sockets.size():
        return 0.0
    var info := data((sockets[active_index] as Dictionary).get("gem", {}))
    var value := float(info.get("mana", 12.0))
    if support_ids(weapon, active_index).has("inspiration_support"):
        value *= 0.78
    return value

static func skill_cooldown(weapon: Dictionary, active_index: int) -> float:
    var sockets: Array = weapon.get("sockets", [])
    if active_index < 0 or active_index >= sockets.size():
        return 0.0
    var info := data((sockets[active_index] as Dictionary).get("gem", {}))
    var value := float(info.get("cooldown", 1.0))
    var supports := support_ids(weapon, active_index)
    if supports.has("faster_attacks_support"):
        value *= 0.80
    if supports.has("faster_casting_support"):
        value *= 0.80
    return value

static func skill_radius(weapon: Dictionary, active_index: int, base_radius: float) -> float:
    return base_radius * (1.30 if support_ids(weapon, active_index).has("increased_area_support") else 1.0)

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
        var new_color: String = String(COLORS[randi_range(0, COLORS.size() - 1)])
        if new_color == old_color:
            new_color = String(COLORS[(COLORS.find(old_color) + 1) % COLORS.size()])
        socket["color"] = new_color
        var gem: Dictionary = socket.get("gem", {})
        if not gem.is_empty() and String(gem.get("color", "")) != new_color:
            removed.append(gem.duplicate(true))
            socket["gem"] = {}
        sockets[i] = socket
    weapon["sockets"] = sockets
    return removed
