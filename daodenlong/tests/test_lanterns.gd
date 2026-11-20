
extends SceneTree

const Core = preload("res://scripts/core/game_core.gd")

func _initialize() -> void:
    var game = Core.new()
    game.reset()

    # Test 1: Five lanterns exist
    assert(game.lanterns.size() == 5)

    # Test 2: Create three motes
    # Use append to preserve Array[Dictionary] type
    game.motes.clear()

    game.motes.append({
        "id": "M1",
        "pos": Vector3.ZERO
    })

    game.motes.append({
        "id": "M2",
        "pos": Vector3(0.5, 0, 0)
    })

    game.motes.append({
        "id": "M3",
        "pos": Vector3(1, 0, 0)
    })

    # Test 3: Collect nearby motes
    game.pickup_motes()

    assert(game.carried == 3)
    assert(game.motes.is_empty())
    assert(game.score == 30)

    # Test 4: Light the first lantern
    game.player_pos = Vector3(0, 0, -12)
    game.interact_lantern()

    assert(game.lanterns[0]["lit"] == true)
    assert(game.carried == 0)
    assert(game.score == 130)
    assert(game.state == "playing")

    print("PASS: mote pickup and lantern interaction")
    quit(0)
