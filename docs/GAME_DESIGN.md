# GAME DESIGN — Riftforged

## Pillars
1. **Loot must change decisions**, not only increase item level.
2. **Combat must be readable but dense**: telegraphs, windup, cooldown, impact feedback.
3. **Every expedition creates a temporary build**, while permanent progression stays secondary.
4. **Runs are short enough to retry immediately**, but long enough for a build to become recognizable.
5. **Skill gems are physical build pieces**: socket space and links are part of the build decision.

## Core loop
Enter Rift → clear combat wave → collect equipment/gems from the ground → choose one of three loot rewards → level and choose blessings → reconfigure linked gems → fight boss every 5 waves → die or push deeper → bring Ember home.

## Gem model
Riftforged uses an original linked-gem system inspired by the general build-crafting principle of socket-link ARPGs, without copying proprietary names, assets or exact content.
- Red/green/blue gems use a free socket matrix.
- Active gems define the attack being used.
- Support gems affect the selected active gem only when they share its linked group and tags are compatible.
- Aura gems consume sockets but do not require links.
- Normal enemies have a 5% gem-drop chance; bosses have a substantially higher chance.
- Gem drops glow on the battlefield and are collected by moving near them.
- Desktop and touch use the same flow: select a gem, then select a socket.

Current prototype gems cover projectile actives plus damage, chain, multi-projectile, pierce, speed and aura modifiers. Chain is a real projectile redirect to a nearby enemy rather than only a numeric stat increase.

## Loot model
Base item + rarity + affixes. Initial prototype has Common/Magic/Rare/Legendary. Future versions add item level, affix tiers, build-defining legendary effects, crafting, socket expansion and loot filters.

## Roguelite layer
Level-up blessings remain run-only secondary bonuses. Gems are the main combat-shaping layer. Ember is persistent. Future meta progression should unlock options rather than simply grant large permanent damage bonuses.
