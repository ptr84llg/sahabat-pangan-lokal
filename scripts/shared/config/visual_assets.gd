class_name VisualAssets
extends RefCounted

const CONFIG_PATH: String = "res://resources/config/visual_asset_config.tres"

static func _config() -> VisualAssetConfig:
	var resource := load(CONFIG_PATH)
	if resource is VisualAssetConfig:
		return resource as VisualAssetConfig
	push_error("VisualAssetConfig tidak dapat dimuat.")
	return null

static func food_texture_paths() -> Dictionary:
	var config := _config()
	return config.food_texture_paths if config != null else {}

static func character_pose_texture_paths() -> Dictionary:
	var config := _config()
	return config.character_pose_texture_paths if config != null else {}

static func npc_pose_texture_paths() -> Dictionary:
	var config := _config()
	return config.npc_pose_texture_paths if config != null else {}

static func ui_texture_paths() -> Dictionary:
	var config := _config()
	return config.ui_texture_paths if config != null else {}

static func processed_food_texture_paths() -> Dictionary:
	var config := _config()
	return config.processed_food_texture_paths if config != null else {}

static func badge_texture_paths() -> Dictionary:
	var config := _config()
	return config.badge_texture_paths if config != null else {}

static func star_texture_paths() -> Dictionary:
	var config := _config()
	return config.star_texture_paths if config != null else {}

static func process_texture_paths() -> Dictionary:
	var config := _config()
	return config.process_texture_paths if config != null else {}

static func process_display_names() -> Dictionary:
	var config := _config()
	return config.process_display_names if config != null else {}

static func food_texture_path(food_id: String, fallback: String = "") -> String:
	return str(food_texture_paths().get(food_id, fallback))

static func character_pose_path(character_id: String, pose: String, fallback: String = "") -> String:
	var poses: Dictionary = character_pose_texture_paths().get(character_id, {})
	return str(poses.get(pose, fallback))

static func npc_pose_path(level_no: int, pose: String, fallback: String = "") -> String:
	var poses: Dictionary = npc_pose_texture_paths().get(str(level_no), {})
	return str(poses.get(pose, fallback))

static func ui_texture_path(asset_id: String, fallback: String = "") -> String:
	return str(ui_texture_paths().get(asset_id, fallback))

static func processed_food_texture_path(processed_food_id: String, fallback: String = "") -> String:
	return str(processed_food_texture_paths().get(processed_food_id, fallback))

static func badge_texture_path(badge_id: String, fallback: String = "") -> String:
	return str(badge_texture_paths().get(badge_id, fallback))

static func star_texture_path(star_type: String, fallback: String = "") -> String:
	return str(star_texture_paths().get(star_type, fallback))

static func process_texture_path(process_id: String, fallback: String = "") -> String:
	return str(process_texture_paths().get(process_id, fallback))

static func process_display_name(process_id: String, fallback: String = "") -> String:
	return str(process_display_names().get(process_id, fallback))