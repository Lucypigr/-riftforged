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

The important rule is that supports should change behavior, not merely add damage. Current implementations include:
- chain: redirects a projectile to another nearby enemy;
- multi-projectile: changes the number and spread of projectiles;
- pierce: lets a projectile continue through targets;
- splash: creates real area damage around the impact target;
- fork: destroys the original projectile after impact and creates two weaker child projectiles;
- reach: changes projectile speed and lifetime, increasing practical range;
- damage/speed trade-offs and independent aura effects.

Multiple active gems can occupy the matrix; tapping an installed active gem selects which attack is currently used, and the linked supports in its group are recalculated for that active gem.

## Loot model
Base item + rarity + affixes. Initial prototype has Common/Magic/Rare/Legendary. Future versions add item level, affix tiers, build-defining legendary effects, crafting, socket expansion and loot filters.

## Next socket progression step
The current free matrix is intentionally a stable prototype layer. The next equipment pass will move socket quantity/link topology into dropped build equipment so finding gear can change both raw stats and which gem combinations are possible. Gems already installed in a topology that becomes unavailable must safely return to the gem stash rather than disappear.

## Roguelite layer
Level-up blessings remain run-only secondary bonuses. Gems are the main combat-shaping layer. Ember is persistent. Future meta progression should unlock options rather than simply grant large permanent damage bonuses.
