extends SceneTree

const Scene = preload("res://scenes/main.tscn")
var output_path: String = "bench.json"
var duration_s: float = 30.0
var seed_value: int = 42

func _initialize() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() % 2 != 0:
        quit(2)
        return
    for i in range(0,args.size(),2):
        match args[i]:
            "--seed": seed_value = int(args[i+1])
            "--duration": duration_s = float(args[i+1])
            "--out": output_path = args[i+1]
            _: quit(2); return
    if duration_s <= 0.0:
        quit(2)
        return
    call_deferred("_run")

func _run() -> void:
    var launch_us: int = Time.get_ticks_usec()
    DisplayServer.window_set_size(Vector2i(1280,720))
    DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    var main: Variant = Scene.instantiate()
    root.add_child(main)
    await process_frame
    main.benchmark_visuals = true
    main._begin_night(1)
    main.started = false
    main.menu.visible = false
    main.score_panel.visible = false
    main.warning_label.text = ""
    main.game.random_shades = false
    main.game.random_motes = false
    main.game.shades.clear()
    main.game.motes.clear()
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_value
    for i in range(200):
        var theta: float = TAU*float(i)/200.0
        var r: float = 5.0+sqrt(rng.randf())*32.0
        main.game.shades.append({"id":"S%d"%(i+1),"pos":Vector3(cos(theta)*r,0,sin(theta)*r),"state":"wander","stun_ticks":0,"recoil":0})
    for i in range(100):
        var theta: float = TAU*float(i)/100.0
        var r: float = 5.0+sqrt(rng.randf())*33.0
        main.game.motes.append({"id":"M%d"%(i+1),"pos":Vector3(cos(theta)*r,0,sin(theta)*r),"kind":"benchmark","ttl":-1})
    for i in range(mini(3,main.game.lanterns.size())):
        main.game.lanterns[i]["lit"] = true
        main.game.lanterns[i]["ever_lit"] = true
        main.game.lanterns[i]["fuel"] = 100.0
        main.game.lanterns[i]["fuel_units"] = 6000
    main._sync_visuals()
    await process_frame
    var load_ms: int = int((Time.get_ticks_usec()-launch_us)/1000)
    print("BENCH_FIRST_FRAME")
    var start_measure: int = Time.get_ticks_usec()
    # 3 s warmup: counts toward neither frames nor measured interval.
    while (Time.get_ticks_usec()-start_measure) < 3000000:
        await process_frame
        main._sync_visuals()
    var frame_times: Array[float] = []
    var duration_us: int = int(duration_s*1000000.0)
    var start_us: int = Time.get_ticks_usec()
    var prev_us: int = start_us
    while Time.get_ticks_usec()-start_us < duration_us:
        await process_frame
        var now_us: int = Time.get_ticks_usec()
        frame_times.append(maxf(0.01,float(now_us-prev_us)/1000.0))
        prev_us = now_us
        var seconds: float = float(now_us-start_us)/1000000.0
        var angle: float = seconds*TAU/15.0
        main._sync_visuals()
        main.cam.position = Vector3(cos(angle)*30.0,15.0,sin(angle)*30.0)
        main.cam.look_at(Vector3.ZERO,Vector3.UP)
    frame_times.sort()
    var n: int = frame_times.size()
    var total: float = 0.0
    for dt in frame_times: total += dt
    var lowest_count: int = maxi(1,int(ceil(float(n)*0.01)))
    var lowest_total: float = 0.0
    for idx in range(lowest_count):
        lowest_total += frame_times[n-1-idx]
    var p95_index: int = clampi(int(ceil(float(n)*0.95))-1,0,maxi(0,n-1))
    var result := {
        "contract_version":"1.3", "avg_fps":(1000.0*float(n)/total) if total>0.0 else 0.0,
        "p1_low_fps":(1000.0*float(lowest_count)/lowest_total) if lowest_total>0.0 else 0.0,
        "frame_ms_p95":frame_times[p95_index] if n>0 else 0.0,
        "frames":n, "load_ms":load_ms, "peak_mem_mb":null,
        "vsync_off":true,"renderer":RenderingServer.get_current_rendering_method(),"os":OS.get_name()
    }
    var file: FileAccess = FileAccess.open(output_path,FileAccess.WRITE)
    if file == null:
        printerr("Cannot write benchmark file: ",output_path)
        quit(1)
        return
    file.store_string(JSON.stringify(result,"  "))
    file.close()
    print("BENCH_RESULT ",JSON.stringify(result))
    quit(0)

