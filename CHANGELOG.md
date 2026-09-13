# Changelog

## 0.5.0 — 2026-09-13
- Continued the parallel Godot 4.7.2 mobile prototype after the first iPhone test was accepted.
- Expanded the Godot scene from a single target into a small combat pack with normal and elite Rift beasts, contact damage, player HP, death/respawn and continuous enemy replacement.
- Ported the first linked-gem combat slice into Godot with a touch-friendly four-link panel and gem stash.
- Added Godot versions of crimson/green/blue active and support gems for damage, multishot, chain, pierce, splash, fork, haste and projectile reach/lifetime.
- Added nearest-target projectile combat with real multishot, chain redirection, pierce, fork children and splash damage interactions.
- Added glowing physical gem drops, proximity auto-pickup and a starter world pickup so mobile testing can verify the loot loop immediately.
- Added a richer prototype battlefield path, extra props, character/enemy ground shadows and a compact HP/build HUD.
- Extended the Godot headless smoke test to validate enemy packs, loot/UI nodes and linked chain support behavior.
- Godot CI now validates project import, headless gameplay smoke and Web export before the prototype is deployed.
- Removed the temporary English Web text rewriter and the custom BMFont/SVG workaround; the Godot prototype now loads a real OFL-licensed Noto Sans TC TrueType font directly and applies it through a shared Theme/Label3D font path.

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
