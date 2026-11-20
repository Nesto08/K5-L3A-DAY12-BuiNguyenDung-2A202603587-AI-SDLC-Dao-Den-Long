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
const Leaderboard = preload("res://scripts/leaderboard.gd")
var hud_top: PanelContainer
var hud_lamps: PanelContainer
var hud_actions: PanelContainer
var hud_title: Label
var hud_stats: Label
var hud_lamps_title: Label
var hud_lamps_value: Label
var hud_actions_value: Label
var result_submitted: bool = false
var score_input: LineEdit
var score_panel: VBoxContainer
var ranking_panel: VBoxContainer
var reduced_motion: bool = false
var large_ui: bool = false
var control_bindings: Dictionary = {"left":KEY_A,"right":KEY_D,"forward":KEY_W,"back":KEY_S,"jump":KEY_SPACE,"dash":KEY_SHIFT,"interact":KEY_E,"pulse":KEY_Q,"pause":KEY_ESCAPE}
var binding_widgets: Dictionary = {}
var remap_wait: String = ""
var warning_label: Label
var visual_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var ambient_fireflies: Array[Node3D] = []
var decoration_root: Node3D
var benchmark_visuals: bool = false
# Lightweight on-screen FPS monitor; visual only, no GameCore changes.
var fps_panel: PanelContainer
var fps_label: Label
var fps_visible: bool = true
var fps_update_elapsed: float = 0.0
# Visual-only dawn cycle. Does not change GameCore time, scoring or headless.
var dawn_environment: Environment
var dawn_sky: ProceduralSkyMaterial
var dawn_sun: DirectionalLight3D
var dawn_last_tick: int = -100
var shade_body_normal: StandardMaterial3D
var shade_body_access: StandardMaterial3D
var shade_eye_material: StandardMaterial3D
var lantern_on_material: StandardMaterial3D
var lantern_off_material: StandardMaterial3D
var lantern_access_on_material: StandardMaterial3D
var lantern_access_off_material: StandardMaterial3D
var lantern_bar_material: StandardMaterial3D
var lantern_bar_warning_material: StandardMaterial3D
var lantern_bar_access_material: StandardMaterial3D
var run_score: int = 0
var run_wins: int = 0
var expected_next_night: int = 1
var result_recorded: bool = false

func _ready() -> void:
    if settings_store.load("user://lantern_settings.cfg") == OK:
        accessible_colors = bool(settings_store.get_value("accessibility","distinguishable_colors",false))
    reduced_motion = bool(settings_store.get_value("accessibility","reduced_motion",false))
    large_ui = bool(settings_store.get_value("accessibility","large_ui",false))
    var stored_bindings: Variant = settings_store.get_value("controls", "bindings", {})
    if stored_bindings is Dictionary:
        for key in control_bindings.keys():
            if stored_bindings.has(key): control_bindings[key] = int(stored_bindings[key])
    _build_ui()
    _set_large_ui(large_ui)
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

func _styled_panel(parent: Node, location: Vector2, extent: Vector2) -> PanelContainer:
    var panel := PanelContainer.new()
    panel.position = location
    panel.custom_minimum_size = extent
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.043,0.063,0.125,0.89)
    style.border_color = Color(0.47,0.61,0.75,0.65)
    style.set_border_width_all(1)
    style.set_corner_radius_all(14)
    style.content_margin_left = 15
    style.content_margin_top = 10
    style.content_margin_right = 15
    style.content_margin_bottom = 10
    panel.add_theme_stylebox_override("panel",style)
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(panel)
    return panel

func _make_label(parent: Node, size: int, color: Color = Color.WHITE) -> Label:
    var label := Label.new()
    label.add_theme_font_size_override("font_size",size)
    label.add_theme_color_override("font_color",color)
    parent.add_child(label)
    return label

func _build_ui() -> void:
    var canvas := CanvasLayer.new()
    add_child(canvas)
    hud_top = _styled_panel(canvas,Vector2(16,14),Vector2(325,112))
    var top_column := VBoxContainer.new()
    top_column.add_theme_constant_override("separation",5)
    hud_top.add_child(top_column)
    hud_title = _make_label(top_column,20,Color("ffdc9f"))
    hud_stats = _make_label(top_column,18)
    hud_lamps = _styled_panel(canvas,Vector2(16,140),Vector2(325,88))
    var lamp_column := VBoxContainer.new()
    lamp_column.add_theme_constant_override("separation",3)
    hud_lamps.add_child(lamp_column)
    hud_lamps_title = _make_label(lamp_column,17,Color("c3d7ff"))
    hud_lamps_value = _make_label(lamp_column,17)
    hud_actions = _styled_panel(canvas,Vector2(16,240),Vector2(325,50))
    hud_actions_value = _make_label(hud_actions,17,Color("c8e5df"))
    banner = Label.new()
    banner.position = Vector2(375,24)
    banner.add_theme_font_size_override("font_size",25)
    banner.add_theme_color_override("font_color",Color("ffe09d"))
    canvas.add_child(banner)
    warning_label = Label.new()
    warning_label.position = Vector2(375,65)
    warning_label.add_theme_font_size_override("font_size",19)
    warning_label.add_theme_color_override("font_color",Color("fff3aa"))
    canvas.add_child(warning_label)
    # FPS badge at top right, separate from the left gameplay HUD.
    fps_panel = _styled_panel(canvas, Vector2.ZERO, Vector2(150, 48))
    fps_panel.set_anchor(SIDE_LEFT, 1.0)
    fps_panel.set_anchor(SIDE_RIGHT, 1.0)
    fps_panel.offset_left = -166.0
    fps_panel.offset_right = -16.0
    fps_panel.offset_top = 14.0
    fps_panel.offset_bottom = 62.0
    fps_label = _make_label(fps_panel, 18, Color("8ee5ac"))
    fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    fps_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    fps_label.text = "FPS  --"
    fps_panel.visible = false
    score_panel = VBoxContainer.new()
    score_panel.position = Vector2(380,120)
    score_panel.visible = false
    canvas.add_child(score_panel)
    _make_label(score_panel,23,Color("ffdc9f")).text = "LƯU ĐIỂM — BÌNH MINH"
    score_input = LineEdit.new()
    score_input.placeholder_text = "Tên (3–12 ký tự A-Z, 0-9, _)"
    score_input.max_length = 12
    score_input.custom_minimum_size = Vector2(330,42)
    score_panel.add_child(score_input)
    var submit := Button.new()
    submit.text = "Lưu vào bảng xếp hạng"
    submit.pressed.connect(_submit_score)
    score_panel.add_child(submit)
    menu = Control.new()
    menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    canvas.add_child(menu)
    var bg := ColorRect.new()
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg.color = Color("11182c")
    bg.color.a = 0.97
    menu.add_child(bg)
    var panel := VBoxContainer.new()
    panel.position = Vector2(76,34)
    panel.add_theme_constant_override("separation",6)
    menu.add_child(panel)
    _make_label(panel,36,Color("ffd99b")).text = "ĐẢO ĐÈN LỒNG"
    _make_label(panel,17,Color("a7c8df")).text = "BÌNH MINH — v1.0.0"
    for index in range(1,4):
        var button := Button.new()
        button.text = "Chơi Đêm %d  ·  %s" % [index,["Đảo Bến","Đảo Cầu","Đảo Chuông"][index-1]]
        button.custom_minimum_size = Vector2(360,39)
        button.pressed.connect(_begin_night.bind(index))
        panel.add_child(button)
    var resume := Button.new()
    resume.text = "Tiếp tục (Esc)"
    resume.pressed.connect(_resume)
    panel.add_child(resume)
    var ranking_button := Button.new()
    ranking_button.text = "Bảng xếp hạng  ·  Top 10"
    ranking_button.pressed.connect(_toggle_ranking)
    panel.add_child(ranking_button)
    ranking_panel = VBoxContainer.new()
    ranking_panel.visible = false
    ranking_panel.position = Vector2(480,100)
    ranking_panel.custom_minimum_size = Vector2(440,420)
    menu.add_child(ranking_panel)
    var accessibility := CheckBox.new()
    accessibility.text = "Bảng màu dễ phân biệt"
    accessibility.button_pressed = accessible_colors
    accessibility.toggled.connect(_set_accessible_colors)
    panel.add_child(accessibility)
    var reduce := CheckBox.new()
    reduce.text = "Giảm chuyển động / hiệu ứng nhấp nháy"
    reduce.button_pressed = reduced_motion
    reduce.toggled.connect(_set_reduced_motion)
    panel.add_child(reduce)
    var large := CheckBox.new()
    large.text = "Chữ lớn x1.25"
    large.button_pressed = large_ui
    large.toggled.connect(_set_large_ui)
    panel.add_child(large)
    _make_label(panel,16,Color("a7c8df")).text = "ĐỔI PHÍM ĐIỀU KHIỂN"
    var grid := GridContainer.new()
    grid.columns = 4
    panel.add_child(grid)
    for action in ["left","right","forward","back","jump","dash","interact","pulse","pause"]:
        var button := Button.new()
        button.custom_minimum_size = Vector2(136,36)
        button.pressed.connect(_choose_binding.bind(action))
        binding_widgets[action] = button
        grid.add_child(button)
    _refresh_binding_buttons()
    var defaults := Button.new()
    defaults.text = "Khôi phục phím mặc định"
    defaults.pressed.connect(_restore_bindings)
    panel.add_child(defaults)

func _set_reduced_motion(enabled: bool) -> void:
    reduced_motion = enabled
    settings_store.set_value("accessibility","reduced_motion",enabled)
    settings_store.save("user://lantern_settings.cfg")

func _set_large_ui(enabled: bool) -> void:
    large_ui = enabled
    settings_store.set_value("accessibility","large_ui",enabled)
    settings_store.save("user://lantern_settings.cfg")
    var multiplier: float = 1.25 if enabled else 1.0
    hud_title.add_theme_font_size_override("font_size",int(20*multiplier))
    hud_stats.add_theme_font_size_override("font_size",int(18*multiplier))
    hud_lamps_title.add_theme_font_size_override("font_size",int(17*multiplier))
    hud_lamps_value.add_theme_font_size_override("font_size",int(17*multiplier))
    hud_actions_value.add_theme_font_size_override("font_size",int(17*multiplier))

func _refresh_binding_buttons() -> void:
    var translations := {"left":"Trái","right":"Phải","forward":"Tiến","back":"Lùi","jump":"Nhảy","dash":"Lướt","interact":"Tương tác","pulse":"Tỏa sáng","pause":"Tạm dừng"}
    for action in control_bindings.keys():
        binding_widgets[action].text = "%s: %s" % [translations[action], OS.get_keycode_string(int(control_bindings[action]))]

func _choose_binding(action: String) -> void:
    remap_wait = action
    warning_label.text = "Nhấn phím mới cho %s (Esc để hủy)" % action

func _restore_bindings() -> void:
    control_bindings = {"left":KEY_A,"right":KEY_D,"forward":KEY_W,"back":KEY_S,"jump":KEY_SPACE,"dash":KEY_SHIFT,"interact":KEY_E,"pulse":KEY_Q,"pause":KEY_ESCAPE}
    settings_store.set_value("controls","bindings",control_bindings)
    settings_store.save("user://lantern_settings.cfg")
    _refresh_binding_buttons()
    warning_label.text = ""

func _submit_score() -> void:
    if result_submitted or game == null: return
    var name: String = score_input.text.strip_edges()
    if not Leaderboard.valid_name(name):
        warning_label.text = "Tên cần 3–12 ký tự: A-Z a-z 0-9 _"
        return
    Leaderboard.add_entry(name,run_score,run_wins,game.current_seed)
    result_submitted = true
    score_panel.visible = false
    warning_label.text = "Đã lưu điểm! Mở menu để xem Top 10."

func _toggle_ranking() -> void:
    ranking_panel.visible = not ranking_panel.visible
    if not ranking_panel.visible: return
    for node in ranking_panel.get_children(): node.queue_free()
    _make_label(ranking_panel,27,Color("ffdc9f")).text = "BẢNG XẾP HẠNG  ·  TOP 10"
    var entries: Array = Leaderboard.load_entries()
    if entries.is_empty():
        _make_label(ranking_panel,18).text = "Chưa có lượt chơi được lưu."
    for index in range(entries.size()):
        var entry: Dictionary = entries[index]
        _make_label(ranking_panel,18).text = "%02d   %-12s    %6d điểm   ·   %d đêm" % [index+1,str(entry.get("name","")),int(entry.get("score",0)),int(entry.get("nights_won",0))]

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
    if value != expected_next_night:
        run_score = 0
        run_wins = 0
    selected_night = value
    result_recorded = false
    result_submitted = false
    score_panel.visible = false
    warning_label.text = ""
    if game_root != null:
        game_root.queue_free()
        shade_visuals.clear()
        mote_visuals.clear()
        drifter_visuals.clear()
        charm_visuals.clear()
        lantern_visuals.clear()
        ambient_fireflies.clear()
    game = Core.new()
    game.set_seed(int(Time.get_ticks_usec()))
    game.reset(selected_night)
    game_root = Node3D.new()
    game_root.name = "ProceduralWorld"
    add_child(game_root)
    _build_world()
    _decorate_world()
    started = true
    paused_ui = false
    menu.visible = false
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _build_world() -> void:
    var world := WorldEnvironment.new()
    var env := Environment.new()
    # Gradient sky from deep night to lavender dawn to peach sunrise.
    dawn_sky = ProceduralSkyMaterial.new()
    dawn_sky.sky_top_color = Color("12142d")
    dawn_sky.sky_horizon_color = Color("30264c")
    dawn_sky.ground_horizon_color = Color("252940")
    dawn_sky.ground_bottom_color = Color("111522")
    var sky := Sky.new()
    sky.sky_material = dawn_sky
    env.background_mode = Environment.BG_SKY
    env.sky = sky
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("77739d")
    env.ambient_light_energy = 0.35
    dawn_environment = env
    world.environment = env
    game_root.add_child(world)
    dawn_sun = DirectionalLight3D.new()
    dawn_sun.rotation_degrees = Vector3(-18,-30,0)
    dawn_sun.light_color = Color("bcacf2")
    dawn_sun.light_energy = 0.16
    game_root.add_child(dawn_sun)
    dawn_last_tick = -100
    _update_daybreak(true)
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
    shade_body_normal = _material(Color("24132e"))
    shade_body_access = _material(Color("00b3ff"))
    shade_eye_material = _material(Color("e7bdff"),true)
    lantern_on_material = _material(Color("ffca64"),true)
    lantern_off_material = _material(Color("71607e"))
    lantern_access_on_material = _material(Color("ffe9a7"),true)
    lantern_access_off_material = _material(Color("333743"))
    lantern_bar_material = _material(Color("87d981"))
    lantern_bar_warning_material = _material(Color("ff6d6d"))
    lantern_bar_access_material = _material(Color("ffffff"))
    _sync_visuals()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        yaw -= event.relative.x*0.003
    if event is InputEventKey and event.pressed and not event.echo:
        if remap_wait != "":
            if event.keycode != KEY_ESCAPE:
                var duplicate: String = ""
                for action in control_bindings.keys():
                    if action != remap_wait and int(control_bindings[action]) == event.keycode:
                        duplicate = action
                if duplicate != "":
                    warning_label.text = "Phím đã được gán cho %s. Chọn phím khác." % duplicate
                    return
                control_bindings[remap_wait] = event.keycode
                settings_store.set_value("controls","bindings",control_bindings)
                settings_store.save("user://lantern_settings.cfg")
                _refresh_binding_buttons()
            remap_wait = ""
            warning_label.text = ""
            return
        if event.keycode == KEY_F3 and started:
            fps_visible = not fps_visible
            fps_panel.visible = fps_visible and not menu.visible
            get_viewport().set_input_as_handled()
            return
        if event.keycode == int(control_bindings["pause"]):
            if started:
                paused_ui = not paused_ui
                menu.visible = paused_ui
                Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if paused_ui else Input.MOUSE_MODE_CAPTURED)
        elif event.keycode == KEY_R and started:
            _begin_night(selected_night)

func _process(delta: float) -> void:
    # A small redraw interval avoids changing label text every rendered frame.
    if fps_panel == null:
        return
    fps_panel.visible = started and fps_visible and not menu.visible
    if not fps_panel.visible:
        fps_update_elapsed = 0.0
        return
    fps_update_elapsed += delta
    if fps_update_elapsed >= 0.2:
        fps_update_elapsed = 0.0
        var fps: int = Engine.get_frames_per_second()
        fps_label.text = "FPS  %d" % fps
        var tint: Color = Color("8ee5ac") if fps >= 60 else (Color("ffdc9f") if fps >= 30 else Color("ff9696"))
        fps_label.add_theme_color_override("font_color", tint)

func _physics_process(_delta: float) -> void:
    if not started or game == null: return
    if not paused_ui and game.state == "playing":
        var move: Vector2 = Vector2(float(int(Input.is_key_pressed(int(control_bindings["left"])))-int(Input.is_key_pressed(int(control_bindings["right"])))),float(int(Input.is_key_pressed(int(control_bindings["forward"])))-int(Input.is_key_pressed(int(control_bindings["back"])))))
        game.step(move,rad_to_deg(yaw),{
            "jump":Input.is_key_pressed(int(control_bindings["jump"])),
            "dash":Input.is_key_pressed(int(control_bindings["dash"])),
            "interact":Input.is_key_pressed(int(control_bindings["interact"])),
            "pulse":Input.is_key_pressed(int(control_bindings["pulse"]))
        })
        game.drain_events()
    _sync_visuals()

func _update_daybreak(force: bool = false) -> void:
    if game == null or dawn_sky == null or dawn_environment == null or dawn_sun == null:
        return
    # Updating sky resources at 10 Hz avoids rebuilding sky radiance every frame.
    # Progress itself comes from simulation time, so Pause freezes the sunrise.
    if not force and game.tick - dawn_last_tick < 6:
        return
    dawn_last_tick = game.tick
    var total: float = maxf(1.0, game.initial_time_left_s)
    var elapsed: float = clampf(1.0 - game.get_time_left() / total, 0.0, 1.0)
    # 0–42%: night. 42–75%: violet/pink predawn. 75–100%: sunrise.
    var predawn: float = smoothstep(0.42, 0.75, elapsed)
    var sunrise: float = smoothstep(0.75, 1.0, elapsed)

    var top_color: Color = Color("12142d").lerp(Color("554a85"), predawn)
    top_color = top_color.lerp(Color("91b6d8"), sunrise)
    var horizon_color: Color = Color("30264c").lerp(Color("b56c95"), predawn)
    horizon_color = horizon_color.lerp(Color("ffbc7a"), sunrise)
    var ground_horizon: Color = Color("252940").lerp(Color("72677d"), predawn)
    ground_horizon = ground_horizon.lerp(Color("c9a18a"), sunrise)
    dawn_sky.sky_top_color = top_color
    dawn_sky.sky_horizon_color = horizon_color
    dawn_sky.ground_horizon_color = ground_horizon
    dawn_sky.ground_bottom_color = Color("111522").lerp(Color("807a73"), sunrise)

    var ambient_color: Color = Color("77739d").lerp(Color("a794b1"), predawn)
    dawn_environment.ambient_light_color = ambient_color.lerp(Color("ffe5bf"), sunrise)
    dawn_environment.ambient_light_energy = lerpf(0.35, 0.72, predawn) + 0.30 * sunrise
    dawn_sun.light_color = Color("bcacf2").lerp(Color("f6ac94"), predawn).lerp(Color("ffedc3"), sunrise)
    dawn_sun.light_energy = lerpf(0.16, 0.55, predawn) + 0.75 * sunrise
    dawn_sun.rotation_degrees.x = lerpf(-18.0, -50.0, sunrise)

func _sync_visuals() -> void:
    if game == null or may == null: return
    _update_daybreak()
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
        var orb_material: StandardMaterial3D = (lantern_access_off_material if accessible_colors else lantern_off_material) if (not lit or blink) else (lantern_access_on_material if accessible_colors else lantern_on_material)
        if visuals["orb"].material_override != orb_material:
            visuals["orb"].material_override = orb_material
        visuals["light"].light_energy = 1.8 if lit and not blink else 0
        var height: float = maxf(0.03,float(lantern["fuel"])/100.0)
        visuals["bar"].scale.y = height
        visuals["bar"].position.y = 0.9+0.5*height
        visuals["bar"].visible = lit
        var bar_material: StandardMaterial3D = lantern_bar_access_material if accessible_colors else (lantern_bar_warning_material if low_fuel else lantern_bar_material)
        if visuals["bar"].material_override != bar_material:
            visuals["bar"].material_override = bar_material
        visuals["worn"].visible = not lit
    var active_motes: Dictionary = {}
    for mote in game.motes:
        var id: String = str(mote["id"])
        active_motes[id] = true
        if not mote_visuals.has(id):
            mote_visuals[id] = _ball(game_root,0.24,mote["pos"] + Vector3(0,0.8,0),Color("ffe187"),true)
        else:
            mote_visuals[id].position = mote["pos"] + Vector3(0,0.8,0)
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
        var children: Array[Node] = shade_visuals[id].get_children()
        for j in range(children.size()):
            var child: Node = children[j]
            if child is MeshInstance3D:
                var wanted: StandardMaterial3D = shade_eye_material if j>0 else (shade_body_access if accessible_colors else shade_body_normal)
                if child.material_override != wanted:
                    child.material_override = wanted
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
    if not reduced_motion and not benchmark_visuals:
        var tm: float = float(Time.get_ticks_msec())/1000.0
        for i in range(ambient_fireflies.size()):
            var particle: Node3D = ambient_fireflies[i]
            if is_instance_valid(particle):
                particle.position.y = float(particle.get_meta("base_y")) + 0.24*sin(tm*1.2+float(i)*0.77)
    var progress: String = ""
    var low_count: int = 0
    for lantern in game.lanterns:
        var fuel: float = float(lantern["fuel"])
        var lit: bool = bool(lantern["lit"])
        var status: String = ("%02d%%" % int(fuel)) if lit else ("%d/10" % int(lantern["deposited"]))
        if lit and fuel < 30.0: low_count += 1
        progress += "%s %s    " % [str(lantern["id"]),status]
        if str(lantern["id"]) == "L4": progress += "\n"
    var required: int = int(ceil(float(game.lantern_count)*0.6))
    hud_title.text = "✦  ĐẢO ĐÈN LỒNG    /    ĐÊM %d" % game.night
    hud_stats.text = "♥ %d     ✧ %d / %d     ★ %d\n◷ %.0f giây    ·    Đèn %d/%d" % [game.flames,game.carried,game.get_capacity(),game.score,game.get_time_left(),game.get_lit_count(),required]
    hud_lamps_title.text = "✷  NHIÊN LIỆU ĐÈN"
    hud_lamps_value.text = progress
    hud_actions_value.text = "LƯỚT  %.1fs      TỎA SÁNG  %.1fs" % [float(game.dash_cooldown)/60.0,float(game.pulse_cooldown)/60.0]
    if low_count > 0:
        warning_label.text = "⚠  %d đèn sắp cạn dầu!" % low_count
    elif remap_wait == "":
        warning_label.text = ""
    if game.state == "won": banner.text = "✦  BÌNH MINH!  Bạn đã bảo vệ hòn đảo."
    elif game.state == "lost": banner.text = "MÀN ĐÊM CHƯA TAN — Hãy thử lại."
    else: banner.text = ""
    if game.state in ["won","lost"] and not result_recorded:
        result_recorded = true
        run_score += game.score
        if game.state == "won":
            run_wins += 1
            expected_next_night = mini(game.night+1,3)
    if (game.state == "lost" or (game.state == "won" and game.night == 3)) and not result_submitted and not score_panel.visible:
        score_panel.visible = true

func _decorate_world() -> void:
    # Decorative-only nodes: never add a mote/shade to GameCore.
    # Deterministic scenery positions; the benchmark can disable it.
    if benchmark_visuals: return
    decoration_root = Node3D.new()
    decoration_root.name = "SceneryOnly"
    game_root.add_child(decoration_root)
    visual_rng.seed = 1000 + selected_night * 97
    var radius: float = 38.0 if selected_night == 1 else (26.0 if selected_night == 2 else 43.0)
    var tree_count: int = 38 if selected_night == 1 else (42 if selected_night == 2 else 48)
    for idx in range(tree_count):
        var angle: float = visual_rng.randf_range(0,TAU)
        var distance: float = visual_rng.randf_range(radius*0.55,radius*0.93)
        var center: Vector3 = Vector3.ZERO
        if selected_night == 2 and idx % 2 == 1: center.x = 70.0
        var spot: Vector3 = center + Vector3(cos(angle)*distance,0,sin(angle)*distance)
        var near_lantern: bool = false
        for lantern in game.lanterns:
            if spot.distance_to(lantern["pos"]) < 4.0: near_lantern = true
        if near_lantern or spot.distance_to(game.player_pos) < 6.0: continue
        var tree := Node3D.new()
        tree.position = spot
        decoration_root.add_child(tree)
        var scale_factor: float = visual_rng.randf_range(0.75,1.45)
        _box(tree,Vector3(0.43,2.9,0.43)*scale_factor,Vector3(0,1.45*scale_factor,0),Color("644638"))
        _ball(tree,1.35*scale_factor,Vector3(0,3.0*scale_factor,0),Color("386f63"))
        _ball(tree,1.05*scale_factor,Vector3(-0.65*scale_factor,3.55*scale_factor,0),Color("528877"))
        _ball(tree,0.88*scale_factor,Vector3(0.7*scale_factor,3.65*scale_factor,0),Color("2b675b"))
    for idx in range(55):
        var angle: float = visual_rng.randf_range(0,TAU)
        var distance: float = visual_rng.randf_range(8.0,radius*0.94)
        var center: Vector3 = Vector3.ZERO
        if selected_night == 2 and idx%2==1: center.x = 70.0
        var place := center + Vector3(cos(angle)*distance,0.12,sin(angle)*distance)
        var stone: bool = idx % 4 == 0
        _ball(decoration_root,0.42 if stone else 0.23,place,Color("768588") if stone else Color("9bbc86"))
    for idx in range(65):
        var a: float = visual_rng.randf_range(0,TAU)
        var r: float = visual_rng.randf_range(4.0,radius*0.94)
        var center: Vector3 = Vector3.ZERO
        if selected_night == 2 and idx%2 == 1: center.x = 70
        var orb: MeshInstance3D = _ball(decoration_root,0.075,center+Vector3(cos(a)*r,visual_rng.randf_range(1.2,3.5),sin(a)*r),Color("ffe39a"),true)
        orb.set_meta("base_y",orb.position.y)
        ambient_fireflies.append(orb)
