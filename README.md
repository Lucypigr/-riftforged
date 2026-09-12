# Riftforged

Original browser ARPG prototype combining loot-driven character building with a compact roguelite expedition loop.

## Play

Serve the repository with any static HTTP server:

```bash
python3 -m http.server 5173
```

Then open `http://localhost:5173`.

### Controls
- Desktop: WASD / arrows move, hold left mouse to attack, Shift to dash, I for inventory.
- Mobile: left virtual stick, Attack and Dash buttons.

## Current gameplay
- Top-down real-time combat.
- Enemy AI states: chase → attack windup → damage → cooldown.
- Boss every fifth wave.
- Random equipment rarity and affixes.
- Loot pickup and immediate stat integration.
- Three-choice chest after every cleared wave.
- Three-choice roguelite blessing on level-up.
- Persistent Ember currency placeholder via localStorage.
- Desktop and touch input from a unified command layer.

## Validation

```bash
npm test
npm run check
```

See `docs/` for design, architecture, portability, and project memory.
