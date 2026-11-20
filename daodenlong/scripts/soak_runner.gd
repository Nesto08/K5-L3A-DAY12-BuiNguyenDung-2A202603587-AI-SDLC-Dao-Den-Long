extends SceneTree
const Core = preload("res://scripts/core/game_core.gd")
var seed_value: int = 7
var nights: int = 10
var out_path: String = "soak.json"
var sync_prefix: String = ""

func _initialize() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() % 2 != 0:
        quit(2)
        return
    for i in range(0, args.size(), 2):
        match args[i]:
            "--seed": seed_value = int(args[i + 1])
            "--nights": nights = int(args[i + 1])
            "--out": out_path = args[i + 1]
            "--sync-prefix": sync_prefix = args[i + 1]
            _:
                quit(2)
                return
    if nights < 1:
        quit(2)
        return
    call_deferred("_run")

func _checkpoint(which: String) -> bool:
    print("SOAK_", which.to_upper(), "_RESET")
    if sync_prefix.is_empty():
        return true
    var ready_path: String = sync_prefix + "." + which + ".ready"
    var ack_path: String = sync_prefix + "." + which + ".ack"
    var marker: FileAccess = FileAccess.open(ready_path, FileAccess.WRITE)
    if marker == null:
        printerr("Cannot signal soak reset checkpoint: ", ready_path)
        return false
    marker.store_string("ready\n")
    marker.close()
    var started: int = Time.get_ticks_msec()
    while not FileAccess.file_exists(ack_path):
        if Time.get_ticks_msec() - started > 15000:
            printerr("Timeout waiting for memory checkpoint acknowledgment: ", which)
            return false
        OS.delay_msec(20)
    return true

func _run() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_value
    var game: GameCore = Core.new()
    var results: Array[String] = []
    var start_us: int = Time.get_ticks_usec()
    for i in range(nights):
        var night: int = (i % 3) + 1
        game.set_seed(seed_value + i)
        game.reset(night)
        var move := Vector2.ZERO
        var buttons := {"jump": false, "dash": false, "pulse": false, "interact": false}
        var max_ticks: int = int(game.initial_time_left_s * 60.0) + 1
        for t in range(max_ticks):
            if game.state != "playing":
                break
            if t % 30 == 0:
                move = Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0))
            buttons["jump"] = rng.randf() < 0.05
            buttons["dash"] = rng.randf() < 0.03
            buttons["pulse"] = rng.randf() < 0.02
            buttons["interact"] = rng.randf() < 0.1
            game.step(move, 0.0, buttons)
            game.drain_events()
        results.append(game.state)
        game.reset(night)
        if i == 0 and not _checkpoint("first"):
            quit(1)
            return
        if i == nights - 1 and not _checkpoint("last"):
            quit(1)
            return
    var seconds: float = float(Time.get_ticks_usec() - start_us) / 1000000.0
    var output := {"nights": nights, "crashes": 0, "results": results,
                   "mem_start_mb": null, "mem_end_mb": null, "duration_s": seconds}
    var file := FileAccess.open(out_path, FileAccess.WRITE)
    if file == null:
        printerr("Cannot open soak output")
        quit(1)
        return
    file.store_string(JSON.stringify(output, "  "))
    file.close()
    print("SOAK_RESULT ", JSON.stringify(output))
    quit(0)
