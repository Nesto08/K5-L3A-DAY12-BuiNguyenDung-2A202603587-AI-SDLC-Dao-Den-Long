extends RefCounted
class_name GameCore

# Phase 1 design choices. Values must exactly match game.contract.json.
const TICK_RATE: int = 60
const DT: float = 1.0 / 60.0
const PLAYER_SPEED: float = 5.0
const SPRINT_SPEED: float = 8.0 # Visual-only enhancement, never enabled by headless v1.0
const CARRY_CAPACITY: int = 10
const LANTERN_COST: int = 3
const PICKUP_RADIUS: float = 1.2
const INTERACT_RADIUS: float = 2.0
const PULSE_COST: int = 2
const PULSE_RADIUS: float = 5.0
const PULSE_STUN_TICKS: int = 120
const PULSE_PUSH_M: float = 2.0
const PULSE_COOLDOWN_TICKS: int = 60
const INVULN_TICKS: int = 60
const SAFE_RADIUS: float = 5.0
const SHADE_SPEED: float = 2.5
const SHADE_HIT_RADIUS: float = 0.8
const SHADE_DETECTION_RADIUS: float = 15.0
const JUMP_SPEED: float = 6.0
const GRAVITY: float = 18.0
const NIGHT_DURATION_S: float = 180.0
const MAX_FLAMES: int = 3
const HIT_DROP_RATIO: float = 0.0
const FALL_ENABLED: bool = false
const SCORE_PER_MOTE: int = 0 # Pickup yields no points. Deposit yields points.
const SCORE_PER_DEPOSIT: int = 10
const SCORE_PER_LANTERN: int = 100
const SCORE_PER_STUN: int = 0
const SCORE_PER_SECOND_LEFT: int = 0
const SCORE_PER_FLAME_LEFT: int = 0

var tick: int = 0
var state: String = "playing"
var player_pos: Vector3 = Vector3.ZERO
var player_velocity_y: float = 0.0
var player_hp: int = 100 # Legacy UI only; flames determine death.
var flames: int = MAX_FLAMES
var carried: int = 0
var score: int = 0
var initial_time_left_s: float = NIGHT_DURATION_S
var night_duration_s: float = NIGHT_DURATION_S
var damage_cooldown: int = 0
var pulse_cooldown: int = 0
var lanterns: Array[Dictionary] = []
var motes: Array[Dictionary] = []
var shades: Array[Dictionary] = []
var events: Array[Dictionary] = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var current_seed: int = 0
var previous_jump: bool = false
var previous_interact: bool = false
var previous_pulse: bool = false

func reset() -> void:
    tick = 0
    state = "playing"
    player_pos = Vector3.ZERO
    player_velocity_y = 0.0
    player_hp = 100
    flames = MAX_FLAMES
    carried = 0
    score = 0
    night_duration_s = NIGHT_DURATION_S
    initial_time_left_s = NIGHT_DURATION_S
    damage_cooldown = 0
    pulse_cooldown = 0
    previous_jump = false
    previous_interact = false
    previous_pulse = false
    lanterns.clear()
    motes.clear()
    shades.clear()
    events.clear()
    rng.seed = current_seed
    setup_lanterns()

func set_seed(value: int) -> void:
    current_seed = value
    rng.seed = value

func setup_lanterns() -> void:
    var positions: Array[Vector3] = [Vector3(0,0,-12), Vector3(11,0,-4), Vector3(7,0,10), Vector3(-7,0,10), Vector3(-11,0,-4)]
    lanterns.clear()
    for i in range(positions.size()):
        lanterns.append({"id":"L" + str(i+1), "pos": positions[i], "lit":false, "deposited":0})

func setup_default_world() -> void:
    # Phase 1 free placement. Seeded RNG keeps headless deterministic.
    # Phase 2 will replace this with the required fixed spawn-point system.
    motes.clear()
    shades.clear()

    const MOTE_COUNT: int = 24
    const MIN_RADIUS: float = 4.0
    const MAX_RADIUS: float = 21.0
    const MIN_SPACING: float = 2.5
    const LANTERN_CLEARANCE: float = 3.5
    const MAX_ATTEMPTS: int = 5000

    var attempts: int = 0
    while motes.size() < MOTE_COUNT and attempts < MAX_ATTEMPTS:
        attempts += 1
        var angle: float = rng.randf_range(0.0, TAU)
        # sqrt gives an approximately uniform density per unit area.
        var radius: float = sqrt(rng.randf_range(
            MIN_RADIUS * MIN_RADIUS,
            MAX_RADIUS * MAX_RADIUS
        ))
        var candidate := Vector3(
            cos(angle) * radius,
            0.0,
            sin(angle) * radius
        )

        var valid: bool = true
        for lantern in lanterns:
            if distance_xz(candidate, lantern["pos"]) < LANTERN_CLEARANCE:
                valid = false
                break
        if not valid:
            continue

        for mote in motes:
            if distance_xz(candidate, mote["pos"]) < MIN_SPACING:
                valid = false
                break
        if not valid:
            continue

        motes.append({
            "id": "M" + str(motes.size() + 1),
            "pos": candidate
        })

    # Fixed initial shade placement; unchanged gameplay and test behavior.
    add_shade("S1", Vector3(16, 0, 14))
    add_shade("S2", Vector3(-16, 0, -14))

static func vec3_from_array(a: Array) -> Vector3:
    return Vector3(float(a[0]), float(a[1]), float(a[2]))

func distance_xz(a: Vector3, b: Vector3) -> float:
    return Vector2(a.x-b.x, a.z-b.z).length()

func get_time_left() -> float:
    return maxf(0.0, initial_time_left_s - float(tick) / float(TICK_RATE))

func emit_event(name: String, data: Dictionary) -> void:
    events.append({"type":"event", "tick":tick, "name":name, "data":data})

func drain_events() -> Array[Dictionary]:
    var result: Array[Dictionary] = events.duplicate(true)
    events.clear()
    return result

func apply_scenario(scenario: Dictionary) -> void:
    if scenario.has("player"):
        var p: Dictionary = scenario["player"]
        if p.has("pos"):
            player_pos = vec3_from_array(p["pos"])
        if p.has("carried"):
            carried = int(p["carried"])
        if p.has("flames"):
            flames = int(p["flames"])
        if p.has("hp"):
            player_hp = int(p["hp"])
    if scenario.has("time_left_s"):
        initial_time_left_s = float(scenario["time_left_s"])
    if scenario.has("lanterns"):
        for updated in scenario["lanterns"]:
            for lantern in lanterns:
                if lantern["id"] != updated["id"]:
                    continue
                if updated.has("pos"):
                    lantern["pos"] = vec3_from_array(updated["pos"])
                if updated.has("deposited"):
                    lantern["deposited"] = int(updated["deposited"])
                if updated.has("lit"):
                    lantern["lit"] = updated["lit"]
    if scenario.get("random_motes", true) == false and not scenario.has("motes"):
        motes.clear()
    if scenario.get("random_shades", true) == false and not scenario.has("shades"):
        shades.clear()
    if scenario.has("motes"):
        motes.clear()
        var i: int = 1
        for mote in scenario["motes"]:
            var location: Array
            var identity: String = "M" + str(i)
            if mote is Array:
                location = mote
            else:
                location = mote["pos"]
                identity = str(mote.get("id", identity))
            motes.append({"id":identity, "pos":vec3_from_array(location)})
            i += 1
    if scenario.has("shades"):
        shades.clear()
        var i: int = 1
        for shade in scenario["shades"]:
            add_shade(str(shade.get("id", "S" + str(i))), vec3_from_array(shade["pos"]))
            i += 1
    events.clear() # Scenario setup must not emit events or award score.

func step(move_input: Vector2, cam_yaw_deg: float = 0.0, buttons: Dictionary = {}) -> void:
    if state != "playing":
        return
    # Step k changes state k -> k+1. Events emitted here have tick k+1.
    tick += 1
    damage_cooldown = maxi(0, damage_cooldown - 1)
    pulse_cooldown = maxi(0, pulse_cooldown - 1)
    var move: Vector2 = move_input.limit_length(1.0)
    var angle: float = deg_to_rad(cam_yaw_deg)
    var world_x: float = move.x*cos(angle) + move.y*sin(angle)
    var world_z: float = -move.x*sin(angle) + move.y*cos(angle)
    var speed: float = SPRINT_SPEED if bool(buttons.get("sprint", false)) else PLAYER_SPEED
    player_pos.x += world_x*speed*DT
    player_pos.z += world_z*speed*DT

    var jump: bool = bool(buttons.get("jump", false))
    var interact: bool = bool(buttons.get("interact", false))
    var pulse: bool = bool(buttons.get("pulse", false))
    var jump_edge: bool = jump and not previous_jump
    var interact_edge: bool = interact and not previous_interact
    var pulse_edge: bool = pulse and not previous_pulse
    previous_jump = jump
    previous_interact = interact
    previous_pulse = pulse
    if jump_edge and player_pos.y <= 0.0:
        player_velocity_y = JUMP_SPEED
    if player_pos.y > 0.0 or player_velocity_y > 0.0:
        player_velocity_y -= GRAVITY*DT
        player_pos.y = maxf(0.0, player_pos.y + player_velocity_y*DT)
        if player_pos.y <= 0.0:
            player_velocity_y = 0.0

    pickup_motes()
    if interact_edge:
        interact_lantern()
    if state == "playing" and pulse_edge:
        use_pulse()
    if state == "playing":
        update_shades()
    if state == "playing" and get_time_left() <= 0.0:
        finish_game("lost", "dawn")

func pickup_motes() -> void:
    if state != "playing":
        return
    # Forward iteration makes pickup event sequence stable by mote list order.
    var i: int = 0
    while i < motes.size() and carried < CARRY_CAPACITY:
        var pos: Vector3 = motes[i]["pos"]
        if distance_xz(player_pos, pos) <= PICKUP_RADIUS:
            carried += 1
            motes.remove_at(i)
            emit_event("mote_picked", {"carried":carried})
        else:
            i += 1

func interact_lantern() -> void:
    if state != "playing" or carried <= 0:
        return
    var nearest: Dictionary = {}
    var best: float = INF
    for lantern in lanterns:
        if lantern["lit"]:
            continue
        var distance: float = distance_xz(player_pos, lantern["pos"])
        if distance > INTERACT_RADIUS:
            continue
        if distance < best or (is_equal_approx(distance, best) and (nearest.is_empty() or str(lantern["id"]) < str(nearest["id"]))):
            best = distance
            nearest = lantern
    if nearest.is_empty():
        return
    var missing: int = maxi(0, LANTERN_COST - int(nearest["deposited"]))
    var amount: int = mini(carried, missing)
    if amount <= 0:
        return
    carried -= amount
    nearest["deposited"] = int(nearest["deposited"]) + amount
    score += amount * SCORE_PER_DEPOSIT
    emit_event("deposit", {"lantern_id":nearest["id"], "amount":amount, "deposited":nearest["deposited"]})
    if int(nearest["deposited"]) >= LANTERN_COST:
        nearest["lit"] = true
        score += SCORE_PER_LANTERN
        emit_event("lantern_lit", {"lantern_id":nearest["id"]})
        check_win()

func get_lit_count() -> int:
    var count: int = 0
    for lantern in lanterns:
        if lantern["lit"]:
            count += 1
    return count

func check_win() -> void:
    if state == "playing" and get_lit_count() == lanterns.size():
        finish_game("won", "all_lit")

func finish_game(result: String, reason: String) -> void:
    if state != "playing":
        return
    state = result
    if result == "won":
        score += int(floor(get_time_left())) * SCORE_PER_SECOND_LEFT
        score += flames * SCORE_PER_FLAME_LEFT
    emit_event("game_over", {"result":result, "reason":reason})

func check_lose() -> void:
    if flames <= 0:
        flames = 0
        player_hp = 0
        finish_game("lost", "no_flames")

func take_damage(amount: int) -> void:
    if state != "playing" or amount <= 0:
        return
    flames = maxi(0, flames - 1)
    player_hp = maxi(0, player_hp - amount)
    var dropped: int = int(floor(carried * HIT_DROP_RATIO))
    carried -= dropped
    emit_event("player_hit", {"by":"shade", "flames":flames, "dropped":dropped})
    check_lose()

func add_shade(id: String, pos: Vector3) -> void:
    shades.append({"id":id, "pos":pos, "state":"chase", "stun_ticks":0})

func is_inside_safe_zone(pos: Vector3) -> bool:
    for lantern in lanterns:
        if lantern["lit"] and distance_xz(pos, lantern["pos"]) <= SAFE_RADIUS:
            return true
    return false

func keep_shade_outside_safe_zones(pos: Vector3) -> Vector3:
    var result: Vector3 = pos
    for iteration in range(20):
        var changed: bool = false
        for lantern in lanterns:
            if not lantern["lit"]:
                continue
            var center: Vector3 = lantern["pos"]
            var delta: Vector2 = Vector2(result.x-center.x, result.z-center.z)
            if delta.length() <= SAFE_RADIUS:
                var direction: Vector2 = delta.normalized() if delta.length() > 0.00001 else Vector2.RIGHT
                result.x = center.x + direction.x*(SAFE_RADIUS+0.001)
                result.z = center.z + direction.y*(SAFE_RADIUS+0.001)
                changed = true
        if not changed:
            break
    return result

func update_shades() -> void:
    for shade in shades:
        var stunned: int = int(shade["stun_ticks"])
        if stunned > 0:
            shade["stun_ticks"] = stunned - 1
            shade["state"] = "stunned"
            continue
        shade["state"] = "chase"
        var shade_pos: Vector3 = shade["pos"]
        var distance: float = distance_xz(shade_pos, player_pos)
        if distance <= SHADE_DETECTION_RADIUS and distance > 0.000001:
            var direction: Vector2 = Vector2(player_pos.x-shade_pos.x, player_pos.z-shade_pos.z).normalized()
            shade_pos.x += direction.x * SHADE_SPEED * DT
            shade_pos.z += direction.y * SHADE_SPEED * DT
        shade_pos = keep_shade_outside_safe_zones(shade_pos)
        shade["pos"] = shade_pos
        if not is_inside_safe_zone(shade_pos) and distance_xz(shade_pos, player_pos) <= SHADE_HIT_RADIUS and damage_cooldown == 0:
            take_damage(20)
            damage_cooldown = INVULN_TICKS
            if state != "playing":
                return

func use_pulse() -> bool:
    if state != "playing" or carried < PULSE_COST or pulse_cooldown > 0:
        return false
    carried -= PULSE_COST
    pulse_cooldown = PULSE_COOLDOWN_TICKS
    var stunned_ids: Array[String] = []
    for shade in shades:
        var pos: Vector3 = shade["pos"]
        if distance_xz(pos, player_pos) > PULSE_RADIUS:
            continue
        stunned_ids.append(str(shade["id"]))
        shade["state"] = "stunned"
        shade["stun_ticks"] = PULSE_STUN_TICKS
        var direction: Vector2 = Vector2(pos.x-player_pos.x, pos.z-player_pos.z)
        direction = direction.normalized() if direction.length() > 0.00001 else Vector2.RIGHT
        pos.x += direction.x * PULSE_PUSH_M
        pos.z += direction.y * PULSE_PUSH_M
        shade["pos"] = keep_shade_outside_safe_zones(pos)
        score += SCORE_PER_STUN
    emit_event("pulse", {"stunned_ids":stunned_ids})
    return true

func get_summary() -> Dictionary:
    return {"tick":tick, "sim_tick":tick, "state":state, "score":score, "flames":flames, "carried":carried, "time_left_s":get_time_left(), "lit_lanterns":get_lit_count()}
