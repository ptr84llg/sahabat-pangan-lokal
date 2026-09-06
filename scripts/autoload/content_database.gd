extends Node

const MASTER_PATH := "res://data/content_master_v1.1.json"
const LEVEL1_PATH := "res://data/levels/level_01.json"
const LEVEL2_PATH := "res://data/levels/level_02.json"
const LEVEL3_PATH := "res://data/levels/level_03.json"
const LEVEL4_PATH := "res://data/levels/level_04.json"
const LEVEL5_PATH := "res://data/levels/level_05.json"

var initialized := false
var content_version := ""
var master: Dictionary = {}
var foods_by_id: Dictionary = {}
var groups_by_id: Dictionary = {}
var processed_foods_by_id: Dictionary = {}
var processes_by_id: Dictionary = {}
var level_01: Dictionary = {}
var level_02: Dictionary = {}
var level_03: Dictionary = {}
var level_04: Dictionary = {}
var level_05: Dictionary = {}

func initialize() -> bool:
    if initialized:
        return true
    master = _load_json(MASTER_PATH)
    if master.is_empty():
        push_error("Content master gagal dimuat: %s" % MASTER_PATH)
        return false
    content_version = str(master.get("content_version", "unknown"))

    foods_by_id.clear()
    for food in master.get("foods", []):
        foods_by_id[str(food.get("food_id", ""))] = food

    groups_by_id.clear()
    for group in master.get("groups", []):
        groups_by_id[str(group.get("group_id", ""))] = group

    processed_foods_by_id.clear()
    for processed_food in master.get("processed_foods", []):
        processed_foods_by_id[str(processed_food.get("processed_food_id", ""))] = processed_food

    processes_by_id.clear()
    for process in master.get("processes", []):
        processes_by_id[str(process.get("process_id", ""))] = process

    level_01 = _load_json(LEVEL1_PATH)
    level_02 = _load_json(LEVEL2_PATH)
    level_03 = _load_json(LEVEL3_PATH)
    level_04 = _load_json(LEVEL4_PATH)
    level_05 = _load_json(LEVEL5_PATH)
    if level_01.is_empty() or level_02.is_empty() or level_03.is_empty() or level_04.is_empty() or level_05.is_empty():
        push_error("Satu atau lebih runtime level content gagal dimuat")
        return false
    initialized = true
    return true

func get_food(food_id: String) -> Dictionary:
    return foods_by_id.get(food_id, {}).duplicate(true)

func get_group(group_id: String) -> Dictionary:
    return groups_by_id.get(group_id, {}).duplicate(true)

func get_group_name(group_id: String) -> String:
    return str(groups_by_id.get(group_id, {}).get("display_name", group_id))

func get_processed_food(processed_food_id: String) -> Dictionary:
    return processed_foods_by_id.get(processed_food_id, {}).duplicate(true)

func get_process(process_id: String) -> Dictionary:
    return processes_by_id.get(process_id, {}).duplicate(true)

func get_process_name(process_id: String) -> String:
    return str(processes_by_id.get(process_id, {}).get("display_name", process_id))

func get_foods(food_ids: Array) -> Array[Dictionary]:
    var out: Array[Dictionary] = []
    for food_id_value in food_ids:
        var food := get_food(str(food_id_value))
        if not food.is_empty():
            out.append(food)
    return out

func get_processed_foods(processed_ids: Array) -> Array[Dictionary]:
    var out: Array[Dictionary] = []
    for processed_id_value in processed_ids:
        var item := get_processed_food(str(processed_id_value))
        if not item.is_empty():
            out.append(item)
    return out

func get_level_01_foods() -> Array[Dictionary]:
    var out := get_foods(level_01.get("food_ids", []))
    for food in out:
        var food_id := str(food.get("food_id", ""))
        var detail: Dictionary = level_01.get("food_details", {}).get(food_id, {})
        food.merge(detail, true)
    return out

func get_level_02_foods() -> Array[Dictionary]:
    var out := get_foods(level_02.get("food_ids", []))
    for food in out:
        var food_id := str(food.get("food_id", ""))
        var detail: Dictionary = level_02.get("food_details", {}).get(food_id, {})
        food.merge(detail, true)
        food["group_name"] = get_group_name(str(food.get("group_id", "")))
        food["is_new_in_current_level"] = int(food.get("introduced_level", 0)) == 2
    return out

func get_level_03_foods() -> Array[Dictionary]:
    var out := get_foods(level_03.get("food_ids", []))
    for food in out:
        var food_id := str(food.get("food_id", ""))
        food["group_name"] = get_group_name(str(food.get("group_id", "")))
        food["info_level_03"] = str(level_03.get("information", {}).get(food_id, ""))
    return out

func get_level_04_processed_foods() -> Array[Dictionary]:
    var out: Array[Dictionary] = []
    for processed_id_value in level_04.get("processed_food_ids", master.get("level_4", {}).get("processed_food_ids", [])):
        var processed_id := str(processed_id_value)
        var item := get_processed_food(processed_id)
        if item.is_empty():
            continue
        item["process_name"] = get_process_name(str(item.get("process_id", "")))
        item["ingredient_a_name"] = str(get_food(str(item.get("ingredient_a_id", ""))).get("display_name", ""))
        item["ingredient_b_name"] = str(get_food(str(item.get("ingredient_b_id", ""))).get("display_name", ""))
        item["info_level_04"] = str(level_04.get("information", {}).get(processed_id, ""))
        out.append(item)
    return out

func get_level_01_config() -> Dictionary:
    return level_01.duplicate(true)

func get_level_02_config() -> Dictionary:
    return level_02.duplicate(true)

func get_level_03_config() -> Dictionary:
    return level_03.duplicate(true)

func get_level_04_config() -> Dictionary:
    return level_04.duplicate(true)

func get_level_05_config() -> Dictionary:
    return level_05.duplicate(true)

func _load_json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {}
    var parsed = JSON.parse_string(file.get_as_text())
    if parsed is Dictionary:
        return parsed
    return {}
