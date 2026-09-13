# PROJECT MEMORY

## Confirmed direction
- Original loot-driven ARPG inspired by the design principles of games such as Path of Exile and Grim Dawn, without copying proprietary assets/code/content.
- Add roguelite run structure.
- Grim Dawn database/tooling analysis is available as structural reference; use its data-driven separation ideas rather than copying game content.
- User wants a PoE-style linked gem feel: physical socket/link decisions, touch-friendly installation, ground gem drops and build-changing support behavior.
- User wants playable results early, then iterative optimization.
- User accepted the first Godot/iPhone prototype and wants development to continue with ChatGPT handling implementation/testing while the iPhone is used for real-device feel testing.

## Current platform strategy
- Keep the existing JavaScript/Canvas build as the stable comparison build at the GitHub Pages root.
- Continue a parallel Godot 4.7.2 version under `/godot-test/` while systems are migrated and compared on iPhone.
- Godot uses a true 3D scene with orthographic Camera3D + billboard-style 2.5D actors, Compatibility rendering and portrait-first controls.
- GitHub repository remains the canonical project source; feature branches are validated by CI before merging.

## JavaScript prototype status
- Current JS build already has linked gems, equipment-driven socket layouts, ground loot, portrait HUD work and browser smoke testing.
- It remains useful as a rules/reference implementation while the Godot version catches up.

## Godot prototype status
- First mobile prototype has already been merged to `main` and deployed to `/godot-test/`.
- Current development branch: `feature/godot-gem-combat`.
- Combat now uses multiple simultaneous enemies plus elite enemies, continuous respawning, player HP, contact damage and death/respawn.
- Godot now has a touch-friendly four-link gem panel and gem stash.
- Ported active/support behaviors include damage scaling, extra projectiles, chain, pierce, splash, fork, attack speed and projectile reach/lifetime.
- Projectiles auto-target the nearest enemy and carry their current gem-derived behavior through hit handling.
- Normal enemies use a 5% gem-drop chance; elite prototype enemies use a higher 35% chance.
- Glowing gem drops exist physically in the world and are collected by proximity; a starter pickup is placed near spawn so iPhone testing can verify pickup immediately.
- UI currently shows HP, kills and active linked-build summary.
- The scene intentionally still uses procedural placeholder actor visuals; higher-quality character art/sprites should be added after the gameplay/camera/mobile interaction loop is stable.

## Validation rules
- Godot feature changes must pass project import, headless scene smoke test and Web export in GitHub Actions.
- The Godot smoke test currently verifies core nodes, orthographic KEEP_WIDTH camera behavior, an initial enemy pack, gem UI presence and linked-chain support behavior.
- Do not replace the stable root JS build with Godot until the Godot version has reached comparable gameplay coverage and has been repeatedly tested on iPhone.

## Next implementation targets
- Add better 2.5D character/enemy artwork and animation without giving up the current true-3D ground/camera setup.
- Port equipment drops/inventory and socket-bearing gear into Godot.
- Add boss encounters and stronger loot feedback.
- Split the growing Godot prototype script into dedicated combat, gem, loot, enemy and UI systems as the port matures.
