extends RefCounted

const PATH: String = "user://lantern_leaderboard.json"

static func valid_name(value: String) -> bool:
    if value.length() < 3 or value.length() > 12: return false
    for i in range(value.length()):
        var code: int = value.unicode_at(i)
        if not ((code >= 65 and code <= 90) or (code >= 97 and code <= 122) or (code >= 48 and code <= 57) or code == 95):
            return false
    return true

static func load_entries() -> Array:
    if not FileAccess.file_exists(PATH): return []
    var file: FileAccess = FileAccess.open(PATH,FileAccess.READ)
    if file == null: return []
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if parsed is Dictionary and parsed.get("entries",[]) is Array:
        return parsed["entries"]
    return []

static func add_entry(name: String, score: int, nights_won: int, seed: int) -> bool:
    if not valid_name(name): return false
    var entries: Array = load_entries()
    var entry := {
        "name":name,
        "score":score,
        "nights_won":clampi(nights_won,0,3),
        "achieved_at":Time.get_datetime_string_from_system(true,false) + "Z",
        "seed":seed
    }
    entries.append(entry)
    # Stable ordering preserves earlier entries on ties.
    entries.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
        if int(a.get("score",0)) != int(b.get("score",0)):
            return int(a.get("score",0)) > int(b.get("score",0))
        return str(a.get("achieved_at","")) < str(b.get("achieved_at",""))
    )
    entries = entries.slice(0,mini(entries.size(),10))
    var file: FileAccess = FileAccess.open(PATH,FileAccess.WRITE)
    if file == null: return false
    file.store_string(JSON.stringify({"entries":entries},"  "))
    file.close()
    return true

static func export_json(path: String) -> bool:
    var file: FileAccess = FileAccess.open(path,FileAccess.WRITE)
    if file == null: return false
    file.store_string(JSON.stringify({"entries":load_entries()},"  "))
    file.close()
    return true
