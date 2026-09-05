extends Node

const SCENES = {
    "splash": "res://scenes/app/splash_scene.tscn",
    "main_menu": "res://scenes/app/main_menu_scene.tscn",
    "player_setup": "res://scenes/app/player_setup_scene.tscn",
    "character_select": "res://scenes/app/character_select_scene.tscn",
    "intro": "res://scenes/app/intro_scene.tscn",
    "main_map": "res://scenes/app/main_map_scene.tscn",
    "level_01": "res://scenes/levels/level_01/level_01_scene.tscn",
    "level_02": "res://scenes/levels/level_02/level_02_scene.tscn",
    "level_03": "res://scenes/levels/level_03/level_03_scene.tscn",
    "level_04": "res://scenes/levels/level_04/level_04_scene.tscn",
    "level_05": "res://scenes/levels/level_05/level_05_scene.tscn"
}

func goto(scene_key: String) -> void:
    var path: String = str(SCENES.get(scene_key, ""))

    if path.is_empty():
        push_error("Scene key tidak dikenal: %s" % scene_key)
        return

    get_tree().change_scene_to_file(path)
