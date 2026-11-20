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
var buttons: Dictionary = {"jump":false,"interact":false,"pulse":false,"dash":false,"pause":false}
var output_file: FileAccess = null

func _initialize() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if parse_args(args) != 0 or ticks < 0 or snapshot_every <= 0 or night < 1 or night > 3:
        printerr("Invalid arguments. --night supports 1, 2 or 3")
        quit(2)
        return
    var game: GameCore = Core.new()
    game.set_seed(seed_value)
    game.reset(night)
    if scenario_path != "":
        var scenario: Variant = parse_file(scenario_path)
        if not validate_scenario(scenario):
            printerr("Invalid scenario: " + scenario_path)
            quit(2)
            return
        game.apply_scenario(scenario)
    if inputs_path != "":
        var loaded: Variant = parse_file(inputs_path)
        if not validate_inputs(loaded):
            printerr("Invalid inputs: " + inputs_path)
            quit(2)
            return
        frames = loaded["frames"]
    if out_path != "":
        output_file = FileAccess.open(out_path,FileAccess.WRITE)
        if output_file == null:
            printerr("Cannot open --out: " + out_path)
            quit(1)
            return
    emit_snapshot(game)
    var frame_index: int = 0
    for k in range(ticks):
        if game.state in ["won","lost"]: break
        while frame_index < frames.size() and int(frames[frame_index]["tick"]) == k:
            var frame: Dictionary = frames[frame_index]
            if frame.has("move"):
                current_move = Vector2(float(frame["move"][0]),float(frame["move"][1]))
            if frame.has("cam_yaw_deg"): current_yaw = float(frame["cam_yaw_deg"])
            for key in buttons.keys():
                if frame.has(key): buttons[key] = bool(frame[key])
            frame_index += 1
        game.step(current_move,current_yaw,buttons)
        for event in game.drain_events(): emit_line(event)
        if game.tick % snapshot_every == 0: emit_snapshot(game)
    emit_line({"type":"end","ticks":game.tick,"sim_tick":game.sim_tick,"state":game.state,"score":game.score,"night":game.night})
    if output_file != null: output_file.close()
    quit(0)

func parse_args(args: PackedStringArray) -> int:
    var i: int = 0
    while i < args.size():
        if i+1 >= args.size(): return 2
        var value: String = args[i+1]
        match args[i]:
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
    if not FileAccess.file_exists(path): return null
    var file: FileAccess = FileAccess.open(path,FileAccess.READ)
    if file == null: return null
    var json: JSON = JSON.new()
    if json.parse(file.get_as_text()) != OK: return null
    return json.data

func is_number(v: Variant) -> bool:
    return (v is int or v is float) and not is_nan(float(v)) and not is_inf(float(v))

func valid_pos(v: Variant) -> bool:
    if not (v is Array) or v.size() != 3: return false
    for x in v:
        if not is_number(x): return false
    return true

func valid_nonnegative_integer(v: Variant) -> bool:
    return is_number(v) and float(v) >= 0 and float(v) == float(int(v))

func validate_scenario(data: Variant) -> bool:
    if not (data is Dictionary): return false
    for key in ["random_motes","random_shades","random_drifters"]:
        if data.has(key) and not (data[key] is bool): return false
    if data.has("time_left_s") and (not is_number(data["time_left_s"]) or float(data["time_left_s"]) < 0): return false
    if data.has("score") and not valid_nonnegative_integer(data["score"]): return false
    if data.has("player"):
        var p: Variant = data["player"]
        if not (p is Dictionary): return false
        if p.has("pos") and not valid_pos(p["pos"]): return false
        if p.has("vel") and not valid_pos(p["vel"]): return false
        if p.has("grounded") and not (p["grounded"] is bool): return false
        for key in ["carried","flames","invuln_ticks","dash_ticks","dash_c_ticks","pulse_cd_ticks","charm_ticks","successful_lights"]:
            if p.has(key) and not valid_nonnegative_integer(p[key]): return false
    if data.has("lanterns"):
        if not (data["lanterns"] is Array): return false
        var seen: Dictionary = {}
        for item in data["lanterns"]:
            if not (item is Dictionary) or not (item.get("id") is String): return false
            var id: String = item["id"]
            if not id.begins_with("L") or not id.substr(1).is_valid_int() or int(id.substr(1)) < 1 or int(id.substr(1)) > (7 if night == 3 else (6 if night == 2 else 5)) or seen.has(id): return false
            seen[id] = true
            if item.has("pos") and not valid_pos(item["pos"]): return false
            if item.has("lit") and not (item["lit"] is bool): return false
            if item.has("deposited") and not valid_nonnegative_integer(item["deposited"]): return false
            if item.has("ever_lit") and not (item["ever_lit"] is bool): return false
            if item.has("fuel") and (not is_number(item["fuel"]) or float(item["fuel"]) < 0 or float(item["fuel"]) > 100): return false
            if item.has("relit_count") and not valid_nonnegative_integer(item["relit_count"]): return false
    for key in ["motes","shades","drifters","charms"]:
        if not data.has(key): continue
        if not (data[key] is Array): return false
        for item in data[key]:
            if key == "motes" and item is Array:
                if not valid_pos(item): return false
                continue
            if not (item is Dictionary) or not item.has("pos") or not valid_pos(item["pos"]): return false
            if item.has("id") and not (item["id"] is String): return false
            if item.has("active") and not (item["active"] is bool): return false
            if item.has("target_lantern_id") and not (item["target_lantern_id"] is String): return false
            for field in ["ttl","stun_ticks","push_ticks","recoil","chase_ticks"]:
                if item.has(field) and not valid_nonnegative_integer(item[field]): return false
    return true

func validate_inputs(data: Variant) -> bool:
    if not (data is Dictionary) or not (data.get("frames") is Array): return false
    var last_tick: int = -1
    for frame in data["frames"]:
        if not (frame is Dictionary) or not frame.has("tick") or not valid_nonnegative_integer(frame["tick"]): return false
        var t: int = int(frame["tick"])
        if t <= last_tick: return false
        last_tick = t
        for key in frame.keys():
            if not (key in ["tick","move","cam_yaw_deg","jump","interact","pulse","dash","pause"]): return false
        if frame.has("move"):
            var move: Variant = frame["move"]
            if not (move is Array) or move.size() != 2: return false
            for x in move:
                if not is_number(x) or absf(float(x)) > 1.0: return false
        if frame.has("cam_yaw_deg") and not is_number(frame["cam_yaw_deg"]): return false
        for key in ["jump","interact","pulse","dash","pause"]:
            if frame.has(key) and not (frame[key] is bool): return false
    return true

func emit_snapshot(game: GameCore) -> void:
    var lantern_json: Array = []
    var shade_json: Array = []
    var mote_json: Array = []
    var drifter_json: Array = []
    var charm_json: Array = []
    for item in game.lanterns:
        lantern_json.append({"id":item["id"],"pos":Core.vec3_json(item["pos"]),"lit":item["lit"],"deposited":item["deposited"],"fuel":game._fuel_visible(item),"ever_lit":item["ever_lit"],"relit_count":item["relit_count"]})
    for item in game.shades:
        shade_json.append({"id":item["id"],"pos":Core.vec3_json(item["pos"]),"state":item["state"],"stun_ticks":item["stun_ticks"],"recoil":item["recoil"],"target_lantern_id":item.get("target_lantern_id","")})
    for item in game.motes:
        mote_json.append({"id":item["id"],"pos":Core.vec3_json(item["pos"]),"kind":item.get("kind","random"),"ttl":item.get("ttl",-1)})
    for item in game.drifters:
        drifter_json.append({"id":item["id"],"pos":Core.vec3_json(item["pos"]),"state":item["state"],"chase_ticks":item["chase_ticks"]})
    for item in game.charms:
        charm_json.append({"id":item["id"],"pos":Core.vec3_json(item["pos"]),"active":item["active"]})
    emit_line({
        "type":"snapshot","tick":game.tick,"sim_tick":game.sim_tick,"night":game.night,
        "state":game.state,"time_left_s":snappedf(game.get_time_left(),0.001),"score":game.score,
        "player":{"pos":Core.vec3_json(game.player_pos),"vel":[0,snappedf(game.player_velocity_y,0.001),0],"grounded":game.grounded,
        "flames":game.flames,"carried":game.carried,"capacity":game.get_capacity(),"invuln_ticks":game.invuln_ticks,
        "dash_ticks":game.dash_ticks,"dash_c_ticks":game.dash_cooldown,"pulse_cd_ticks":game.pulse_cooldown,
        "charm_ticks":game.charm_ticks},
        "lanterns":lantern_json,"shades":shade_json,"motes_active":game.motes.size(),"motes":mote_json,
        "drifters":drifter_json,"charms":charm_json,"wind":{"x":snappedf(game.weather_wind.x,0.001),"z":snappedf(game.weather_wind.y,0.001),"ticks":game.wind_tick}
    })

func emit_line(obj: Dictionary) -> void:
    var line: String = JSON.stringify(obj)
    if output_file == null: print(line)
    else: output_file.store_line(line)
