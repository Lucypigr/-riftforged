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

## Gem prototype status
- Feature branch: `feature/poe-style-gems`.
- Pull request: #7.
- Eight-socket free matrix currently used as a stable prototype topology.
- Active/support/aura gems implemented with linked-group compatibility.
- Real gameplay transformations include chain, multi-projectile, pierce, splash, fork, projectile reach, damage/speed trade-offs, crit and regeneration.
- Normal enemies use a 5% gem-drop chance; bosses use a much higher chance.
- Feature-branch/PR CI runs Node tests and JavaScript syntax checks and is passing.
- Next planned system step: move socket count/link topology from the fixed matrix into dropped build equipment while safely returning displaced gems to the stash.
