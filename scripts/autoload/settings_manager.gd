extends Node

const AUDIO_SETTINGS_PATH: String = "user://audio_settings.cfg"
const AUDIO_SECTION: String = "audio"

var state: Dictionary = {
	"muted": false,
	"music_volume": 0.80,
	"sfx_volume": 0.80,
	"button_hover_enabled": true,
	"button_click_enabled": true,
	"mouse_click_enabled": true
}

var _initialized: bool = false
var _persistent_audio_loaded: bool = false


func initialize() -> void:
	if _initialized:
		return

	_initialized = true
	_ensure_defaults()
	_persistent_audio_loaded = _load_persistent_audio_settings()


func import_state(payload: Dictionary = {}) -> void:
	initialize()

	if payload.is_empty():
		return

	var persistent_muted: bool = bool(
		state.get("muted", false)
	)
	var persistent_music: float = _clamp_volume(
		state.get("music_volume", 0.80)
	)
	var persistent_sfx: float = _clamp_volume(
		state.get("sfx_volume", 0.80)
	)
	var persistent_button_hover: bool = bool(
		state.get("button_hover_enabled", true)
	)
	var persistent_button_click: bool = bool(
		state.get("button_click_enabled", true)
	)
	var persistent_mouse_click: bool = bool(
		state.get("mouse_click_enabled", true)
	)

	for key_variant in payload.keys():
		var key: String = str(key_variant)
		state[key] = payload.get(key_variant)

	_ensure_defaults()

	if _persistent_audio_loaded:
		state["muted"] = persistent_muted
		state["music_volume"] = persistent_music
		state["sfx_volume"] = persistent_sfx
		state["button_hover_enabled"] = persistent_button_hover
		state["button_click_enabled"] = persistent_button_click
		state["mouse_click_enabled"] = persistent_mouse_click
		return

	var payload_has_audio: bool = (
		payload.has("muted")
		or payload.has("music_volume")
		or payload.has("sfx_volume")
		or payload.has("button_hover_enabled")
		or payload.has("button_click_enabled")
		or payload.has("mouse_click_enabled")
	)

	if payload_has_audio:
		_save_persistent_audio_settings()
		_persistent_audio_loaded = true


func export_state() -> Dictionary:
	initialize()
	return state.duplicate(true)


func get_flag(
	key: String,
	default_value: bool = false
) -> bool:
	initialize()
	return bool(state.get(key, default_value))


func set_flag(
	key: String,
	value: bool
) -> void:
	initialize()
	state[key] = bool(value)

	if (
		key == "muted"
		or key == "button_hover_enabled"
		or key == "button_click_enabled"
		or key == "mouse_click_enabled"
	):
		_save_persistent_audio_settings()
		_persistent_audio_loaded = true

	SaveManager.request_save()


func get_value(
	key: String,
	default_value
):
	initialize()
	return state.get(key, default_value)


func set_value(
	key: String,
	value
) -> void:
	initialize()

	if key == "music_volume" or key == "sfx_volume":
		state[key] = _clamp_volume(value)
		_save_persistent_audio_settings()
		_persistent_audio_loaded = true
	else:
		state[key] = value

	SaveManager.request_save()


func _ensure_defaults() -> void:
	if not state.has("muted"):
		state["muted"] = false

	if not state.has("music_volume"):
		state["music_volume"] = 0.80

	if not state.has("sfx_volume"):
		state["sfx_volume"] = 0.80

	if not state.has("button_hover_enabled"):
		state["button_hover_enabled"] = true

	if not state.has("button_click_enabled"):
		state["button_click_enabled"] = true

	if not state.has("mouse_click_enabled"):
		state["mouse_click_enabled"] = true

	state["muted"] = bool(
		state.get("muted", false)
	)
	state["music_volume"] = _clamp_volume(
		state.get("music_volume", 0.80)
	)
	state["sfx_volume"] = _clamp_volume(
		state.get("sfx_volume", 0.80)
	)
	state["button_hover_enabled"] = bool(
		state.get("button_hover_enabled", true)
	)
	state["button_click_enabled"] = bool(
		state.get("button_click_enabled", true)
	)
	state["mouse_click_enabled"] = bool(
		state.get("mouse_click_enabled", true)
	)


func _load_persistent_audio_settings() -> bool:
	var config: ConfigFile = ConfigFile.new()
	var load_error: Error = config.load(AUDIO_SETTINGS_PATH)

	if load_error != OK:
		return false

	state["muted"] = bool(
		config.get_value(
			AUDIO_SECTION,
			"muted",
			state.get("muted", false)
		)
	)
	state["music_volume"] = _clamp_volume(
		config.get_value(
			AUDIO_SECTION,
			"music_volume",
			state.get("music_volume", 0.80)
		)
	)
	state["sfx_volume"] = _clamp_volume(
		config.get_value(
			AUDIO_SECTION,
			"sfx_volume",
			state.get("sfx_volume", 0.80)
		)
	)

	state["button_hover_enabled"] = bool(
		config.get_value(
			AUDIO_SECTION,
			"button_hover_enabled",
			state.get("button_hover_enabled", true)
		)
	)
	state["button_click_enabled"] = bool(
		config.get_value(
			AUDIO_SECTION,
			"button_click_enabled",
			state.get("button_click_enabled", true)
		)
	)
	state["mouse_click_enabled"] = bool(
		config.get_value(
			AUDIO_SECTION,
			"mouse_click_enabled",
			state.get("mouse_click_enabled", true)
		)
	)

	return true


func _save_persistent_audio_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value(
		AUDIO_SECTION,
		"muted",
		bool(state.get("muted", false))
	)
	config.set_value(
		AUDIO_SECTION,
		"music_volume",
		_clamp_volume(state.get("music_volume", 0.80))
	)
	config.set_value(
		AUDIO_SECTION,
		"sfx_volume",
		_clamp_volume(state.get("sfx_volume", 0.80))
	)
	config.set_value(
		AUDIO_SECTION,
		"button_hover_enabled",
		bool(state.get("button_hover_enabled", true))
	)
	config.set_value(
		AUDIO_SECTION,
		"button_click_enabled",
		bool(state.get("button_click_enabled", true))
	)
	config.set_value(
		AUDIO_SECTION,
		"mouse_click_enabled",
		bool(state.get("mouse_click_enabled", true))
	)

	var save_error: Error = config.save(AUDIO_SETTINGS_PATH)

	if save_error != OK:
		push_warning(
			"Audio settings could not be saved."
		)


func _clamp_volume(value) -> float:
	return clampf(float(value), 0.0, 1.0)
