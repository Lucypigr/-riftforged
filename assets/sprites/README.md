# 2.5D Actor Sprite Slots

The renderer automatically uses these transparent PNG files when present:

- `hero.png` — red-caped knight, feet centered at bottom edge.
- `husk.png` — standard humanoid undead.
- `skitter.png` — low-profile crawling enemy.
- `brute.png` — large armored/meaty enemy.
- `boss.png` — boss silhouette.

## Export rules
- Transparent background.
- One actor per PNG.
- Same 3/4 isometric camera direction for every actor.
- Feet/ground contact centered horizontally and touching the bottom edge.
- Leave a small transparent margin around weapons/capes.
- Recommended source size: 512×512 or 768×768.
- Do not bake a floor, UI, health bar, text, or drop shadow into the PNG.

If an image is missing, Riftforged falls back to the current procedural actor so the game remains playable.
