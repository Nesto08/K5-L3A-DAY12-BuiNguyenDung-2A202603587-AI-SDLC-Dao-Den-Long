extends Node3D

# Playable 3D visual client for the existing GameCore.
# GameCore remains the authority for movement, motes, lanterns, shades and rules.
const Core = preload("res://scripts/core/game_core.gd")

var game: GameCore
var may: Node3D
var camera_pivot: Node3D
var view_camera: Camera3D
var hud: Label
var banner: Label
var lantern_visuals: Dictionary = {}
var mote_visuals: Dictionary = {}
var shade_visuals: Dictionary = {}
var camera_yaw: float = 0.0


func _ready() -> void:
    game = Core.new()
    # New seed for each desktop play/restart. Headless still uses --seed.
    game.set_seed(int(Time.get_ticks_usec()))
    game.reset()
    game.setup_default_world()
    _build_scene()
    _sync_visuals()
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _make_mat(color: Color, glow: bool = false) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.8
    if glow:
        material.emission_enabled = true
        material.emission = color
        material.emission_energy_multiplier = 2.0
    return material


func _sphere(parent: Node3D, radius: float, position_3d: Vector3, color: Color, glow: bool = false) -> MeshInstance3D:
    var mesh_node := MeshInstance3D.new()
    var mesh := SphereMesh.new()
    mesh.radius = radius
    mesh.height = radius * 2.0
    mesh_node.mesh = mesh
    mesh_node.material_override = _make_mat(color, glow)
    mesh_node.position = position_3d
    parent.add_child(mesh_node)
    return mesh_node


func _box(parent: Node3D, size: Vector3, position_3d: Vector3, color: Color) -> MeshInstance3D:
    var mesh_node := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    mesh_node.mesh = mesh
    mesh_node.material_override = _make_mat(color)
    mesh_node.position = position_3d
    parent.add_child(mesh_node)
    return mesh_node


func _build_scene() -> void:
    var environment_node := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color("16152d")
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color("74719b")
    environment.ambient_light_energy = 0.75
    environment_node.environment = environment
    add_child(environment_node)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-55, -35, 0)
    sun.light_color = Color("ffe1b0")
    sun.light_energy = 0.8
    add_child(sun)

    var island := MeshInstance3D.new()
    var ground_mesh := CylinderMesh.new()
    ground_mesh.top_radius = 25.0
    ground_mesh.bottom_radius = 23.0
    ground_mesh.height = 1.5
    island.mesh = ground_mesh
    island.position = Vector3(0, -0.75, 0)
    island.material_override = _make_mat(Color("385b54"))
    add_child(island)

    for i in range(28):
        var angle: float = float(i) * TAU / 28.0
        var r: float = 21.0 + float(i % 4) * 0.6
        _sphere(self, 0.5 + float(i % 3) * 0.12, Vector3(cos(angle) * r, 0.25, sin(angle) * r), Color("72728d"))

    may = Node3D.new()
    may.name = "May"
    add_child(may)
    _box(may, Vector3(0.8, 0.85, 0.58), Vector3(0, 0.58, 0), Color("5db0ad"))
    _sphere(may, 0.43, Vector3(0, 1.25, 0), Color("f3cb9c"))
    var hat_node := MeshInstance3D.new()
    var hat_mesh := CylinderMesh.new()
    hat_mesh.top_radius = 0.02
    hat_mesh.bottom_radius = 0.94
    hat_mesh.height = 0.43
    hat_node.mesh = hat_mesh
    hat_node.position = Vector3(0, 1.75, 0)
    hat_node.material_override = _make_mat(Color("dfbc7d"))
    may.add_child(hat_node)
    _sphere(may, 0.17, Vector3(0.62, 1.42, 0), Color("ffbc52"), true)

    camera_pivot = Node3D.new()
    add_child(camera_pivot)
    view_camera = Camera3D.new()
    view_camera.position = Vector3(0, 9.5, -14)
    view_camera.current = true
    camera_pivot.add_child(view_camera)

    var canvas := CanvasLayer.new()
    add_child(canvas)
    hud = Label.new()
    hud.position = Vector2(20, 18)
    hud.add_theme_font_size_override("font_size", 23)
    canvas.add_child(hud)
    banner = Label.new()
    banner.position = Vector2(20, 138)
    banner.add_theme_font_size_override("font_size", 22)
    canvas.add_child(banner)
    var instructions := Label.new()
    instructions.position = Vector2(20, 193)
    instructions.text = "WASD: Di chuyển | Shift: Chạy nhanh | Chuột: Camera | Space: Nhảy | E: Thắp đèn | Q: Tỏa sáng | R: Chơi lại | Esc: Thả chuột"
    instructions.add_theme_font_size_override("font_size", 15)
    canvas.add_child(instructions)

    for lantern in game.lanterns:
        var lantern_id: String = str(lantern["id"])
        var post := Node3D.new()
        post.position = lantern["pos"]
        add_child(post)
        _box(post, Vector3(0.24, 2.8, 0.24), Vector3(0, 1.4, 0), Color("765145"))
        var light_sphere := _sphere(post, 0.75, Vector3(0, 3.0, 0), Color("68546f"))
        var lamp := OmniLight3D.new()
        lamp.position = Vector3(0, 3.0, 0)
        lamp.light_color = Color("ffb65a")
        lamp.omni_range = 10.0
        lamp.light_energy = 0.0
        post.add_child(lamp)
        lantern_visuals[lantern_id] = {"sphere": light_sphere, "lamp": lamp}

    for mote in game.motes:
        var mote_id: String = str(mote["id"])
        var mote_pos: Vector3 = mote["pos"]
        mote_visuals[mote_id] = _sphere(self, 0.23, mote_pos + Vector3(0, 0.9, 0), Color("ffd66a"), true)

    for shade in game.shades:
        var shade_id: String = str(shade["id"])
        var shade_node := Node3D.new()
        shade_node.position = shade["pos"]
        add_child(shade_node)
        _sphere(shade_node, 0.7, Vector3(0, 0.8, 0), Color("1d112c"))
        _sphere(shade_node, 0.10, Vector3(-0.22, 1.0, -0.58), Color("bda4ff"), true)
        _sphere(shade_node, 0.10, Vector3(0.22, 1.0, -0.58), Color("bda4ff"), true)
        shade_visuals[shade_id] = shade_node


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        camera_yaw -= event.relative.x * 0.003
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_ESCAPE:
            if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
                Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
            else:
                Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
        elif event.keycode == KEY_R:
            get_tree().reload_current_scene()


func _physics_process(_delta: float) -> void:
    if game.state == "playing":
        var move_x: float = float(int(Input.is_key_pressed(KEY_A)) - int(Input.is_key_pressed(KEY_D)))
        var move_z: float = float(int(Input.is_key_pressed(KEY_W)) - int(Input.is_key_pressed(KEY_S)))
        var buttons := {
            "jump": Input.is_key_pressed(KEY_SPACE),
            "interact": Input.is_key_pressed(KEY_E),
            "pulse": Input.is_key_pressed(KEY_Q),
            "sprint": Input.is_key_pressed(KEY_SHIFT)
        }
        game.step(Vector2(move_x, move_z), rad_to_deg(camera_yaw), buttons)
        game.drain_events()  # HUD uses state; CLI runner separately emits JSONL events.
    _sync_visuals()


func _sync_visuals() -> void:
    may.position = game.player_pos
    camera_pivot.position = Vector3(game.player_pos.x, 0, game.player_pos.z)
    camera_pivot.rotation.y = camera_yaw
    view_camera.look_at(game.player_pos + Vector3(0, 1, 0), Vector3.UP)

    for lantern in game.lanterns:
        var lantern_id: String = str(lantern["id"])
        var visuals: Dictionary = lantern_visuals[lantern_id]
        var light_sphere: MeshInstance3D = visuals["sphere"]
        var lamp: OmniLight3D = visuals["lamp"]
        var lit: bool = bool(lantern["lit"])
        light_sphere.material_override = _make_mat(Color("ffbf62") if lit else Color("68546f"), lit)
        lamp.light_energy = 1.6 if lit else 0.0

    var live_motes: Dictionary = {}
    for mote in game.motes:
        live_motes[str(mote["id"])] = true
    for mote_id in mote_visuals:
        var mote_node: MeshInstance3D = mote_visuals[mote_id]
        mote_node.visible = live_motes.has(mote_id)

    for shade in game.shades:
        var shade_id: String = str(shade["id"])
        var shade_node: Node3D = shade_visuals[shade_id]
        shade_node.position = shade["pos"]
        shade_node.scale = Vector3.ONE * (0.82 if str(shade["state"]) == "stunned" else 1.0)

    hud.text = "ĐẢO ĐÈN LỒNG | ĐÊM 1\nMạng: %d  ·  Đom đóm: %d  ·  Đèn: %d/5\nĐiểm: %d  ·  Thời gian: %.1f giây" % [game.flames, game.carried, game.get_lit_count(), game.score, game.get_time_left()]
    if game.state == "won":
        banner.text = "CHIẾN THẮNG! Nhấn R để chơi lại"
    elif game.state == "lost":
        banner.text = "THẤT BẠI! Nhấn R để chơi lại"
    else:
        banner.text = "Thu thập ánh sáng, đến gần đèn và nhấn E"
