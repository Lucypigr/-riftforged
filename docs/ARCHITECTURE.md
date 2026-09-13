# ARCHITECTURE

## Current stack
No runtime dependencies. HTML/CSS + JavaScript ES modules + Canvas 2D. The 2.5D presentation is a pseudo-isometric projection layered over the same gameplay/world coordinates.

## Separation
- `data/`: enemy, item, blessing and gem definitions.
- `systems/`: renderer-agnostic rules such as loot generation, socket topology and linked-gem evaluation.
- `input/`: keyboard, pointer and touch normalization.
- `Game.js`: current orchestration/render loop; as scope grows it will be split into combat, AI, world, rendering and progression systems.
- `IsoMode2.js` / `UprightSprites.js`: presentation-only 2.5D projection and upright actor rendering.
- `SocketSystem.js`: pure socket/link topology generation, formatting and socket construction.
- `GemSystem.js`: gem inventory, active/support/aura evaluation, equipment socket swapping, gem drops and combat transformations.
- `GemUI.js`: touch/click socket management and socket-equipment presentation.

## Gem + socket architecture
Weapons and armor receive a data-only `socketLayout` during loot generation. The layout is an array of linked-group sizes such as `[4]`, `[3,1]` or `[3,3]`. `SocketSystem` converts that layout into runtime socket records with `linkGroup` identifiers. `GemSystem` then compiles the selected active gem plus compatible supports sharing its link group into a combat profile. Aura gems occupy sockets but do not require links.

Changing socket equipment never destroys gems: installed gems are returned to the gem stash before the new topology is created. This keeps item generation independent of rendering and prevents the combat loop from needing equipment-specific branches.

## Testing
- Node unit tests validate loot, socket topology, link isolation, aura rules and behavior-changing support profiles.
- A dependency-free Chromium/Chrome DevTools Protocol smoke test boots the real page, opens the gem UI, installs a linked support and checks a mobile viewport for basic layout/runtime failures.
- GitHub Actions runs unit tests, syntax checks and the browser smoke test for feature branches and pull requests.

## Portability rule
Core loot/progression/gem/socket data remains renderer-agnostic. Browser-specific APIs stay near input, persistence and presentation so the rules can later be ported to Unity C# or Godot without pretending this is a one-click conversion.
