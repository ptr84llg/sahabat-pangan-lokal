class_name AudioConfig
extends Resource

@export var music_tracks: Dictionary = {}
@export var sfx_tracks: Dictionary = {}
@export var shell_scene_keys: Array[String] = []
@export var game_scene_keys: Array[String] = []
@export var final_scene_sfx_keys: Array[String] = []
@export var direct_scene_music: Dictionary = {}
@export var level_scene_prefix: String = "res://scenes/levels/level_"
@export var level_music_key: String = "game"
@export var main_map_scene_key: String = "main_map"
@export var shell_music_key: String = "shell"
@export var map_music_key: String = "map"
@export var game_music_key: String = "game"
@export_range(1, 16, 1) var sfx_player_count: int = 4
@export_range(1, 8, 1) var final_scene_sfx_player_count: int = 2
@export var music_player_volume_db: float = -4.0
@export var sfx_player_volume_db: float = -2.0