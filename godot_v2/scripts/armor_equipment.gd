extends RefCounted
class_name RiftArmorEquipment

# Each wearable has independent real opened sockets and connections.
const SLOTS := ["頭部", "身體", "腿部", "鞋子"]
const LIMITS := {"頭部":4, "身體":6, "腿部":4, "鞋子":4}
const BASE_ARMOR := {"頭部":7.0, "身體":14.0, "腿部":9.0, "鞋子":5.0}
const STARTERS := {"頭部":"旅者兜帽", "身體":"旅者皮甲", "腿部":"旅者護腿", "鞋子":"荒徑長靴"}
const FOOTPRINTS := {"頭部":Vector2i(2, 2), "身體":Vector2i(2, 3), "腿部":Vector2i(2, 3), "鞋子":Vector2i(2, 2)}

static func canonical_slot(value: String) -> String:
    match value:
        "護甲", "胸甲", "身體": return "身體"
        "鞋", "鞋子": return "鞋子"
        "腿", "護腿", "腿部": return "腿部"
        "頭盔", "頭部": return "頭部"
    return ""

static func starter(slot: String) -> Dictionary:
    var item := {"id":"starter_" + slot, "slot":slot, "name":String(STARTERS.get(slot, slot)), "rarity":"普通", "level":1, "armor":float(BASE_ARMOR.get(slot, 5.0)), "prefix":{}, "suffix":{}, "max_sockets":int(LIMITS.get(slot, 4))}
    return normalize(item, true)

static func normalize(source: Dictionary, is_starter: bool = false) -> Dictionary:
    var item := source.duplicate(true)
    var slot := canonical_slot(String(item.get("slot", "")))
    if slot.is_empty():
        return {}
    item["slot"] = slot
    item["max_sockets"] = int(LIMITS[slot])
    item["inventory_w"] = int((FOOTPRINTS[slot] as Vector2i).x)
    item["inventory_h"] = int((FOOTPRINTS[slot] as Vector2i).y)
    item["socket_layout_id"] = slot
    if not item.has("armor"):
        item["armor"] = float(BASE_ARMOR[slot]) + float(maxi(0, int(item.get("level", 1)) - 1)) * 0.8
    if not item.has("sockets"):
        var count := 1 if is_starter else randi_range(1, mini(3, int(LIMITS[slot])))
        var sockets: Array[Dictionary] = []
        for i in range(count):
            var color := "red" if is_starter else String(RiftLinkedGemSystem.COLORS[randi_range(0, 2)])
            sockets.append({"color":color, "gem":{}})
        item["sockets"] = sockets
        var links: Array[bool] = []
        for i in range(count - 1):
            links.append(randf() < 0.50)
        item["links"] = links
    if not item.has("links"):
        item["links"] = []
    return item

static func defense(equipped: Dictionary) -> float:
    var total := 0.0
    for slot in SLOTS:
        var item: Dictionary = equipped.get(slot, {})
        total += float(item.get("armor", 0.0))
    return total

static func health_bonus(equipped: Dictionary) -> float:
    var total := 0.0
    for slot in SLOTS:
        var item: Dictionary = equipped.get(slot, {})
        for key in ["prefix", "suffix"]:
            var affix: Dictionary = item.get(key, {})
            if String(affix.get("stat", "")) == "生命":
                total += float(affix.get("value", 0))
    return total
