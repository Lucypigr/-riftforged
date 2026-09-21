# Expedition Lab 0.1

- Vendor PR #52 into an independent Godot project and scene entry; original directory unchanged.
- Correct basic aiming, canceled touch, multishot/pierce semantics, melee area and actual cold slowdown.
- Add pack activation distance, dodgeable melee telegraphs and simple obstacle steering.
- Start currencies at zero, reject empty-socket recolor, improve actual boss reward affixes.
- Add responsive boss HUD, exploration objective and death input reset/protection.
- Add actual combat-to-boss integration regression and reproducible local/CI verification.
- Subset UI font and gzip Web payloads; keep gameplay and gem catalog intact.

## 2026-09-21 — Gem expansion
- Retained all 27 IDs; added 18 original simplified active gems and 12 real support gems (57 total).
- Added bounded persistent areas/orbits, delayed strikes, directional waves/bolts/beam, totems and pursuing temporary sentinels.
- Added 23 compatible build recipes and stash search inside the existing gem/equipment window.
- Added required/excluded tag validation, support deduplication and physical/added-fire conflict handling.
- Preserved one gem-drop roll per death and existing drop probabilities; all added gems enter the authoritative pool.
- Fixed camera-relative touch point targeting and burst radius support.
- Added engine-level expansion suite; original godot_v2 remains untouched.
