extends SceneTree
const Core = preload("res://scripts/core/game_core.gd")

var failed: bool = false

func ensure(condition: bool, message: String) -> void:
    if not condition:
        failed = true
        push_error("FAIL: " + message)

func _initialize() -> void:
    var g: GameCore = Core.new()
    g.reset()
    for i in range(60):
        g.step(Vector2(1, 0))
    ensure(g.tick == 60 and absf(g.player_pos.x - 5.0) < 0.001, "Movement 60 ticks")
    ensure(absf(g.get_time_left() - 179.0) < 0.001, "Timer 60 Hz")
    g.reset()
    g.motes.append({"id":"M1", "pos":Vector3.ZERO})
    g.step(Vector2.ZERO)
    ensure(g.carried == 1 and g.score == 0, "Pickup does not award deposit points")
    var events: Array[Dictionary] = g.drain_events()
    ensure(events.size() == 1 and events[0]["tick"] == 1, "Pickup event tick")
    g.player_pos = g.lanterns[0]["pos"]
    g.step(Vector2.ZERO, 0.0, {"interact":true})
    ensure(g.carried == 0 and g.lanterns[0]["deposited"] == 1 and g.score == 10, "Partial deposit")
    g.step(Vector2.ZERO, 0.0, {"interact":true})
    ensure(g.score == 10, "Held interact must not repeat")
    g.reset()
    g.apply_scenario({"player":{"pos":[0,0,0], "flames":3, "carried":3}, "motes":[[0,0,5]], "shades":[], "lanterns":[{"id":"L1", "pos":[0,0,0]}], "time_left_s":300})
    ensure(g.events.is_empty() and g.score == 0, "Scenario setup no events or points")
    ensure(g.motes.size() == 1 and absf(g.get_time_left()-300.0)<0.001, "Scenario mote and timer")
    g.step(Vector2.ZERO, 0.0, {"interact":true})
    ensure(g.lanterns[0]["lit"] and g.score == 130, "Lantern points")
    g.reset()
    g.take_damage(20)
    g.take_damage(20)
    ensure(g.flames == 1 and g.state == "playing", "Flames 3 -> 1")
    g.take_damage(20)
    ensure(g.flames == 0 and g.state == "lost", "Loss at zero flames")
    g.reset()
    g.carried = 2
    g.add_shade("S1", Vector3(2,0,0))
    g.step(Vector2.ZERO, 0.0, {"pulse":true})
    ensure(g.carried == 0 and g.shades[0]["state"] == "stunned", "Pulse stun")
    if failed:
        quit(1)
        return
    print("PASS: Phase 1 core, movement, partial deposits, inputs, flames, pulse")
    quit(0)
