class_name PresentationRegistry
extends RefCounted

const CONFIG_PATH: String = "res://resources/config/presentation_config.tres"

static func _config() -> PresentationConfig:
	var resource := load(CONFIG_PATH)
	if resource is PresentationConfig:
		return resource as PresentationConfig
	push_error("PresentationConfig tidak dapat dimuat.")
	return null

static func level_background_paths() -> Dictionary:
	var config := _config()
	return config.level_background_paths if config != null else {}

static func level_intro_names() -> Dictionary:
	var config := _config()
	return config.level_intro_names if config != null else {}

static func level_intro_fallback() -> Dictionary:
	var config := _config()
	return config.level_intro_fallback if config != null else {}