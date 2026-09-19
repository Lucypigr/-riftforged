# Actual validation — 2026-09-20 UTC

Engine executed: `4.7.2.stable.official.ed1daf0bf` from official godot-builds release.
Baseline: all nine PR #52 CI smoke suites passed before behavioral edits.
Final experiment: all ten suites passed with the subset font, no script/runtime ERROR lines.

| Suite | Result |
|---|---|
| v4_smoke | PASS — progression, mana, flasks, floor loot, boss |
| v4_integrity_smoke | PASS — five builds, item identity, summons, telegraphs |
| gem_smoke | PASS — links, colors, install/extract, currency/refine |
| unified_inventory_smoke | PASS |
| equipment_interaction_smoke | PASS |
| mobile_landscape_smoke | PASS — synthetic input/layout assertions |
| v5_smoke | PASS — combined inventory, touch ownership, mana |
| configurable_hotbar_smoke | PASS — assign/swap/clear, fifth button |
| skill_aim_smoke | PASS — manual ranges, two-touch, release/cancel |
| expedition_smoke | PASS — 54 assertions, physical movement, projectile damage, 12 damage actives, support effects, OS cancellation, floor pickup/equip/install, real skill damage kills boss, death/respawn |

The integration suite places enemies and supplies test mana to exercise behavior deterministically. It is not evidence of balanced natural progression or a human playthrough. Inherited gem/v5 tests were updated only to pick up fixture currency from the floor instead of assuming free starter currency.

Web: release export PASS. Gzip loader executed in Node: WASM decompressed and WebAssembly.compile passed; PCK decompression/magic passed. PCK 853,784 bytes (previous unoptimized 9,551,580); WASM 39,514,754 bytes. Compressed payload 10,054,758 + 830,376 bytes, plus JS/icons. This is size measurement, not a measured browser loading-time claim.

Browser QA: NOT PASSED / blocked. Supervised preview reports running, but the permitted cloud browser returned `net::ERR_BLOCKED_BY_CLIENT` opening it. No screenshot, visual layout, browser input, browser FPS, or end-to-end browser success is claimed.
Physical iPhone/Android: NOT RUN. Native PC visual QA: NOT RUN. IPA/APK/Desktop package exports: NOT RUN.

Known limitations: inherited procedural/SVG presentation; deep controller inheritance remains; tangent obstacle steering is simpler than navigation-mesh pathfinding; no persistent expedition save system; no physical safe-area or multi-device performance validation. Compressed Web loader requires modern DecompressionStream support. Hosted deployment status and any later CI results must be reported separately from these local tests.
