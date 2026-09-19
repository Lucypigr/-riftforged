extends "res://scripts/app_v4.gd"

const V4GemUI = preload("res://scripts/v4_gem_ui.gd")

# Player-selectable combinations, never forced equipment classes. Added Fire
# does not match this fireball's spell tags; Inspiration replaces it rather
# than silently forcing an incompatible support to activate.
const V4_BUILDS := {
    "弓箭清圖流": ["split_arrow", "pierce_support", "faster_attacks_support"],
    "近戰範圍流": ["cleave", "melee_physical_support", "increased_area_support"],
    "火球法師流": ["ember_bolt", "inspiration_support", "faster_casting_support"],
    "冰霜控制流": ["frost_nova", "increased_area_support", "hypothermia_support"],
    "閃電連鎖流": ["arc", "faster_casting_support", "controlled_destruction_support"],
}

func _ready() -> void:
    super._ready()
    if gem_ui == null or ui_font == null:
        return
    var old_ui := gem_ui
    remove_child(old_ui)
    old_ui.queue_free()
    gem_ui = V4GemUI.new() as RiftLinkedGemUI
    gem_ui.name = "LinkedGemInventory"
    add_child(gem_ui)
    gem_ui.setup(ui_font)
    gem_ui.gem_requested.connect(_select_gem)
    gem_ui.socket_requested.connect(_use_socket)
    gem_ui.currency_requested.connect(_use_currency)
    gem_ui.aura_requested.connect(_toggle_aura)
    (gem_ui as RiftV4GemUI).set_action_interval(Callable(self, "_action_seconds"))
    _refresh_gem_ui()

func _spawn_loot_visual(position: Vector3, item: Dictionary) -> void:
    # Determine sockets and links at monster death: picking an item up must
    # not reroll its physical properties or replace its UID.
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

func _warning_blast(center: Vector3, radius: float, damage: float, seconds: float, owner_id: int) -> void:
    # Node3D.global_position requires a live scene-tree transform. The parent
    # implementation positioned a newly constructed marker before add_child,
    # resulting in !is_inside_tree() errors and misplaced danger indicators.
    var marker := MeshInstance3D.new()
    marker.name = "DangerTelegraph"
    var disc := CylinderMesh.new()
    disc.top_radius = radius
    disc.bottom_radius = radius
    disc.height = 0.03
    marker.mesh = disc
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(1.0, 0.13, 0.07, 0.38)
    mat.emission_enabled = true
    mat.emission = Color(1.0, 0.08, 0.06)
    mat.emission_energy_multiplier = 1.6
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    marker.material_override = mat
    marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    projectiles_root.add_child(marker)
    marker.global_position = center + Vector3(0, 0.09, 0)
    get_tree().create_timer(seconds).timeout.connect(_finish_warning.bind(marker, center, radius, damage, owner_id), CONNECT_ONE_SHOT)

func debug_v4_builds() -> Dictionary:
    return V4_BUILDS.duplicate(true)
