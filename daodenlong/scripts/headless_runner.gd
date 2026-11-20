extends SceneTree

const Core = preload("res://scripts/core/game_core.gd")

var ticks: int = 60
var snapshot_every: int = 10
var night: int = 1
var seed_value: int = 0
var scenario_path: String = ""
var inputs_path: String = ""
var out_path: String = ""
var frames: Array = []
var current_move: Vector2 = Vector2.ZERO
var current_yaw: float = 0.0
var buttons: Dictionary = {"jump":false, "interact":false, "pulse":false}
var output_file: FileAccess = null

func _initialize() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if parse_args(args) != 0 or ticks < 0 or snapshot_every <= 0 or night != 1:
        printerr("Invalid arguments or unsupported night (Phase 1 supports --night 1)")
        quit(2)
        return
    var game: GameCore = Core.new()
    game.set_seed(seed_value)
    game.reset()
    game.setup_default_world()

    if scenario_path != "":
        var scenario: Variant = parse_file(scenario_path)
        if not validate_scenario(scenario):
            printerr("Invalid scenario file: " + scenario_path)
            quit(2)
            return
        game.apply_scenario(scenario)
    if inputs_path != "":
        var loaded: Variant = parse_file(inputs_path)
        if not validate_inputs(loaded):
            printerr("Invalid inputs file: " + inputs_path)
            quit(2)
            return
        frames = loaded["frames"]

    if out_path != "":
        output_file = FileAccess.open(out_path, FileAccess.WRITE)
        if output_file == null:
            printerr("Cannot create output file: " + out_path)
            quit(1)
            return
    emit_snapshot(game)
    var index: int = 0
    for k in range(ticks):
        if game.state != "playing":
            break
        while index < frames.size() and int(frames[index]["tick"]) == k:
            var frame: Dictionary = frames[index]
            if frame.has("move"):
                current_move = Vector2(float(frame["move"][0]), float(frame["move"][1]))
            if frame.has("cam_yaw_deg"):
                current_yaw = float(frame["cam_yaw_deg"])
            for name in ["jump", "interact", "pulse"]:
                if frame.has(name):
                    buttons[name] = frame[name]
            index += 1
        game.step(current_move, current_yaw, buttons)
        for event in game.drain_events():
            emit_line(event)
        if game.tick % snapshot_every == 0:
            emit_snapshot(game)
    emit_line({"type":"end", "ticks":game.tick, "state":game.state, "score":game.score})
    if output_file != null:
        output_file.close()
    quit(0)

func parse_args(args: PackedStringArray) -> int:
    var i: int = 0
    while i < args.size():
        if i + 1 >= args.size():
            return 2
        var option: String = args[i]
        var value: String = args[i+1]
        match option:
            "--ticks":
                if not value.is_valid_int(): return 2
                ticks = int(value)
            "--seed":
                if not value.is_valid_int(): return 2
                seed_value = int(value)
            "--night":
                if not value.is_valid_int(): return 2
                night = int(value)
            "--snapshot-every":
                if not value.is_valid_int(): return 2
                snapshot_every = int(value)
            "--scenario": scenario_path = value
            "--inputs": inputs_path = value
            "--out": out_path = value
            _: return 2
        i += 2
    return 0

func parse_file(path: String) -> Variant:
    if not FileAccess.file_exists(path):
        return null
    var file: FileAccess = FileAccess.open(path, FileAccess.READ)
    if file == null:
        return null
    var parser: JSON = JSON.new()
    if parser.parse(file.get_as_text()) != OK:
        return null
    return parser.data

func is_number(value: Variant) -> bool:
    return (value is int or value is float) and (not is_nan(float(value)) and not is_inf(float(value)))

func valid_pos(value: Variant) -> bool:
    if not (value is Array) or value.size() != 3:
        return false
    for coordinate in value:
        if not is_number(coordinate):
            return false
    return true

func validate_scenario(data: Variant) -> bool:
    if not (data is Dictionary):
        return false
    for flag in ["random_motes", "random_shades"]:
        if data.has(flag) and not (data[flag] is bool): return false
    if data.has("time_left_s") and (not is_number(data["time_left_s"]) or float(data["time_left_s"]) < 0.0): return false
    if data.has("player"):
        var p: Variant = data["player"]
        if not (p is Dictionary): return false
        if p.has("pos") and not valid_pos(p["pos"]): return false
        for f in ["carried", "flames"]:
            if p.has(f) and (not (p[f] is int or p[f] is float) or int(p[f]) < 0 or float(p[f]) != float(int(p[f]))): return false
    if data.has("lanterns"):
        if not (data["lanterns"] is Array): return false
        var seen: Dictionary = {}
        for item in data["lanterns"]:
            if not (item is Dictionary) or not (item.get("id") is String): return false
            if not (item["id"] in ["L1","L2","L3","L4","L5"]) or seen.has(item["id"]): return false
            seen[item["id"]] = true
            if item.has("pos") and not valid_pos(item["pos"]): return false
            if item.has("lit") and not (item["lit"] is bool): return false
            if item.has("deposited") and (not is_number(item["deposited"]) or int(item["deposited"]) < 0 or float(item["deposited"]) != float(int(item["deposited"]))): return false
    if data.has("motes"):
        if not (data["motes"] is Array): return false
        for mote in data["motes"]:
            if mote is Array:
                if not valid_pos(mote): return false
            elif mote is Dictionary:
                if not mote.has("pos") or not valid_pos(mote["pos"]): return false
                if mote.has("id") and not (mote["id"] is String): return false
            else: return false
    if data.has("shades"):
        if not (data["shades"] is Array): return false
        for shade in data["shades"]:
            if not (shade is Dictionary) or not shade.has("pos") or not valid_pos(shade["pos"]): return false
            if shade.has("id") and not (shade["id"] is String): return false
    return true

func validate_inputs(data: Variant) -> bool:
    if not (data is Dictionary) or not (data.get("frames") is Array):
        return false
    var previous: int = -1
    for frame in data["frames"]:
        if not (frame is Dictionary) or not frame.has("tick") or not (frame["tick"] is int or frame["tick"] is float): return false
        var t: int = int(frame["tick"])
        if float(frame["tick"]) != float(t) or t <= previous: return false
        previous = t
        for name in frame.keys():
            if not (name in ["tick", "move", "cam_yaw_deg", "jump", "interact", "pulse"]): return false
        if frame.has("move"):
            var move: Variant = frame["move"]
            if not (move is Array) or move.size() != 2: return false
            for x in move:
                if not is_number(x) or absf(float(x)) > 1.0: return false
        if frame.has("cam_yaw_deg") and not is_number(frame["cam_yaw_deg"]): return false
        for btn in ["jump", "interact", "pulse"]:
            if frame.has(btn) and not (frame[btn] is bool): return false
    return true

func vec3_json(pos: Vector3) -> Array:
    return [snappedf(pos.x, 0.001), snappedf(pos.y, 0.001), snappedf(pos.z, 0.001)]

func emit_snapshot(game: GameCore) -> void:
    var lantern_json: Array = []
    var shade_json: Array = []
    var mote_json: Array = []
    for lantern in game.lanterns:
        lantern_json.append({"id":lantern["id"], "pos":vec3_json(lantern["pos"]), "lit":lantern["lit"], "deposited":lantern["deposited"]})
    for shade in game.shades:
        shade_json.append({"id":shade["id"], "pos":vec3_json(shade["pos"]), "state":shade["state"]})
    for mote in game.motes:
        mote_json.append({"id":mote["id"], "pos":vec3_json(mote["pos"])})
    emit_line({
        "type":"snapshot", "tick":game.tick, "sim_tick":game.tick,
        "state":game.state, "time_left_s":game.get_time_left(), "score":game.score,
        "player":{"pos":vec3_json(game.player_pos), "flames":game.flames, "carried":game.carried},
        "lanterns":lantern_json, "shades":shade_json, "motes_active":game.motes.size(), "motes":mote_json
    })

func emit_line(obj: Dictionary) -> void:
    var line: String = JSON.stringify(obj)
    if output_file == null:
        print(line)
    else:
        output_file.store_line(line)
