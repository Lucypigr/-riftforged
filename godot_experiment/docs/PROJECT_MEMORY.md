# Confirmed constraints

User requested an independent experiment, explicitly forbidding changes to the original game.
Baseline read from latest main: 265bc9ec28187a2f04c30921dfee6f6f60755969, PR #52 merged. Root repository docs describe an older prototype, so baseline source/tests are authoritative.
Branch: experiment/gpt6-riftforged-independent. Work restricted to godot_experiment plus a new opt-in CI workflow. Never merge this branch or modify original deployments without a new request.
Use Traditional Chinese UI, mobile two-finger controls, five configurable hotbar slots, ground loot, existing gem IDs and tag compatibility. Do not introduce classes/talent trees or change drop rates.

This is an integration/fix experiment reusing substantial existing game code and artwork, not a wholly new engine/game implementation. Do not attribute inherited systems to this turn.
Test results must distinguish automated engine checks, browser QA, and physical-device QA. Browser access failed in this environment; do not infer rendering or mobile FPS from headless tests.
