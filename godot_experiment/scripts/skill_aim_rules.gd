extends RefCounted
class_name RiftSkillAimRules

# Fixed ranges mirror the existing executable skill implementations. This is
# cast targeting metadata, not a second gem inventory or drop catalog.
const AIM := {
    "ember_bolt":{"mode":"direction", "range":11.5},
    "crimson_burst":{"mode":"none", "range":4.2},
    "swift_aura":{"mode":"none", "range":0.0},
    "rift_trail":{"mode":"none", "range":0.0},
    "rift_dash":{"mode":"direction", "range":4.6},
    "cleave":{"mode":"melee", "range":3.5},
    "ground_slam":{"mode":"melee", "range":5.5},
    "molten_strike":{"mode":"melee", "range":6.5},
    "burning_arrow":{"mode":"direction", "range":11.5},
    "split_arrow":{"mode":"direction", "range":11.5},
    "ice_shot":{"mode":"direction", "range":11.5},
    "galvanic_arrow":{"mode":"direction", "range":8.0},
    "freezing_pulse":{"mode":"direction", "range":10.0},
    "arc":{"mode":"auto", "range":10.0},
    "frost_nova":{"mode":"none", "range":0.0},
}

static func descriptor(gem: Dictionary) -> Dictionary:
    var id := String(gem.get("id", ""))
    if AIM.has(id):
        return (AIM[id] as Dictionary).duplicate()
    # Future skills can supply aim_mode/max_range in the authoritative gem
    # record. Never silently treat every projectile as homing.
    var info := RiftLinkedGemSystem.data(gem)
    var mode := String(info.get("aim_mode", ""))
    if mode not in ["direction", "point", "melee", "auto", "none"]:
        var tags: Array = info.get("tags", [])
        mode = "direction" if tags.has("projectile") or tags.has("movement") else ("melee" if tags.has("melee") else "none")
    return {"mode":mode, "range":float(info.get("max_range", 0.0))}

static func needs_drag(mode: String) -> bool:
    return mode in ["direction", "point", "melee"]

static func valid_direction(candidate: Vector3, fallback: Vector3) -> Vector3:
    candidate.y = 0.0
    fallback.y = 0.0
    if candidate.length_squared() > 0.0144:
        return candidate.normalized()
    return fallback.normalized() if fallback.length_squared() > 0.0144 else Vector3(1.0, 0.0, 0.0)

static func limit_point(origin: Vector3, target: Vector3, reach: float) -> Vector3:
    var delta := target - origin
    delta.y = 0.0
    return origin + delta.limit_length(maxf(0.0, reach))
