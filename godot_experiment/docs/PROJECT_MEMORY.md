# Confirmed constraints

User requested an independent experiment, explicitly forbidding changes to the original game.
Baseline read from latest main: 265bc9ec28187a2f04c30921dfee6f6f60755969, PR #52 merged. Root repository docs describe an older prototype, so baseline source/tests are authoritative.
Branch: experiment/gpt6-riftforged-independent. Work restricted to godot_experiment plus a new opt-in CI workflow. Never merge this branch or modify original deployments without a new request.
Use Traditional Chinese UI, mobile two-finger controls, five configurable hotbar slots, ground loot, existing gem IDs and tag compatibility. Do not introduce classes/talent trees or change drop rates.

This is an integration/fix experiment reusing substantial existing game code and artwork, not a wholly new engine/game implementation. Do not attribute inherited systems to this turn.
Test results must distinguish automated engine checks, browser QA, and physical-device QA. Browser access failed in this environment; do not infer rendering or mobile FPS from headless tests.

## Gem expansion request — 2026-09-21
User asked for substantially more gems/build diversity, referencing https://poedb.tw/tw/Gem and https://home.gamer.com.tw/artwork.php?sn=3187450 . Both requested pages returned HTTP 403 in this session; their contents were not read. Do not claim the 23 recipes reproduce that article. New skills are explicitly simplified original implementations inspired by common ARPG mechanics, not imported POE code/assets.
Catalog now 57 (33 active/aura actions, 24 supports). Preserve original IDs and drop probabilities. No free new gems/currency or automatic equip on guide selection. Update only the existing experimental PR/preview; do not merge or change the original game.
