# ARCHITECTURE

## Current stack
No runtime dependencies. HTML/CSS + JavaScript ES modules + Canvas 2D. The 2.5D presentation is a pseudo-isometric projection layered over the same gameplay/world coordinates.

## Separation
- `data/`: enemy, item, blessing and gem definitions.
- `systems/`: renderer-agnostic rules such as loot generation and linked-gem evaluation.
- `input/`: keyboard, pointer and touch normalization.
- `Game.js`: current orchestration/render loop; as scope grows it will be split into combat, AI, world, rendering and progression systems.
- `IsoMode2.js` / `UprightSprites.js`: presentation-only 2.5D projection and upright actor rendering.
- `GemSystem.js`: socket state, link-group rules, gem drops and combat modifiers. The prototype is isolated as a runtime layer so it can later be folded into dedicated combat/progression modules without rewriting gem data.

## Gem architecture
Gem definitions are data-driven. A socket has a `linkGroup`; an active gem uses only compatible support gems in the same link group. Aura gems occupy sockets but do not require a link. Combat asks the gem system for a compiled loadout profile instead of hard-coding each gem into `Game.js`.

## Portability rule
Core loot/progression/gem data remains renderer-agnostic. Browser-specific APIs stay near input, persistence and presentation so the rules can later be ported to Unity C# or Godot without pretending this is a one-click conversion.
