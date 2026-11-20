extends Node3D

# Procedural 3D client; simulation and headless use the same GameCore.
const Core = preload("res://scripts/core/game_core.gd")
var game: GameCore
var may: Node3D
var pivot: Node3D
var cam: Camera3D
var hud: Label
var banner: Label
var menu: Control
var shade_visuals: Dictionary = {}
var mote_visuals: Dictionary = {}
var lantern_visuals: Dictionary = {}
var drifter_visuals: Dictionary = {}
var charm_visuals: Dictionary = {}
var yaw: float = 0.0
var selected_night: int = 1
var started: bool = false
var paused_ui: bool = false
var game_root: Node3D
var accessible_colors: bool = false
var settings_store: ConfigFile = ConfigFile.new()

func _ready() -> void:
    if settings_store.load("user://lantern_settings.cfg") == OK:
        accessible_colors = bool(settings_store.get_value("accessibility","distinguishable_colors",false))
    _build_ui()
    _show_menu()
    Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _material(color: Color, glow: bool = false) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = 0.75
    if glow:
        m.emission_enabled = true
        m.emission = color
        m.emission_energy_multiplier = 2.0
    return m

func _ball(parent: Node3D, radius: float, p: Vector3, c: Color, glow: bool = false) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    var mesh := SphereMesh.new()
    mesh.radius = radius
    mesh.height = radius*2
    node.mesh = mesh
    node.position = p
    node.material_override = _material(c,glow)
    parent.add_child(node)
    return node

func _box(parent: Node3D, size: Vector3, p: Vector3, c: Color) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    node.mesh = mesh
    node.position = p
    node.material_override = _material(c)
    parent.add_child(node)
    return node

func _island(center: Vector3, radius: float, height: float, color: Color) -> void:
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius-1.0
    mesh.height = 2.0
    var node := MeshInstance3D.new()
    node.mesh = mesh
    node.position = center + Vector3(0,height-1.0,0)
    node.material_override = _material(color)
    game_root.add_child(node)

func _build_ui() -> void:
    var canvas := CanvasLayer.new()
    add_child(canvas)
    # Keep status text readable against the 3D world without covering play area.
    var hud_background := ColorRect.new()
    hud_background.position = Vector2(12, 10)
    hud_background.size = Vector2(900, 155)
    hud_background.color = Color(0.055, 0.06, 0.13, 0.78)
    hud_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    canvas.add_child(hud_background)
    hud = Label.new()
    hud.position = Vector2(24, 18)
    hud.add_theme_font_size_override("font_size", 18)
    canvas.add_child(hud)
    banner = Label.new()
    banner.position = Vector2(24, 177)
    banner.add_theme_font_size_override("font_size", 21)
    canvas.add_child(banner)
    menu = Control.new()
    menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    canvas.add_child(menu)
    var bg := ColorRect.new()
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg.color = Color("14152a")
    bg.color.a = 0.9
    menu.add_child(bg)
    var panel := VBoxContainer.new()
    panel.position = Vector2(70,80)
    panel.add_theme_constant_override("separation",17)
    menu.add_child(panel)
    var title := Label.new()
    title.text = "ĐẢO ĐÈN LỒNG — BA HÒN ĐẢO"
    title.add_theme_font_size_override("font_size",38)
    panel.add_child(title)
    for index in range(1,4):
        var button := Button.new()
        button.text = "Chơi Đêm %d — %s" % [index,["Đảo Bến","Đảo Cầu","Đảo Chuông"][index-1]]
        button.custom_minimum_size = Vector2(420,46)
        button.pressed.connect(_begin_night.bind(index))
        panel.add_child(button)
    var resume := Button.new()
    resume.text = "Tiếp tục (Esc)"
    resume.pressed.connect(_resume)
    panel.add_child(resume)
    var accessibility := CheckBox.new()
    accessibility.text = "Bảng màu dễ phân biệt (lưu tự động)"
    accessibility.button_pressed = accessible_colors
    accessibility.toggled.connect(_set_accessible_colors)
    panel.add_child(accessibility)

func _set_accessible_colors(enabled: bool) -> void:
    accessible_colors = enabled
    settings_store.set_value("accessibility","distinguishable_colors",enabled)
    settings_store.save("user://lantern_settings.cfg")

func _show_menu() -> void:
    menu.visible = true
    Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _resume() -> void:
    if started:
        menu.visible = false
        paused_ui = false
        Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _begin_night(value: int) -> void:
    selected_night = value
    if game_root != null:
        game_root.queue_free()
        shade_visuals.clear()
        mote_visuals.clear()
        drifter_visuals.clear()
        charm_visuals.clear()
        lantern_visuals.clear()
    game = Core.new()
    game.set_seed(int(Time.get_ticks_usec()))
    game.reset(selected_night)
    game_root = Node3D.new()
    game_root.name = "ProceduralWorld"
    add_child(game_root)
    _build_world()
    started = true
    paused_ui = false
    menu.visible = false
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _build_world() -> void:
    var world := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("15162f")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("7b779f")
    env.ambient_light_energy = 0.8
    world.environment = env
    game_root.add_child(world)
    var sunlight := DirectionalLight3D.new()
    sunlight.rotation_degrees = Vector3(-55,-30,0)
    sunlight.light_color = Color("ffe4b7")
    sunlight.light_energy = 0.8
    game_root.add_child(sunlight)
    if selected_night == 1:
        _island(Vector3.ZERO,40,0,Color("395a55"))
    elif selected_night == 2:
        _island(Vector3.ZERO,28,0,Color("36565a"))
        _island(Vector3(70,0,0),28,0,Color("3f5960"))
        _box(game_root,Vector3(18,0.6,2),Vector3(35,-0.2,0),Color("c19b71"))
        _ball(game_root,1,Vector3(20,0.7,18),Color("f5a765"),true)
        _ball(game_root,1,Vector3(50,0.7,-18),Color("f5a765"),true)
    else:
        _island(Vector3.ZERO,45,0,Color("304d5e"))
        _island(Vector3.ZERO,24,3,Color("496b68"))
        _island(Vector3.ZERO,8,6,Color("657674"))
        _box(game_root,Vector3(2,1,12),Vector3(0,0.2,29),Color("9b967d"))
    may = Node3D.new()
    game_root.add_child(may)
    _box(may,Vector3(0.8,0.9,0.65),Vector3(0,0.62,0),Color("56c4b5"))
    _ball(may,0.42,Vector3(0,1.28,0),Color("f8d3a3"))
    var hat := MeshInstance3D.new()
    var cone := CylinderMesh.new()
    cone.top_radius = 0.02
    cone.bottom_radius = 0.9
    cone.height = 0.42
    hat.mesh = cone
    hat.position = Vector3(0,1.76,0)
    hat.material_override = _material(Color("debf84"))
    may.add_child(hat)
    _ball(may,0.2,Vector3(0.65,1.3,0),Color("ffbb52"),true)
    pivot = Node3D.new()
    game_root.add_child(pivot)
    cam = Camera3D.new()
    cam.position = Vector3(0,11, -17)
    cam.current = true
    pivot.add_child(cam)
    for lantern in game.lanterns:
        var id: String = str(lantern["id"])
        var post := Node3D.new()
        post.position = lantern["pos"]
        game_root.add_child(post)
        _box(post,Vector3(0.3,2.8,0.3),Vector3(0,1.4,0),Color("73564c"))
        var orb := _ball(post,0.7,Vector3(0,3,0),Color("71607e"))
        var light := OmniLight3D.new()
        light.position = Vector3(0,3,0)
        light.light_color = Color("ffbf61")
        light.omni_range = 12
        post.add_child(light)
        var bar := _box(post,Vector3(0.14,1.0,0.14),Vector3(0.8,1.4,0),Color("87d981"))
        var worn := _box(post,Vector3(0.85,0.025,0.85),Vector3(0,2.72,0),Color("a9a0a0"))
        lantern_visuals[id] = {"orb":orb,"light":light,"bar":bar,"worn":worn}
    _sync_visuals()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        yaw -= event.relative.x*0.003
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_ESCAPE:
            if started:
                paused_ui = not paused_ui
                menu.visible = paused_ui
                Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if paused_ui else Input.MOUSE_MODE_CAPTURED)
        elif event.keycode == KEY_R and started:
            _begin_night(selected_night)

func _physics_process(_delta: float) -> void:
    if not started or game == null: return
    if not paused_ui and game.state == "playing":
        var move: Vector2 = Vector2(float(int(Input.is_key_pressed(KEY_A))-int(Input.is_key_pressed(KEY_D))),float(int(Input.is_key_pressed(KEY_W))-int(Input.is_key_pressed(KEY_S))))
        game.step(move,rad_to_deg(yaw),{
            "jump":Input.is_key_pressed(KEY_SPACE),
            "dash":Input.is_key_pressed(KEY_SHIFT),
            "interact":Input.is_key_pressed(KEY_E),
            "pulse":Input.is_key_pressed(KEY_Q)
        })
        game.drain_events()
    _sync_visuals()

func _sync_visuals() -> void:
    if game == null or may == null: return
    may.position = game.player_pos
    pivot.position = game.player_pos
    pivot.rotation.y = yaw
    cam.look_at(game.player_pos + Vector3(0,1.2,0),Vector3.UP)
    for lantern in game.lanterns:
        var id: String = str(lantern["id"])
        var visuals: Dictionary = lantern_visuals[id]
        var lit: bool = bool(lantern["lit"])
        var low_fuel: bool = lit and float(lantern["fuel"]) < 30.0
        var blink: bool = low_fuel and int(Time.get_ticks_msec()/500) % 2 == 0
        var off_color: Color = Color("333743") if accessible_colors else Color("71607e")
        var lit_color: Color = Color("ffe9a7") if accessible_colors else Color("ffca64")
        visuals["orb"].material_override = _material(off_color if not lit or blink else lit_color,lit and not blink)
        visuals["light"].light_energy = 1.8 if lit and not blink else 0
        var height: float = maxf(0.03,float(lantern["fuel"])/100.0)
        visuals["bar"].scale.y = height
        visuals["bar"].position.y = 0.9+0.5*height
        visuals["bar"].visible = lit
        visuals["bar"].material_override = _material(Color("ffffff") if accessible_colors else (Color("ff6d6d") if low_fuel else Color("87d981")))
        visuals["worn"].visible = not lit
    var active_motes: Dictionary = {}
    for mote in game.motes:
        var id: String = str(mote["id"])
        active_motes[id] = true
        if not mote_visuals.has(id):
            mote_visuals[id] = _ball(game_root,0.24,mote["pos"] + Vector3(0,0.8,0),Color("ffe187"),true)
    for id in mote_visuals:
        mote_visuals[id].visible = active_motes.has(id)
    for shade in game.shades:
        var id: String = str(shade["id"])
        if not shade_visuals.has(id):
            var node := Node3D.new()
            game_root.add_child(node)
            _ball(node,0.72,Vector3(0,0.75,0),Color("24132e"))
            _ball(node,0.11,Vector3(-0.24,1,-0.55),Color("c5a4ff"),true)
            _ball(node,0.11,Vector3(0.24,1,-0.55),Color("c5a4ff"),true)
            shade_visuals[id] = node
        shade_visuals[id].position = shade["pos"]
        shade_visuals[id].scale = Vector3.ONE*(0.8 if shade["state"] == "stunned" else 1)
        for child in shade_visuals[id].get_children():
            if child is MeshInstance3D:
                var shade_color: Color = Color("00b3ff") if accessible_colors else Color("24132e")
                child.material_override = _material(shade_color)
    for drifter in game.drifters:
        var id: String = str(drifter["id"])
        if not drifter_visuals.has(id):
            drifter_visuals[id] = _ball(game_root,0.6,drifter["pos"] + Vector3(0,1,0),Color("91c8ea"),true)
        drifter_visuals[id].position = drifter["pos"]+Vector3(0,1,0)
    for charm in game.charms:
        var id: String = str(charm["id"])
        if not charm_visuals.has(id):
            charm_visuals[id] = _ball(game_root,0.4,charm["pos"]+Vector3(0,0.8,0),Color("7ee1c7"),true)
        charm_visuals[id].visible = bool(charm["active"])
    var progress: String = ""
    for lantern in game.lanterns:
        var fuel: float = float(lantern["fuel"])
        var status: String = ("%3.0f" % fuel) if bool(lantern["lit"]) else ("TẮT (%d)" % int(lantern["deposited"]))
        progress += "%s:%s  " % [str(lantern["id"]),status]
    var required: int = int(ceil(float(game.lantern_count)*0.6))
    hud.text = "ĐẢO ĐÈN LỒNG | ĐÊM %d\nNgọn Lửa: %d | Đom đóm: %d/%d | Đèn đang sáng: %d/%d (cần %d)\nĐiểm: %d | Còn: %.1fs\n%s\nLướt: %.1fs | Tỏa Sáng: %.1fs" % [game.night,game.flames,game.carried,game.get_capacity(),game.get_lit_count(),game.lantern_count,required,game.score,game.get_time_left(),progress,float(game.dash_cooldown)/60.0,float(game.pulse_cooldown)/60.0]
    if game.state == "won": banner.text = "CHIẾN THẮNG BÌNH MINH! Nhấn R để chơi lại hoặc Esc chọn đêm."
    elif game.state == "lost": banner.text = "THẤT BẠI! Nhấn R để chơi lại hoặc Esc chọn đêm."
    else: banner.text = ""
