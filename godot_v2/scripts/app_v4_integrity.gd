extends "res://scripts/app_v4.gd"

# Player-selectable combinations; these are recommendations, not fixed classes.
# Added Fire Damage Support requires a compatible physical-damage skill in POE;
# the existing fireball is a pure fire spell, so Inspiration is the valid red
# replacement instead of falsely enabling an incompatible support.
const V4_BUILDS := {
    "弓箭清圖流": ["split_arrow", "pierce_support", "faster_attacks_support"],
    "近戰範圍流": ["cleave", "melee_physical_support", "increased_area_support"],
    "火球法師流": ["ember_bolt", "inspiration_support", "faster_casting_support"],
    "冰霜控制流": ["frost_nova", "increased_area_support", "hypothermia_support"],
    "閃電連鎖流": ["arc", "faster_casting_support", "controlled_destruction_support"],
}

func _spawn_loot_visual(position: Vector3, item: Dictionary) -> void:
    # Determine sockets/links ONCE at monster death, before a floor instance
    # exists; pickup must not reroll or create a new physical item identity.
    var prepared := item.duplicate(true)
    var slot := String(prepared.get("slot", ""))
    if slot == "武器":
        prepared = GemSystem.normalize_weapon_sockets(WeaponSkillSystem.normalize_weapon(prepared), false)
    elif not ArmorSystem.canonical_slot(slot).is_empty():
        prepared = ArmorSystem.normalize(prepared)
    super._spawn_loot_visual(position, prepared)

func _kill_enemy(index: int) -> void:
    if index < 0 or index >= enemies.size():
        return
    var entry: Dictionary = enemies[index]
    var id := int(entry.get("id", -1))
    var summon_owner := String((entry.get("archetype", {}) as Dictionary).get("id", "")) == "rift_oracle"
    super._kill_enemy(index)
    if summon_owner:
        _remove_minions(id)

func _use_skill(slot: int) -> void:
    var entries := _hotbar_entries()
    if slot >= 0 and slot < entries.size():
        var gem: Dictionary = entries[slot].get("gem", {})
        if String(gem.get("id", "")) == "arc" and _enemy_ids_in_range(10.0, 4).is_empty():
            ui.set_hint("電弧：附近沒有目標，沒有消耗魔力")
            return
    super._use_skill(slot)

func debug_v4_builds() -> Dictionary:
    return V4_BUILDS.duplicate(true)
