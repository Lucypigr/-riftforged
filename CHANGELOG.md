# Changelog

## 0.6.3 — 2026-09-14
- Fixed the desktop life/mana orbs appearing uncolored in Web/Compatibility rendering by replacing the custom CanvasItem shader with deterministic canvas-drawn circular liquid fills.
- Strengthened the orb colors so life renders clearly red and mana clearly blue while preserving live fill levels and numeric values.
- Fixed the centered action dock covering the three active skill buttons; the desktop row now visibly shows left-click basic attack plus skills 1/2/3.
- Added HUD regression checks for orb colors, Web-safe orb rendering, skill visibility, hotkey labels and draw order.

## 0.6.2 — 2026-09-14
- Rebuilt the desktop combat HUD around a dark-fantasy ARPG bottom frame inspired by classic life-orb/mana-orb layouts without copying external game assets.
- Added a large red life orb on the lower-left and blue mana orb on the lower-right, with live numeric values and shader-driven liquid fill.
- Added a centered bottom action dock containing the left-click basic attack slot plus the three existing active skills.
- Added functional life and mana flasks on desktop hotkeys 4/5 with charges, healing/restoration and HUD updates.
- Added a real mana resource: active skills now consume mana, mana regenerates over time and insufficient mana blocks the cast with feedback.
- Kept the existing 1280×720 desktop landscape/fullscreen profile and the mobile portrait control layout intact.
- Added a dedicated ARPG HUD smoke test covering life/mana controls, skill mana consumption and flask behavior before Web export.

## 0.6.1 — 2026-09-14
- Added a desktop-specific 1280×720 landscape runtime profile while preserving the existing portrait mobile layout.
- Desktop camera now keeps vertical framing and expands horizontally so widescreen play shows more battlefield instead of stretching the portrait view.
- Desktop UI hides the mobile joystick and attack button, moves skills into a centered bottom action bar, and keeps weapon/gem controls in the top-right HUD.
- Added a desktop fullscreen control plus F/F11 shortcut; native desktop builds enter fullscreen automatically, while Web builds use the browser-safe user-triggered fullscreen request.
- Kept the Web canvas adaptive so the game fills the available browser area rather than remaining in the old 390×844 portrait presentation.
- Extended Godot smoke coverage for the 1280×720 desktop viewport, widescreen camera, hidden mobile controls and fullscreen button.

## 0.6.0 — 2026-09-14
- Added the first fully playable weapon/equipment loop to Godot V2: picked weapons are stored, shown in a weapon panel and can be equipped directly.
- Added three distinct weapon archetypes: bows use long-range rapid projectiles, blades use short-range melee hits, and focuses use slower high-damage ranged attacks.
- Weapon affixes now affect real combat values for damage, attack speed, flat elemental damage and critical chance instead of being display-only loot text.
- Added three active combat skills with mobile buttons and desktop hotkeys 1/2/3: a weapon-specific multi-hit skill, an explosive AoE attack, and Rift Dash movement.
- The first skill changes behavior with the equipped weapon: bow/focus fires a multi-projectile attack while blades perform a circular melee strike.
- Added a gameplay HUD weapon readout, skill cooldown display, equipment button and weapon inventory panel while preserving the existing gem button and mobile controls.
- Kept the Web performance work active underneath the new gameplay layer, including projectile/effect pools, staggered AI decisions, label culling and capped ground loot.
- Extended Godot smoke coverage to verify the starter weapon, equipment UI, skill catalog, active skill cooldowns, pooled skill projectiles and weapon-type switching.

## 0.5.1 — 2026-09-14
- Added a second Godot Web performance pass for the 2.5D ARPG runtime.
- Prewarmed and reused player/enemy projectile nodes plus hit-flash nodes to reduce browser allocation/GC spikes during sustained combat.
- Kept movement/collision at 60 Hz while splitting enemy AI decisions across two alternating phases.
- Throttled enemy/loot Label3D visibility scans and hides distant labels to reduce text rendering cost.
- Capped persistent ground loot at 24 drops so long combat sessions cannot grow an unbounded scene tree.
- Extended the Godot smoke test to verify pooled effects and the second performance layer before Web export.

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
