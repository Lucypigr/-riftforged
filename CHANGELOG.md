# Changelog

## 0.4.0 — 2026-09-13
- Added an original PoE-inspired linked gem system using the existing JavaScript ES-module architecture.
- Replaced the temporary eight-socket free matrix with a four-link starter base plus equipment-driven socket layouts.
- Weapons and armor now roll 2–6 sockets with link patterns such as full links, split links and unlinked utility sockets.
- Added a socket-equipment selector to the gem UI; changing socket gear safely returns installed gems to the stash before rebuilding the layout.
- Loot reward cards now show socket/link topology so gear can be valuable for build structure, not only raw stats.
- Added red/green/blue active, support and aura gems with touch/click installation.
- Support gems work only when linked to the currently selected active gem; aura gems work without links.
- Added real projectile chain, extra projectile, pierce, damage, attack-speed, crit and regeneration gem effects.
- Added build-defining projectile transformations: splash explosions, projectile fork and extended projectile range/lifetime.
- Added an additional chain-focused active gem so different linked setups can reuse supports in different ways.
- Added 5% normal-enemy gem drops and a much higher boss gem-drop chance.
- Added glowing ground gem drops with proximity auto-pickup and gem loot notifications.
- Expanded automated tests for linked support, unlinked support, aura behavior, duplicate gem installation, splash, fork, reach, equipment socket swapping and socket-layout generation.
- Added a dependency-free headless Chrome/Chromium browser smoke test covering actual page boot, gem UI interaction and a mobile viewport.
- Feature-branch/PR CI now runs unit tests, JavaScript syntax checks and the browser smoke test, with superseded runs cancelled automatically.
- Optimized portrait phones with a compact HUD/control layout and a true 0.72x world-camera pullback so more battlefield is visible instead of shrinking only the player sprite.

## 0.3.0 — 2026-09-13
- Added a true pseudo-isometric 2.5D rendering mode while preserving the existing gameplay rules.
- Remapped desktop/mobile movement so controls remain screen-relative under the isometric projection.
- Added depth sorting for player, enemies, loot and environment props.
- Reworked the battlefield presentation with isometric stone tiles, braziers, pillars, banners, rubble, grass, fog and stronger lighting.
- Replaced the most primitive hero/enemy shapes in the 2.5D renderer with clearer dark-fantasy silhouettes.

## 0.1.0 — 2026-09-12
- Created first playable Riftforged prototype.
- Added movement, dash, auto-target projectile combat and hit feedback.
- Added enemy state machine and boss wave.
- Added randomized loot rarity and affixes.
- Added three-choice wave chest and level-up blessings.
- Added inventory, persistent Ember placeholder and mobile controls.
- Added project design/architecture/portability memory documents.
