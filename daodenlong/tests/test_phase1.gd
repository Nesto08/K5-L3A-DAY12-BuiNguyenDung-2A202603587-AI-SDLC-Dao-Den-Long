extends SceneTree
const Core = preload("res://scripts/core/game_core.gd")

var failed: bool = false

func ensure(condition: bool, message: String) -> void:
    if not condition:
        failed = true
        push_error("FAIL: " + message)

func _initialize() -> void:
    var g: GameCore = Core.new()
    g.set_seed(42)
    g.reset(1)
    g.apply_scenario({"random_motes":false,"random_shades":false,"random_drifters":false})
    for i in range(60):
        g.step(Vector2(1, 0))
    ensure(g.tick == 60 and g.sim_tick == 60 and absf(g.player_pos.x - 6.0) < 0.001, "Movement: 60 ticks at 6 m/s")
    ensure(absf(g.get_time_left() - 239.0) < 0.001, "Timer: 60 Hz, night 1 initial 240 s (contract v1.3)")

    g.reset(1)
    g.apply_scenario({"random_motes":false,"random_shades":false,"random_drifters":false,
        "player":{"pos":[0,0,0]},"motes":[[0,0,0]]})
    g.step(Vector2.ZERO)
    ensure(g.carried == 1 and g.score == 0, "Pickup does not award score")
    var events: Array[Dictionary] = g.drain_events()
    ensure(events.size() == 1 and events[0]["tick"] == 1 and events[0]["name"] == "mote_picked", "Pickup event tick")

    g.player_pos = g.lanterns[0]["pos"]
    g.step(Vector2.ZERO, 0.0, {"interact":true})
    ensure(g.carried == 0 and int(g.lanterns[0]["deposited"]) == 1 and g.score == 5, "Partial deposit: 1 mote grants 5 points")
    g.step(Vector2.ZERO, 0.0, {"interact":true})
    ensure(g.carried == 0 and int(g.lanterns[0]["deposited"]) == 1 and g.score == 5, "Held interact must not repeat")

    g.reset(1)
    g.apply_scenario({"random_motes":false,"random_shades":false,"random_drifters":false,
        "player":{"pos":[0,0,25],"flames":3,"carried":10},
        "lanterns":[{"id":"L1","pos":[0,0,25],"lit":false,"deposited":0}]})
    ensure(g.events.is_empty() and g.score == 0, "Scenario setup no events or points")
    g.step(Vector2.ZERO, 0.0, {"interact":true})
    ensure(bool(g.lanterns[0]["lit"]) and g.carried == 0 and g.score == 150, "First light: 10 motes * 5 + 100 points")
    ensure(int(g.lanterns[0]["fuel_units"]) == 6000, "First light fills lantern fuel to 100")

    g.reset(1)
    g.apply_scenario({"random_motes":false,"random_shades":false,"random_drifters":false})
    # Exercise damage effect directly; collision and invulnerability are checked separately.
    g._hurt("test")
    g._hurt("test")
    ensure(g.flames == 1 and g.state == "playing", "Flames 3 -> 1")
    g._hurt("test")
    ensure(g.flames == 0 and g.state == "lost", "Loss at zero flames")

    g.reset(1)
    g.apply_scenario({"random_motes":false,"random_shades":false,"random_drifters":false,
        "player":{"pos":[0,0,0],"carried":3},
        "shades":[{"id":"S1","pos":[2,0,0]}]})
    g.step(Vector2.ZERO, 0.0, {"pulse":true})
    ensure(g.carried == 0 and g.shades[0]["state"] == "stunned" and g.score == 5, "Pulse costs 3 and grants 5 stun points")

    if failed:
        quit(1)
        return
    print("PASS: Phase 1 gameplay regression under current contract v1.3")
    quit(0)
