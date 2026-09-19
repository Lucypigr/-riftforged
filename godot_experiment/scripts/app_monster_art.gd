extends "res://scripts/app_armor_monsters.gd"

# Per-species imported art is used in the actual spawned runtime, including
# reinforcements. Existing AI, colliders and lightweight silhouette parts stay.
const RUNNER_ART = preload("res://art/enemies/bone_runner.svg")
const BULWARK_ART = preload("res://art/enemies/rift_bulwark.svg")
const ARCHER_ART = preload("res://art/enemies/crystal_archer.svg")
const SAPPER_ART = preload("res://art/enemies/swamp_sapper.svg")
const ORACLE_ART = preload("res://art/enemies/rift_oracle.svg")

func _spawn_enemy(force_elite: bool = false, slot: int = -1) -> void:
    super._spawn_enemy(force_elite, slot)
    if enemies.is_empty():
        return
    var entry: Dictionary = enemies.back()
    var archetype: Dictionary = entry.get("archetype", {})
    var sprite := entry.get("visual") as Sprite3D
    if sprite == null:
        return
    match String(archetype.get("id", "")):
        "bone_runner": sprite.texture = RUNNER_ART
        "rift_bulwark": sprite.texture = BULWARK_ART
        "crystal_archer": sprite.texture = ARCHER_ART
        "swamp_sapper": sprite.texture = SAPPER_ART
        "rift_oracle": sprite.texture = ORACLE_ART
        _: return
    # The imported sprite provides the designed colours; do not tint it using
    # the placeholder species modulate which obscured painted contrast.
    sprite.modulate = Color.WHITE
