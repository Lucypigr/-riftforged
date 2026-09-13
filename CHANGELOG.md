# Changelog

## 0.4.0 — 2026-09-13
- Added an original PoE-inspired linked gem system using the existing JavaScript ES-module architecture.
- Added a free eight-socket matrix with two linked groups plus one unlinked utility socket.
- Added red/green/blue active, support and aura gems with touch/click installation.
- Support gems work only when linked to the currently selected active gem; aura gems work without links.
- Added real projectile chain, extra projectile, pierce, damage, attack-speed, crit and regeneration gem effects.
- Added build-defining projectile transformations: splash explosions, projectile fork and extended projectile range/lifetime.
- Added an additional chain-focused active gem so different linked setups can reuse supports in different ways.
- Added 5% normal-enemy gem drops and a much higher boss gem-drop chance.
- Added glowing ground gem drops with proximity auto-pickup and gem loot notifications.
- Added automated tests for linked support, unlinked support, aura behavior, duplicate gem installation, splash, fork and reach support rules.
- Added pull-request/feature-branch CI that runs tests and JavaScript syntax checks.

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
