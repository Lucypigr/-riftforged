extends RefCounted
class_name RiftUnifiedBag

# One physical 12 x 5 bag for unequipped weapons and wearables. No overflow pages:
# a ground item is never consumed when its footprint cannot be placed.
const WIDTH := 12
const HEIGHT := 5

static func footprint(item: Dictionary) -> Vector2i:
    match String(item.get("slot", "")):
        "頭部", "頭盔", "鞋子", "鞋": return Vector2i(2, 2)
        "身體", "胸甲", "護甲", "腿部", "護腿", "腿": return Vector2i(2, 3)
        "武器":
            match String(item.get("weapon_type", "bow")):
                "blade": return Vector2i(1, 3)
                "focus": return Vector2i(2, 2)
                _: return Vector2i(2, 3)
    return Vector2i.ZERO

static func pack(weapons: Array[Dictionary], equipped_index: int, armor: Array[Dictionary]) -> Dictionary:
    var entries: Array[Dictionary] = []
    for index in range(weapons.size()):
        if index != equipped_index:
            entries.append({"kind":"weapon", "index":index, "item":weapons[index]})
    for index in range(armor.size()):
        entries.append({"kind":"armor", "index":index, "item":armor[index]})
    var occupied: Array[bool] = []
    occupied.resize(WIDTH * HEIGHT)
    occupied.fill(false)
    var placements: Array[Dictionary] = []
    var overflow: Array[Dictionary] = []
    for entry in entries:
        var dim := footprint(entry["item"] as Dictionary)
        var placed := false
        if dim.x <= 0 or dim.y <= 0 or dim.x > WIDTH or dim.y > HEIGHT:
            overflow.append(entry)
            continue
        for y in range(HEIGHT - dim.y + 1):
            if placed:
                break
            for x in range(WIDTH - dim.x + 1):
                if not _fits(occupied, x, y, dim):
                    continue
                for cy in range(y, y + dim.y):
                    for cx in range(x, x + dim.x):
                        occupied[cy * WIDTH + cx] = true
                placements.append({"kind":entry["kind"], "index":entry["index"], "item":entry["item"], "x":x, "y":y, "w":dim.x, "h":dim.y})
                placed = true
                break
        if not placed:
            overflow.append(entry)
    var used := 0
    for filled in occupied:
        if filled:
            used += 1
    return {"placements":placements, "overflow":overflow, "used":used, "capacity":WIDTH * HEIGHT}

static func fits_after_pickup(weapons: Array[Dictionary], equipped_index: int, armor: Array[Dictionary], item: Dictionary) -> bool:
    var next_weapons := weapons.duplicate(true)
    var next_armor := armor.duplicate(true)
    if String(item.get("slot", "")) == "武器":
        next_weapons.append(item)
    else:
        next_armor.append(item)
    return (pack(next_weapons, equipped_index, next_armor)["overflow"] as Array).is_empty()

static func _fits(occupied: Array[bool], x: int, y: int, size: Vector2i) -> bool:
    for cy in range(y, y + size.y):
        for cx in range(x, x + size.x):
            if occupied[cy * WIDTH + cx]:
                return false
    return true
