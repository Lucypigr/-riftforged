# ARCHITECTURE

## Current stack
No runtime dependencies. HTML/CSS/ES modules + Canvas 2D.

## Separation
- `data/`: enemy, item and skill definitions.
- `systems/`: rules such as loot generation.
- `input/`: keyboard, pointer and touch normalization.
- `Game.js`: current orchestration/render loop. As scope grows it will be split into combat, AI, world, rendering and progression systems.

## Portability rule
Core loot/progression data should remain renderer-agnostic. Browser-specific API usage is kept near input, local persistence and presentation layers so the rules can later be ported to Unity C# or Godot without pretending this is a one-click conversion.
