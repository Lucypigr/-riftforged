# Architecture

Independent root: `project.godot` → `main.tscn` → `scripts/app_experiment.gd`.
All `res://` references are local to this project. User data directory: RiftforgedExpeditionLab.

Vendored PR #52 systems:
- `linked_gem_system.gd`: authoritative 57-gem catalog, tags, links, damage/mana modifiers.
- `weapon_skill_system.gd`, `armor_equipment.gd`, `unified_bag.gd`: normalized equipment/UID views.
- `app_v3_gems.gd`, `app_v4.gd`, `app_v4_integrity.gd`: drops, progression, flasks, boss, combat.
- `app_configurable_hotbar.gd`, `app_hotbar_safe.gd`: five identity-based shortcuts.
- `skill_aim_rules.gd`, `skill_aim_hud.gd`, `app_skill_aim.gd`: shared aiming, touch ownership, swept projectile collision.
- `v5_equipment_ui.gd`, `v5_gem_ui.gd`: single equipment/gem modal.
- `region_map.gd`: streamed terrain, roads, obstacles, spawn positions.
- `app_grim_perf2.gd`: staggered enemy AI and pooled visuals.
- `app_experiment.gd`: independent orchestration, manual basic attacks, objective, death protection, boss rewards.

The baseline uses a deep inheritance chain. This experiment intentionally preserves that architecture to avoid a speculative rewrite. It is maintainable through the named modules and regression suite, but further composition/refactoring is a known technical debt. Equipped weapon is a normalized snapshot of its authoritative inventory entry; use `_save_weapon`/equip paths rather than mutating one representation alone.

No native platform services, analytics, external game APIs or credentials are used.

Gem expansion composition:
- `gem_effect_runtime.gd`: child Node owned by experiment entry; compiles a cast snapshot and updates capped delta-based effects. Inventory pauses effects; death clears them. Enemy references are resolved at each hit. 24 overall effects, 6 zones/travelling effects, 3 sentinels, 1 or 3 totems; no loot eviction. Straight bolts reuse swept projectiles. Temporary construct visuals are procedural placeholders.
- `build_catalog.gd`: 23 recipe records, each validated for connected tag compatibility.
- `v5_gem_ui.gd`: searchable stash and non-mutating build guide inside existing modal.
- Supports require any matching tag plus all `requires_all`, reject `excludes`, deduplicate IDs. Brutality disables added-fire support. Duration/echo/volley supports intentionally target tagged expansion skills only; UI does not pretend otherwise.
