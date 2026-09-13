extends SceneTree

func _fail(message: String) -> void:
    push_error(message)
    quit(1)

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    var packed := load("res://main.tscn") as PackedScene
    if packed == null:
        _fail("Unable to load ARPG HUD scene")
        return
    var scene := packed.instantiate()
    root.add_child(scene)
    await process_frame
    await process_frame

    var ui_root := scene.get_node_or_null("MobileUI/Root") as Control
    if ui_root == null:
        _fail("Desktop UI root is missing")
        return

    var life_orb := ui_root.get_node_or_null("LifeOrb") as Control
    var mana_orb := ui_root.get_node_or_null("ManaOrb") as Control
    var bottom_hud := ui_root.get_node_or_null("BottomHudFrame") as Panel
    var action_dock := ui_root.get_node_or_null("ActionDock") as Panel
    var basic_slot := ui_root.get_node_or_null("BasicAttackSlot") as Panel
    var flask0 := ui_root.get_node_or_null("FlaskButton0") as Button
    var flask1 := ui_root.get_node_or_null("FlaskButton1") as Button
    if life_orb == null or mana_orb == null or bottom_hud == null or action_dock == null or basic_slot == null or flask0 == null or flask1 == null:
        _fail("ARPG bottom HUD controls did not mount")
        return
    if not life_orb.visible or not mana_orb.visible or not bottom_hud.visible or not action_dock.visible:
        _fail("Desktop ARPG HUD is not visible")
        return

    var viewport_width := get_root().get_visible_rect().size.x
    if life_orb.position.x >= viewport_width * 0.5 or mana_orb.position.x <= viewport_width * 0.5:
        _fail("Life/mana orbs are not anchored to opposite sides")
        return

    var state: Dictionary = scene.call("debug_resource_state")
    if float(state.get("max_mana", 0.0)) < 100.0 or float(state.get("mana_regen", 0.0)) <= 0.0:
        _fail("Mana resource system is not active")
        return
    var costs: Array = state.get("skill_mana_costs", [])
    if costs.size() != 3 or float(costs[0]) <= 0.0:
        _fail("Skill mana costs are missing")
        return

    scene.call("debug_set_mana", 100.0)
    var before_skill := float(scene.call("debug_resource_state").get("mana", 0.0))
    scene.call("_use_skill", 0)
    await process_frame
    var after_skill := float(scene.call("debug_resource_state").get("mana", 0.0))
    if after_skill >= before_skill:
        _fail("Using an active skill did not consume mana")
        return

    scene.call("debug_set_mana", 20.0)
    var before_mana_flask: Dictionary = scene.call("debug_resource_state")
    scene.call("_use_flask", 1)
    var after_mana_flask: Dictionary = scene.call("debug_resource_state")
    if float(after_mana_flask.get("mana", 0.0)) <= float(before_mana_flask.get("mana", 0.0)):
        _fail("Mana flask did not restore mana")
        return
    var before_charges: Array = before_mana_flask.get("flask_charges", [])
    var after_charges: Array = after_mana_flask.get("flask_charges", [])
    if before_charges.size() < 2 or after_charges.size() < 2 or int(after_charges[1]) != int(before_charges[1]) - 1:
        _fail("Mana flask charge was not consumed")
        return

    scene.call("debug_set_hp", 40.0)
    var hp_before := float(scene.call("debug_resource_state").get("hp", 0.0))
    scene.call("_use_flask", 0)
    var hp_after := float(scene.call("debug_resource_state").get("hp", 0.0))
    if hp_after <= hp_before:
        _fail("Life flask did not restore health")
        return

    if not flask0.text.contains("生命藥水") or not flask1.text.contains("魔力藥水"):
        _fail("Desktop flask labels are incomplete")
        return

    print("RIFTFORGED_HUD_SMOKE_OK life-orb/mana-orb/mana-costs/flasks ready")
    quit(0)
