extends RefCounted
class_name GameCore

# Day 12 Ticket-02 / deterministic, fixed-60-Hz Game Core.
const TICK_RATE: int = 60
const DT: float = 1.0 / 60.0
const PLAYER_SPEED: float = 6.0
const SPRINT_SPEED: float = 6.0
const JUMP_SPEED: float = 7.0
const GRAVITY: float = 20.0
const DASH_SPEED: float = 14.0
const DASH_TICKS: int = 12
const DASH_COOLDOWN_TICKS: int = 90
const CARRY_CAPACITY: int = 10
const PICKUP_RADIUS: float = 1.0
const PICKUP_HEIGHT: float = 1.5
const LANTERN_COST: int = 10
const INTERACT_RADIUS: float = 2.0
const SAFE_RADIUS: float = 6.0
const PULSE_COST: int = 3
const PULSE_RADIUS: float = 5.0
const PULSE_COOLDOWN_TICKS: int = 180
const PULSE_STUN_TICKS: int = 120
const PULSE_PUSH_M: float = 4.0
const PULSE_PUSH_TICKS: int = 15
const SHADE_SPEED: float = 4.0
const SHADE_HIT_RADIUS: float = 1.0
const INVULN_TICKS: int = 90
const MAX_FLAMES: int = 3
const SCORE_PER_DEPOSIT: int = 10
const SCORE_PER_LANTERN: int = 100
const SCORE_PER_STUN: int = 5
const SCORE_PER_SECOND_LEFT: int = 2
const SCORE_PER_FLAME_LEFT: int = 50
const NIGHT_DURATIONS: Array = [300.0, 330.0, 360.0]

var tick: int = 0
var sim_tick: int = 0
var night: int = 1
var state: String = "playing"
var player_pos: Vector3 = Vector3.ZERO
var player_velocity_y: float = 0.0
var grounded: bool = true
var flames: int = MAX_FLAMES
var carried: int = 0
var score: int = 0
var score_nights: int = 0
var initial_time_left_s: float = 300.0
var pulse_cooldown: int = 0
var dash_cooldown: int = 0
var dash_ticks: int = 0
var dash_dir: Vector2 = Vector2(0, -1)
var invuln_ticks: int = 0
var charm_ticks: int = 0
var charm_cooldown: int = 0
var charm_active: bool = false
var previous_buttons: Dictionary = {}
var lanterns: Array[Dictionary] = []
var motes: Array[Dictionary] = []
var shades: Array[Dictionary] = []
var drifters: Array[Dictionary] = []
var charms: Array[Dictionary] = []
var events: Array[Dictionary] = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var current_seed: int = 0
var mote_serial: int = 0
var shade_serial: int = 0
var drifter_serial: int = 0
var drop_serial: int = 0
var random_motes: bool = true
var random_shades: bool = true
var random_drifters: bool = true
var last_movement: Vector2 = Vector2(0, -1)
var weather_wind: Vector2 = Vector2.ZERO
var wind_tick: int = 0
var wind_warned: bool = false
var lantern_count: int = 5
var night_spawned: bool = false
var launch_ticks: int = 0
var launch_dir: Vector2 = Vector2.ZERO

func set_seed(value: int) -> void:
    current_seed = value
    rng.seed = value

func reset(next_night: int = 1) -> void:
    night = clampi(next_night, 1, 3)
    tick = 0
    sim_tick = 0
    state = "playing"
    player_pos = Vector3(0,6,0) if night == 3 else Vector3.ZERO
    player_velocity_y = 0.0
    grounded = true
    flames = MAX_FLAMES
    carried = 0
    score = 0
    score_nights = 0
    initial_time_left_s = float(NIGHT_DURATIONS[night - 1])
    pulse_cooldown = 0
    dash_cooldown = 0
    dash_ticks = 0
    invuln_ticks = 0
    charm_ticks = 0
    charm_cooldown = 0
    charm_active = false
    previous_buttons.clear()
    lanterns.clear()
    motes.clear()
    shades.clear()
    drifters.clear()
    charms.clear()
    events.clear()
    mote_serial = 0
    shade_serial = 0
    drifter_serial = 0
    drop_serial = 0
    random_motes = true
    random_shades = true
    random_drifters = true
    last_movement = Vector2(0, -1)
    weather_wind = Vector2.ZERO
    wind_tick = 0
    wind_warned = false
    night_spawned = false
    launch_ticks = 0
    launch_dir = Vector2.ZERO
    rng.seed = current_seed + (night - 1) * 10007
    setup_lanterns()
    setup_default_world()

func setup_lanterns() -> void:
    lanterns.clear()
    var locations: Array = []
    if night == 1:
        locations = [Vector3(0,0,25),Vector3(23.8,0,7.7),Vector3(14.7,0,-20.2),Vector3(-14.7,0,-20.2),Vector3(-23.8,0,7.7)]
    elif night == 2:
        locations = [Vector3(0,0,20),Vector3(17,0,-10),Vector3(-17,0,-10),Vector3(70,0,20),Vector3(87,0,-10),Vector3(53,0,-10)]
    else:
        locations = [Vector3(0,6,6),Vector3(18,3,10),Vector3(-18,3,10),Vector3(35,0,-10),Vector3(-35,0,-10),Vector3(20,0,-35),Vector3(-20,0,-35)]
    lantern_count = locations.size()
    for i in range(locations.size()):
        lanterns.append({"id":"L" + str(i + 1),"pos":locations[i],"lit":false,"deposited":0})

func _mote_spawn_points() -> Array[Vector3]:
    var result: Array[Vector3] = []
    if night == 1:
        for i in range(8):
            var a: float = deg_to_rad(float(i) * 45.0)
            result.append(Vector3(cos(a)*12,0,sin(a)*12))
        for i in range(16):
            var a: float = deg_to_rad(22.5 + float(i)*22.5)
            result.append(Vector3(cos(a)*33,0,sin(a)*33))
    elif night == 2:
        for center in [0.0,70.0]:
            for i in range(4):
                var a: float = deg_to_rad(float(i)*90.0)
                result.append(Vector3(center + cos(a)*10,0,sin(a)*10))
            for i in range(8):
                var a: float = deg_to_rad(22.5 + float(i)*45.0)
                result.append(Vector3(center + cos(a)*22,0,sin(a)*22))
    else:
        for i in range(18):
            var a: float = deg_to_rad(float(i)*20.0)
            result.append(Vector3(cos(a)*34,0,sin(a)*34))
        for i in range(8):
            var a: float = deg_to_rad(20.0 + float(i)*40.0)
            result.append(Vector3(cos(a)*18,3,sin(a)*18))
        for i in range(4):
            var a: float = deg_to_rad(45.0 + float(i)*90.0)
            result.append(Vector3(cos(a)*5,6,sin(a)*5))
    return result

func setup_default_world() -> void:
    motes.clear()
    shades.clear()
    drifters.clear()
    charms.clear()
    _spawn_mote_batch(20, false)
    if night >= 2:
        charms.append({"id":"C1", "pos":Vector3(12,0,0), "active":true})
        charms.append({"id":"C2", "pos":Vector3(68,0,0) if night == 2 else Vector3(-12,3,0), "active":true})

func _spawn_mote_batch(count: int, emit_spawn: bool = true) -> void:
    var points: Array[Vector3] = _mote_spawn_points()
    var valid: Array[Vector3] = []
    for point in points:
        var occupied: bool = false
        for mote in motes:
            if distance_xz(point,mote["pos"]) < 0.01:
                occupied = true
                break
        if not occupied: valid.append(point)
    for _i in range(count):
        if valid.is_empty() or motes.size() >= 30: return
        var chosen: int = rng.randi_range(0,valid.size()-1)
        var pos: Vector3 = valid[chosen]
        valid.remove_at(chosen)
        mote_serial += 1
        var identity: String = "M"+str(mote_serial)
        motes.append({"id":identity,"pos":pos,"kind":"random","ttl":-1})
        if emit_spawn: emit_event("mote_spawned",{"id":identity,"pos":vec3_json(pos)})

func add_shade(identity: String, pos: Vector3) -> void:
    shades.append({"id":identity,"pos":pos,"state":"idle","stun_ticks":0,"push_ticks":0,"push_dir":Vector2.ZERO,"recoil":0,"spawn_pos":pos})

func add_drifter(identity: String, pos: Vector3) -> void:
    drifters.append({"id":identity,"pos":pos,"state":"idle","chase_ticks":0,"stun_ticks":0,"steal_cooldown":0,"spawn_pos":pos})

static func vec3_from_array(a: Array) -> Vector3:
    return Vector3(float(a[0]),float(a[1]),float(a[2]))

static func vec3_json(pos: Vector3) -> Array:
    return [snappedf(pos.x,0.001),snappedf(pos.y,0.001),snappedf(pos.z,0.001)]

func distance_xz(a: Vector3, b: Vector3) -> float:
    return Vector2(a.x-b.x,a.z-b.z).length()

func get_time_left() -> float:
    return maxf(0.0,initial_time_left_s - float(sim_tick)/60.0)

func emit_event(name: String, data: Dictionary = {}) -> void:
    var event: Dictionary = {"type":"event", "tick":tick,"name":name}
    for key in data:
        event[key] = data[key]
    event["data"] = data.duplicate(true)
    events.append(event)

func drain_events() -> Array[Dictionary]:
    var result: Array[Dictionary] = events.duplicate(true)
    events.clear()
    return result

func _scenario_set_cooldown(p: Dictionary, key: String, field: String) -> void:
    if p.has(key):
        set(field,int(p[key]))

func apply_scenario(scenario: Dictionary) -> void:
    if scenario.has("player"):
        var p: Dictionary = scenario["player"]
        if p.has("pos"): player_pos = vec3_from_array(p["pos"])
        if p.has("carried"): carried = int(p["carried"])
        if p.has("flames"): flames = int(p["flames"])
        if p.has("vel"): player_velocity_y = float(p["vel"][1])
        if p.has("grounded"): grounded = bool(p["grounded"])
        if p.has("invuln_ticks"): invuln_ticks = int(p["invuln_ticks"])
        if p.has("dash_ticks"): dash_ticks = int(p["dash_ticks"])
        if p.has("dash_c_ticks"): dash_cooldown = int(p["dash_c_ticks"])
        if p.has("pulse_cd_ticks"): pulse_cooldown = int(p["pulse_cd_ticks"])
        if p.has("charm_ticks"): charm_ticks = int(p["charm_ticks"])
    if scenario.has("time_left_s"): initial_time_left_s = float(scenario["time_left_s"])
    if scenario.has("score"): score = int(scenario["score"])
    if scenario.has("lanterns"):
        for update in scenario["lanterns"]:
            for lantern in lanterns:
                if str(lantern["id"]) == str(update["id"]):
                    if update.has("pos"): lantern["pos"] = vec3_from_array(update["pos"])
                    if update.has("lit"): lantern["lit"] = bool(update["lit"])
                    if update.has("deposited"): lantern["deposited"] = int(update["deposited"])
    random_motes = bool(scenario.get("random_motes",true))
    random_shades = bool(scenario.get("random_shades",true))
    random_drifters = bool(scenario.get("random_drifters",true))
    if not random_motes: motes.clear()
    if not random_shades: shades.clear()
    if not random_drifters: drifters.clear()
    if scenario.has("motes"):
        motes.clear()
        var idx: int = 0
        for mote in scenario["motes"]:
            idx += 1
            var m: Dictionary = {}
            if mote is Array:
                m = {"id":"M"+str(idx),"pos":vec3_from_array(mote),"kind":"scenario","ttl":-1}
            else:
                m = {"id":str(mote.get("id","M"+str(idx))),"pos":vec3_from_array(mote["pos"]),"kind":str(mote.get("kind","scenario")),"ttl":int(mote.get("ttl",-1))}
            motes.append(m)
    if scenario.has("shades"):
        shades.clear()
        var idx: int = 0
        for shade in scenario["shades"]:
            idx += 1
            add_shade(str(shade.get("id","S"+str(idx))),vec3_from_array(shade["pos"]))
            var new_shade: Dictionary = shades.back()
            for property in ["state","stun_ticks","push_ticks","recoil"]:
                if shade.has(property): new_shade[property] = shade[property]
    if scenario.has("drifters"):
        drifters.clear()
        var idx: int = 0
        for drifter in scenario["drifters"]:
            idx += 1
            add_drifter(str(drifter.get("id","D"+str(idx))),vec3_from_array(drifter["pos"]))
            var d: Dictionary = drifters.back()
            if drifter.has("state"): d["state"] = str(drifter["state"])
            if drifter.has("chase_ticks"): d["chase_ticks"] = int(drifter["chase_ticks"])
    if scenario.has("charms"):
        charms.clear()
        var idx: int = 0
        for charm in scenario["charms"]:
            idx += 1
            charms.append({"id":str(charm.get("id","C"+str(idx))),"pos":vec3_from_array(charm["pos"]),"active":bool(charm.get("active",true))})
    events.clear()

func _edge(buttons: Dictionary, name: String) -> bool:
    return bool(buttons.get(name,false)) and not bool(previous_buttons.get(name,false))

func _tick_timers() -> void:
    pulse_cooldown = maxi(0,pulse_cooldown-1)
    dash_cooldown = maxi(0,dash_cooldown-1)
    invuln_ticks = maxi(0,invuln_ticks-1)
    charm_cooldown = maxi(0,charm_cooldown-1)
    charm_ticks = maxi(0,charm_ticks-1)
    charm_active = charm_ticks > 0
    for mote in motes:
        if int(mote.get("ttl",-1)) > 0: mote["ttl"] = int(mote["ttl"]) - 1
    var i: int = motes.size()-1
    while i >= 0:
        if int(motes[i].get("ttl",-1)) == 0: motes.remove_at(i)
        i -= 1
    for shade in shades:
        shade["recoil"] = maxi(0,int(shade.get("recoil",0))-1)
        if int(shade["stun_ticks"]) > 0: shade["stun_ticks"] = int(shade["stun_ticks"])-1
        if int(shade["push_ticks"]) > 0:
            var pos: Vector3 = shade["pos"]
            var d: Vector2 = shade["push_dir"]
            pos.x += d.x * PULSE_PUSH_M / float(PULSE_PUSH_TICKS)
            pos.z += d.y * PULSE_PUSH_M / float(PULSE_PUSH_TICKS)
            shade["pos"] = _project_safe(pos)
            shade["push_ticks"] = int(shade["push_ticks"])-1
    for drifter in drifters:
        drifter["stun_ticks"] = maxi(0,int(drifter["stun_ticks"])-1)
        drifter["steal_cooldown"] = maxi(0,int(drifter["steal_cooldown"])-1)

func _surface_height(pos: Vector3) -> float:
    if night != 3: return 0.0
    var r: float = Vector2(pos.x,pos.z).length()
    if r <= 8.0: return 6.0
    if r >= 12.0 and r <= 24.0: return 3.0
    return 0.0

func _is_supported(pos: Vector3) -> bool:
    var p: Vector2 = Vector2(pos.x,pos.z)
    if night == 1: return p.length() <= 40.0
    if night == 2:
        return p.length() <= 28.0 or (p-Vector2(70,0)).length() <= 28.0 or (pos.x >= 26 and pos.x <= 44 and absf(pos.z) <= 1)
    var r: float = p.length()
    if r > 45.0: return false
    var angle: float = fposmod(rad_to_deg(atan2(pos.z,pos.x)),360.0)
    if r >= 30 and r <= 45 and (absf(angle-30.0) < 1.5 or absf(angle-150.0) < 1.5): return false
    return true

func _move_player(move_input: Vector2, yaw: float, buttons: Dictionary) -> void:
    var v: Vector2 = move_input.limit_length(1.0)
    var a: float = deg_to_rad(yaw)
    var world: Vector2 = Vector2(v.x*cos(a)+v.y*sin(a),-v.x*sin(a)+v.y*cos(a))
    if world.length() > 0.001: last_movement = world.normalized()
    if _edge(buttons,"dash") and dash_cooldown == 0:
        dash_ticks = DASH_TICKS
        dash_cooldown = DASH_COOLDOWN_TICKS
        dash_dir = last_movement
        emit_event("dash",{"ticks":DASH_TICKS})
    var velocity: Vector2 = world*PLAYER_SPEED
    if dash_ticks > 0:
        velocity = dash_dir*DASH_SPEED
        dash_ticks -= 1
    if not charm_active and weather_wind.length() > 0.0: velocity += weather_wind
    if launch_ticks > 0:
        velocity = launch_dir*(24.0 if night == 2 else 8.0)
        launch_ticks -= 1
    player_pos.x += velocity.x*DT
    player_pos.z += velocity.y*DT
    var height: float = _surface_height(player_pos)
    if _edge(buttons,"jump") and grounded:
        player_velocity_y = JUMP_SPEED
        grounded = false
    # Deterministic launch pads, active only on ground contact.
    if grounded and night == 2:
        for pad in [Vector3(20,0,18),Vector3(50,0,-18)]:
            if distance_xz(player_pos,pad) <= 1.0:
                var toward: float = 1.0 if pad.x < 35.0 else -1.0
                dash_dir = Vector2(toward,0)
                dash_ticks = 0
                player_velocity_y = 14.0
                grounded = false
                # Launch horizontal velocity is applied over approximately 1.4 s.
                launch_ticks = 84
                launch_dir = Vector2(toward,0)
                emit_event("launch_pad",{"pos":vec3_json(pad)})
                break
    elif grounded and night == 3 and distance_xz(player_pos,Vector3(0,3,13)) <= 1.0:
        player_velocity_y = 12.0
        grounded = false
        launch_ticks = 60
        launch_dir = Vector2(0,-1)
        emit_event("launch_pad",{"pos":[0,3,13]})
    if not grounded:
        player_velocity_y -= GRAVITY*DT
        player_pos.y += player_velocity_y*DT
        if player_velocity_y <= 0 and player_pos.y <= height and _is_supported(player_pos):
            player_pos.y = height
            player_velocity_y = 0
            grounded = true
    elif _is_supported(player_pos):
        player_pos.y = height
    else:
        grounded = false
    if player_pos.y < -10.0:
        finish_game("lost","fall")

func _pickup() -> void:
    var i: int = 0
    while i < motes.size() and carried < CARRY_CAPACITY:
        var m: Dictionary = motes[i]
        if distance_xz(player_pos,m["pos"]) <= PICKUP_RADIUS and absf(player_pos.y-float(m["pos"].y)) <= PICKUP_HEIGHT:
            carried += 1
            motes.remove_at(i)
            emit_event("mote_picked",{"mote_id":m["id"],"carried":carried})
        else: i += 1
    for charm in charms:
        if bool(charm["active"]) and distance_xz(player_pos,charm["pos"]) <= 1.0:
            charm["active"] = false
            charm_ticks = 600
            charm_active = true
            emit_event("charm_picked",{"charm_id":charm["id"],"charm_ticks":600})

func interact_lantern() -> void:
    if carried <= 0 or state != "playing": return
    var choice: Dictionary = {}
    var best: float = INF
    for lantern in lanterns:
        if lantern["lit"]: continue
        var pos: Vector3 = lantern["pos"]
        var distance: float = distance_xz(player_pos,pos)
        if distance <= INTERACT_RADIUS and absf(player_pos.y-pos.y) <= 2.0:
            if distance < best or (is_equal_approx(distance,best) and (choice.is_empty() or str(lantern["id"]) < str(choice["id"]))):
                choice = lantern
                best = distance
    if choice.is_empty(): return
    var amount: int = mini(carried,LANTERN_COST-int(choice["deposited"]))
    if amount <= 0: return
    carried -= amount
    choice["deposited"] = int(choice["deposited"]) + amount
    score += amount*SCORE_PER_DEPOSIT
    emit_event("deposit",{"lantern_id":choice["id"],"amount":amount,"deposited":choice["deposited"]})
    if int(choice["deposited"]) == LANTERN_COST:
        choice["lit"] = true
        score += SCORE_PER_LANTERN
        emit_event("lantern_lit",{"lantern_id":choice["id"]})
        _check_win()

func _safe_center(pos: Vector3) -> Vector3:
    for lantern in lanterns:
        if bool(lantern["lit"]) and distance_xz(pos,lantern["pos"]) <= SAFE_RADIUS:
            return lantern["pos"]
    return Vector3(INF,INF,INF)

func _project_safe(pos: Vector3) -> Vector3:
    var adjusted: Vector3 = pos
    for _attempt in range(12):
        var center: Vector3 = _safe_center(adjusted)
        if is_inf(center.x): break
        var d: Vector2 = Vector2(adjusted.x-center.x, adjusted.z-center.z)
        if d.length() < 0.0001: d = Vector2.RIGHT
        d = d.normalized()*(SAFE_RADIUS+0.001)
        adjusted.x = center.x+d.x
        adjusted.z = center.z+d.y
    return adjusted

func is_inside_safe_zone(pos: Vector3) -> bool:
    return not is_inf(_safe_center(pos).x)

func _pulse() -> void:
    if carried < PULSE_COST or pulse_cooldown > 0: return
    carried -= PULSE_COST
    pulse_cooldown = PULSE_COOLDOWN_TICKS
    var stunned: Array[String] = []
    for shade in shades:
        var pos: Vector3 = shade["pos"]
        if distance_xz(pos,player_pos) <= PULSE_RADIUS and absf(pos.y-player_pos.y) <= 1.5:
            shade["stun_ticks"] = PULSE_STUN_TICKS
            shade["state"] = "stunned"
            var d: Vector2 = Vector2(pos.x-player_pos.x,pos.z-player_pos.z)
            if d.length() < 0.00001: d = Vector2.RIGHT
            shade["push_dir"] = d.normalized()
            shade["push_ticks"] = PULSE_PUSH_TICKS
            stunned.append(str(shade["id"]))
            score += SCORE_PER_STUN
    emit_event("pulse",{"stunned_ids":stunned,"cost":PULSE_COST})

func _shade_step() -> void:
    for shade in shades:
        var pos: Vector3 = shade["pos"]
        if int(shade.get("stun_ticks",0)) > 0:
            shade["state"] = "stunned"
            continue
        var distance: float = distance_xz(pos,player_pos)
        var was_chasing: bool = str(shade["state"]) == "chase"
        if distance > (18.0 if was_chasing else 12.0):
            shade["state"] = "idle"
        else:
            shade["state"] = "chase"
            if distance > 0.0001:
                var dir: Vector2 = Vector2(player_pos.x-pos.x,player_pos.z-pos.z).normalized()
                var speed: float = 4.5 if night == 3 else SHADE_SPEED
                pos.x += dir.x*speed*DT
                pos.z += dir.y*speed*DT
                pos = _project_safe(pos)
                shade["pos"] = pos
        if distance_xz(pos,player_pos) <= SHADE_HIT_RADIUS and absf(pos.y-player_pos.y) <= 1.5 and not is_inside_safe_zone(player_pos) and invuln_ticks == 0 and int(shade["recoil"]) == 0:
            _hurt("shade")
            shade["recoil"] = 60
            var away: Vector2 = Vector2(pos.x-player_pos.x,pos.z-player_pos.z)
            if away.length() < 0.0001: away = Vector2.RIGHT
            away = away.normalized()
            pos.x += away.x*2.0
            pos.z += away.y*2.0
            shade["pos"] = _project_safe(pos)
            if state != "playing": return

func _drifter_step() -> void:
    for drifter in drifters:
        if int(drifter["stun_ticks"]) > 0:
            drifter["state"] = "stunned"
            continue
        var pos: Vector3 = drifter["pos"]
        var dist: float = distance_xz(pos,player_pos)
        if dist <= 15.0:
            drifter["chase_ticks"] = maxi(int(drifter["chase_ticks"]),240)
        if int(drifter["chase_ticks"]) > 0:
            drifter["chase_ticks"] = int(drifter["chase_ticks"])-1
            drifter["state"] = "chase"
            if dist > 0.00001:
                var direction: Vector2 = Vector2(player_pos.x-pos.x,player_pos.z-pos.z).normalized()
                pos.x += direction.x*5.0*DT
                pos.z += direction.y*5.0*DT
                drifter["pos"] = pos
            if dist <= 1.2 and not charm_active and int(drifter["steal_cooldown"]) == 0:
                var stolen: int = mini(3,carried)
                carried -= stolen
                drifter["steal_cooldown"] = 120
                emit_event("drifter_steal",{"drifter_id":drifter["id"],"amount":stolen})
        else:
            drifter["state"] = "idle"

func _hurt(by: String) -> void:
    flames = maxi(0,flames-1)
    invuln_ticks = INVULN_TICKS
    var dropped: int = int(floor(float(carried)/2.0))
    carried -= dropped
    for i in range(dropped):
        drop_serial += 1
        var angle: float = TAU*float(i)/float(maxi(1,dropped))
        var r: float = 1.5 + float(i%3)*1.0
        var location: Vector3 = player_pos + Vector3(cos(angle)*r,0,sin(angle)*r)
        motes.append({"id":"DROP"+str(drop_serial),"pos":location,"kind":"dropped","ttl":480})
    emit_event("player_hit",{"by":by,"flames":flames,"dropped":dropped})
    if flames <= 0: finish_game("lost","no_flames")

func _spawn_scheduled() -> void:
    # Spawns happen *after* the interactions and collisions of this tick.
    if random_motes and sim_tick > 0 and sim_tick % 240 == 0:
        _spawn_mote_batch(1)
    if random_shades:
        var interval: int = 480 if night == 1 else (420 if night == 2 else 360)
        var maximum: int = 6 if night == 1 else (8 if night == 2 else 10)
        if sim_tick == 300 and night == 1:
            _spawn_shades(2,maximum)
        elif sim_tick > 0 and sim_tick % interval == 0:
            _spawn_shades(1,maximum)
    if random_drifters and night >= 2 and sim_tick > 0 and sim_tick % 1200 == 0 and drifters.size() < 2:
        drifter_serial += 1
        var location: Vector3 = Vector3(18,0,18) if night == 2 else Vector3(25,0,15)
        add_drifter("D"+str(drifter_serial),location)
        emit_event("drifter_spawned",{"drifter_id":"D"+str(drifter_serial)})

func _spawn_shades(number: int, maximum: int) -> void:
    for _i in range(number):
        if shades.size() >= maximum: return
        var spots: Array[Vector3] = []
        if night == 1:
            for j in range(12):
                var a: float = deg_to_rad(15.0+30.0*float(j))
                spots.append(Vector3(cos(a)*37,0,sin(a)*37))
        elif night == 2:
            for center in [0.0,70.0]:
                for j in range(8):
                    var a: float = deg_to_rad(22.5+45.0*float(j))
                    spots.append(Vector3(center+cos(a)*26,0,sin(a)*26))
        else:
            for j in range(12):
                var a: float = deg_to_rad(15.0+30.0*float(j))
                spots.append(Vector3(cos(a)*39,0,sin(a)*39))
        var valid: Array[Vector3] = []
        for spot in spots:
            if distance_xz(spot,player_pos) >= 15 and not is_inside_safe_zone(spot): valid.append(spot)
        if valid.is_empty(): return
        shade_serial += 1
        var id: String = "S"+str(shade_serial)
        var selected: Vector3 = valid[rng.randi_range(0,valid.size()-1)]
        add_shade(id,selected)
        emit_event("shade_spawned",{"shade_id":id,"pos":vec3_json(selected)})

func _wind_step() -> void:
    if night != 3: return
    var cycle: int = sim_tick % 1800
    if cycle == 1680 and not wind_warned:
        wind_warned = true
        emit_event("wind_warning",{"ticks_to_wind":120})
    if cycle == 0:
        wind_tick = 300
        wind_warned = false
        var angle: float = rng.randf_range(0,TAU)
        weather_wind = Vector2(cos(angle),sin(angle))*2.0
        emit_event("wind_start",{"direction":[snappedf(weather_wind.x,0.001),snappedf(weather_wind.y,0.001)],"duration_ticks":300})
    if wind_tick > 0:
        wind_tick -= 1
        if wind_tick == 0: weather_wind = Vector2.ZERO

func _check_win() -> void:
    if get_lit_count() == lanterns.size():
        finish_game("won","all_lit")

func get_lit_count() -> int:
    var count: int = 0
    for lantern in lanterns:
        if bool(lantern["lit"]): count += 1
    return count

func finish_game(result: String, reason: String) -> void:
    if state != "playing": return
    state = result
    if result == "won":
        score += int(floor(get_time_left()))*SCORE_PER_SECOND_LEFT
        score += flames*SCORE_PER_FLAME_LEFT
        score_nights += score
    emit_event("game_over",{"result":result,"reason":reason})

func step(move_input: Vector2, cam_yaw_deg: float = 0.0, buttons: Dictionary = {}) -> void:
    # pause stops sim_tick but increments tick; all timers and schedules freeze.
    if _edge(buttons,"pause") and state in ["playing","paused"]:
        state = "playing" if state == "paused" else "paused"
        emit_event("resumed" if state == "playing" else "paused",{})
    tick += 1
    if state == "paused":
        previous_buttons = buttons.duplicate(true)
        return
    if state != "playing":
        previous_buttons = buttons.duplicate(true)
        return
    sim_tick += 1
    _tick_timers()
    _wind_step()
    _move_player(move_input,cam_yaw_deg,buttons)
    if state != "playing":
        previous_buttons = buttons.duplicate(true)
        return
    _pickup()
    if _edge(buttons,"interact"): interact_lantern()
    if state == "playing" and _edge(buttons,"pulse"): _pulse()
    if state == "playing": _shade_step()
    if state == "playing": _drifter_step()
    if state == "playing": _spawn_scheduled()
    if state == "playing" and get_time_left() <= 0.0: finish_game("lost","dawn")
    previous_buttons = buttons.duplicate(true)

func get_summary() -> Dictionary:
    return {"tick":tick,"sim_tick":sim_tick,"night":night,"state":state,"score":score,"flames":flames,"carried":carried,"time_left_s":get_time_left(),"lit_lanterns":get_lit_count()}
