extends SceneTree

const Core = preload("res://scripts/core/game_core.gd")

func _initialize() -> void:
    var game = Core.new()
    game.reset()

    assert(game.tick == 0)
    assert(game.player_pos == Vector3.ZERO)

    for i in range(60):
        game.step(Vector2(1.0, 0.0))

    assert(game.tick == 60)
    assert(absf(game.player_pos.x - 5.0) < 0.001)
    assert(absf(game.get_time_left() - 179.0) < 0.001)

    print("PASS: movement and 60-tick simulation")
    quit(0)