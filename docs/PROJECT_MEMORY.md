# PROJECT MEMORY

## Confirmed direction
- Original loot-driven ARPG inspired by the design principles of games such as Path of Exile and Grim Dawn, without copying proprietary assets/code/content.
- Add roguelite run structure.
- Grim Dawn database/tooling analysis is available as structural reference; use its data-driven separation ideas rather than copying game content.
- User wants a PoE-style linked gem feel: physical socket/link decisions, touch-friendly installation, ground gem drops and build-changing support behavior.
- User wants playable results early, then iterative optimization.

## Current prototype defaults
- 2D top-down gameplay with pseudo-isometric 2.5D presentation.
- Web first, using dependency-free JavaScript ES modules + Canvas 2D.
- Desktop + mobile input from the first version.
- GitHub repository is the canonical project source.

## Gem + socket prototype status
- Feature branch: `feature/poe-style-gems`.
- Pull request: #7.
- Starter state now uses a temporary four-link Rift Base rather than the old eight-socket free matrix.
- Dropped weapons/armor roll socket/link layouts; rarity controls the available 2–6 socket range.
- Gem UI can select socket-providing equipment from the player's inventory. Switching socket gear safely returns installed gems to the gem stash before rebuilding sockets.
- Active/support/aura gems use linked-group compatibility.
- Real gameplay transformations include chain, multi-projectile, pierce, splash, fork, projectile reach, damage/speed trade-offs, crit and regeneration.
- Normal enemies use a 5% gem-drop chance; bosses use a much higher chance.
- A headless real-browser smoke test was added using Chrome/Chromium DevTools Protocol to validate boot, gem UI interaction and a mobile viewport without adding runtime dependencies.
- Earlier Node/syntax CI passed for the linked-gem version. The newest equipment-socket/browser-smoke revision must not be merged until its latest CI run completes successfully.
