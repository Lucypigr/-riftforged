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
- Red/green/blue gems are installed into sockets supplied by weapons and armor.
- The run begins with a temporary four-link Rift Base so the gem system is usable before socket gear drops.
- Dropped weapons/armor roll 2–6 sockets depending on rarity plus a link topology such as 4-link, 3+1, 2+2, 5+1 or 3+3.
- Active gems define the attack being used.
- Support gems affect the selected active gem only when they share its linked group and tags are compatible.
- Aura gems consume sockets but do not require links.
- Swapping the socket-providing item safely returns installed gems to the gem stash, then applies the new socket/link topology.
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

Multiple active gems can occupy a socket item; tapping an installed active gem selects which attack is currently used, and the linked supports in its group are recalculated for that active gem.

## Loot model
Base item + rarity + affixes + optional socket topology. Common/Magic/Rare/Legendary remain the initial rarity bands. Weapons and armor can now matter even when raw stats are similar because socket count and links can enable different builds. Future versions add item level, affix tiers, build-defining legendary effects, crafting, socket rerolling/expansion and loot filters.

## Roguelite layer
Level-up blessings remain run-only secondary bonuses. Gems and socket gear are the main combat-shaping layer. Ember is persistent. Future meta progression should unlock options rather than simply grant large permanent damage bonuses.
