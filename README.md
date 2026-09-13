# Riftforged

A browser-first 2.5D loot roguelite ARPG prototype built with dependency-free JavaScript ES modules, HTML/CSS and Canvas 2D.

## Current prototype
- pseudo-isometric 2.5D battlefield rendering
- desktop and mobile controls
- enemy state machine and boss waves
- randomized equipment rarity and affixes
- run-only blessings and persistent Ember placeholder
- original linked skill-gem prototype with active/support/aura behavior
- touch/click socket management and glowing ground gem drops
- real projectile transformations including chain, pierce, multi-projectile, splash and fork

## Run locally
Use any static web server from the repository root. For example:

```bash
npm run serve
```

Then open `http://localhost:5173`.

## Validate

```bash
npm test
npm run check
```

GitHub Actions runs the same validation on feature branches and pull requests. The `main` branch deploy workflow publishes the static site to GitHub Pages after tests pass.

## Project memory
Design and architecture decisions are tracked in `docs/` so the project can be continued across sessions without relying on chat history alone.
