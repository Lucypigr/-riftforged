extends RefCounted
class_name RiftGrimData

# Eight distinctive original common enemies and a champion. The existing AI
# executor reads the behavior, range, berserk, projectile and death parameters.
static func enemy_archetype(slot: int, force_elite: bool = false) -> Dictionary:
    if force_elite:
        var champion := _record("rift_champion", "菁英裂隙獸", 165.0, 2.05, 15.0, "melee", 1.1, 0.0, "champion", Color(1.0, 0.72, 0.28), 1.18)
        champion["low_health_trigger"] = 0.34
        champion["berserk_speed"] = 1.38
        champion["dying_burst"] = 9.0
        return champion
    match posmod(slot, 8):
        0:
            return _record("rift_stalker", "裂隙獵犬", 62.0, 2.55, 9.0, "melee", 1.05, 0.0, "beast", Color(0.62, 0.27, 0.76), 0.96)
        1:
            var warden := _record("rift_warden", "裂隙衛士", 98.0, 1.72, 13.0, "melee", 1.12, 0.0, "warden", Color(0.72, 0.35, 0.34), 1.08)
            warden["low_health_trigger"] = 0.38
            warden["berserk_speed"] = 1.32
            return warden
        2:
            var hexer := _record("rift_hexer", "裂隙咒徒", 72.0, 1.58, 8.0, "ranged", 5.8, 12.0, "caster", Color(0.37, 0.60, 0.96), 1.0)
            hexer["skill_delay"] = 2.25
            hexer["skill_chance"] = 0.78
            return hexer
        3:
            var runner := _record("bone_runner", "碎骨疾行者", 43.0, 3.65, 7.0, "melee", 0.92, 0.0, "hunter", Color(0.95, 0.85, 0.61), 0.80)
            runner["low_health_trigger"] = 0.45
            runner["berserk_speed"] = 1.48
            runner["touch_delay"] = 0.56
            return runner
        4:
            var bulwark := _record("rift_bulwark", "裂隙巨盾", 148.0, 1.22, 18.0, "melee", 1.28, 0.0, "warden", Color(0.54, 0.72, 0.67), 1.40)
            bulwark["touch_delay"] = 1.22
            return bulwark
        5:
            var archer := _record("crystal_archer", "結晶弩手", 58.0, 1.82, 7.0, "ranged", 7.0, 10.0, "hunter", Color(0.38, 0.91, 0.90), 0.95)
            archer["skill_delay"] = 2.8
            archer["skill_chance"] = 0.88
            archer["volley"] = 2
            return archer
        6:
            var sapper := _record("swamp_sapper", "腐沼爆裂蟲", 66.0, 2.38, 8.0, "melee", 0.9, 0.0, "crawler", Color(0.59, 0.91, 0.28), 0.83)
            sapper["dying_burst"] = 16.0
            return sapper
        _:
            var oracle := _record("rift_oracle", "虛空觀星者", 88.0, 1.10, 6.0, "ranged", 6.7, 19.0, "caster", Color(0.91, 0.48, 0.99), 1.08)
            oracle["skill_delay"] = 3.05
            oracle["skill_chance"] = 0.92
            return oracle

static func _record(id: String, title: String, hp: float, speed: float, contact: float, behavior: String, distance: float, magic: float, loot: String, tint: Color, sprite_scale: float) -> Dictionary:
    return {
        "id":id, "name":title, "hp":hp, "speed":speed,
        "touch_damage":contact, "touch_delay":0.82,
        "behavior":behavior, "desired_range":distance,
        "skill_delay":2.35 if behavior == "ranged" else 0.0,
        "skill_chance":0.8 if behavior == "ranged" else 0.0,
        "skill_damage":magic,
        "low_health_trigger":0.0, "berserk_speed":1.0, "dying_burst":0.0,
        "loot_profile":loot, "color":tint, "scale":sprite_scale, "volley":1,
    }

static func scaled_stats(base: Dictionary, level: int) -> Dictionary:
    var out := base.duplicate(true)
    var lv := maxi(1, level)
    out["level"] = lv
    out["hp"] = float(base["hp"]) * (1.0 + float(lv - 1) * 0.16)
    out["touch_damage"] = float(base["touch_damage"]) * (1.0 + float(lv - 1) * 0.11)
    out["skill_damage"] = float(base["skill_damage"]) * (1.0 + float(lv - 1) * 0.10)
    return out
