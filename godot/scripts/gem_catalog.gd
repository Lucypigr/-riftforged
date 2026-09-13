extends RefCounted

const COLORS := {
    "red": "ef6658",
    "green": "53d49a",
    "blue": "65a9ff",
}

const GEMS := {
    "crimson_bolt": {"id":"crimson_bolt", "color":"red", "kind":"active", "icon":"◆", "name":"緋紅裂矢", "active":{"damage":1.12, "speed":1.0, "projectile_color":"ff8b68"}},
    "verdant_volley": {"id":"verdant_volley", "color":"green", "kind":"active", "icon":"◆", "name":"翠綠疾矢", "active":{"damage":0.86, "projectiles":1, "speed":1.12, "projectile_color":"71e7ab"}},
    "azure_lance": {"id":"azure_lance", "color":"blue", "kind":"active", "icon":"◆", "name":"蒼藍霜槍", "active":{"damage":0.98, "pierce":1, "speed":1.2, "projectile_color":"83bdff"}},
    "azure_arcshot": {"id":"azure_arcshot", "color":"blue", "kind":"active", "icon":"◆", "name":"蒼藍躍電", "active":{"damage":0.90, "chain":1, "speed":1.08, "projectile_color":"77c8ff"}},
    "crimson_force": {"id":"crimson_force", "color":"red", "kind":"support", "icon":"◇", "name":"緋紅猛攻", "support":{"damage":1.32, "cooldown":1.08}},
    "crimson_burst": {"id":"crimson_burst", "color":"red", "kind":"support", "icon":"◇", "name":"緋紅爆裂", "support":{"damage":0.92, "splash":2.7, "splash_damage":0.45}},
    "verdant_chain": {"id":"verdant_chain", "color":"green", "kind":"support", "icon":"◇", "name":"翠綠連鎖", "support":{"chain":1, "damage":0.90}},
    "verdant_multishot": {"id":"verdant_multishot", "color":"green", "kind":"support", "icon":"◇", "name":"翠綠多重", "support":{"projectiles":2, "damage":0.84}},
    "verdant_fork": {"id":"verdant_fork", "color":"green", "kind":"support", "icon":"◇", "name":"翠綠分岔", "support":{"forks":2, "fork_damage":0.72, "damage":0.90}},
    "azure_pierce": {"id":"azure_pierce", "color":"blue", "kind":"support", "icon":"◇", "name":"蒼藍穿透", "support":{"pierce":2, "damage":0.94}},
    "azure_haste": {"id":"azure_haste", "color":"blue", "kind":"support", "icon":"◇", "name":"蒼藍迅捷", "support":{"cooldown":0.82, "damage":0.92}},
    "azure_reach": {"id":"azure_reach", "color":"blue", "kind":"support", "icon":"◇", "name":"蒼藍延伸", "support":{"speed":1.18, "life":1.35, "damage":0.96}},
}

const DROP_POOL := [
    "crimson_bolt", "verdant_volley", "azure_lance", "azure_arcshot",
    "crimson_force", "crimson_burst", "verdant_chain", "verdant_multishot",
    "verdant_fork", "azure_pierce", "azure_haste", "azure_reach",
]

static func get_gem(id: String) -> Dictionary:
    return GEMS.get(id, {})

static func gem_color(id: String) -> Color:
    var gem: Dictionary = get_gem(id)
    var key: String = String(gem.get("color", "blue"))
    return Color.html(String(COLORS.get(key, "65a9ff")))

static func random_drop() -> String:
    return String(DROP_POOL[randi() % DROP_POOL.size()])
