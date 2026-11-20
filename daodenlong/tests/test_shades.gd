
extends SceneTree

const Core = preload("res://scripts/core/game_core.gd")

func _initialize() -> void:
    var game = Core.new()

    # Test 1: Shade follows the player
    game.reset()
    game.add_shade("S1", Vector3(5, 0, 0))

    var old_x: float = game.shades[0]["pos"].x
    game.step(Vector2.ZERO)

    assert(game.shades[0]["pos"].x < old_x)
    print("PASS: shade chase")

    # Test 2: Collision causes damage
    game.reset()
    game.add_shade("S1", Vector3(0.5, 0, 0))

    game.step(Vector2.ZERO)
    assert(game.player_hp == 80)

    # Damage cooldown prevents immediate repeated damage
    game.step(Vector2.ZERO)
    assert(game.player_hp == 80)

    print("PASS: shade damage and cooldown")

    # Test 3: Pulse stuns a shade
    game.reset()
    game.carried = 2
    game.add_shade("S1", Vector3(3, 0, 0))

    assert(game.use_pulse())
    assert(game.carried == 0)
    assert(game.shades[0]["state"] == "stunned")
    assert(game.shades[0]["stun_ticks"] == 120)

    print("PASS: pulse stun")

    # Test 4: Lit lantern creates a safe zone
    game.reset()
    game.lanterns[0]["lit"] = true

    var lantern_pos: Vector3 = game.lanterns[0]["pos"]
    assert(game.is_inside_safe_zone(lantern_pos))

    game.add_shade("S1", lantern_pos)
    game.step(Vector2.ZERO)

    var shade_pos: Vector3 = game.shades[0]["pos"]
    assert(
        game.distance_xz(shade_pos, lantern_pos)
        >= game.SAFE_RADIUS - 0.001
    )

    print("PASS: lantern safe zone")

    # Test 5: HP reaching zero means defeat
    game.reset()
    game.take_damage(100)

    assert(game.player_hp == 0)
    assert(game.state == "lost")

    print("PASS: lose condition")
    print("ALL SHADE TESTS PASSED")

    quit(0)
