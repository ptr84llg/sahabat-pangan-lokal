extends Node

const CONFIG_PATH: String = "res://resources/config/navigation_config.tres"

var config: NavigationConfig

func _ready() -> void:
	var loaded := load(CONFIG_PATH)
	if loaded is NavigationConfig:
		config = loaded as NavigationConfig
	else:
		push_error("NavigationConfig tidak dapat dimuat.")

func goto(scene_key: String) -> void:
	if config == null:
		push_error("NavigationConfig belum tersedia.")
		return

	var path: String = str(config.scene_paths.get(scene_key, ""))

	if path.is_empty():
		push_error("Scene key tidak dikenal: %s" % scene_key)
		return

	get_tree().change_scene_to_file(path)