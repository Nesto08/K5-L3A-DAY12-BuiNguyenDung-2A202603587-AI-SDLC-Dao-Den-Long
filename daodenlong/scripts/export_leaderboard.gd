extends SceneTree
const Leaderboard = preload("res://scripts/leaderboard.gd")
func _initialize() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() != 2 or args[0] != "--export-leaderboard":
        printerr("Usage: --export-leaderboard out.json")
        quit(2)
        return
    if not Leaderboard.export_json(args[1]):
        printerr("Could not export leaderboard")
        quit(1)
        return
    print("Exported leaderboard: ",args[1])
    quit(0)
