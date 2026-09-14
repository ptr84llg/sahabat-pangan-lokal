extends Control

const TYPEWRITER_CHARACTERS_PER_SECOND: float = 20.0

const NPC_NAMES: Dictionary = {
	1: "IBU",
	2: "IBU GURU",
	3: "PEDAGANG",
	4: "NENEK",
	5: "LURAH"
}

@export var name_inactive_style: StyleBoxFlat
@export var name_active_style: StyleBoxFlat

@onready var ui_root: Control = %UIRoot
@onready var npc_portrait: TextureRect = %NPCPortrait
@onready var player_portrait: TextureRect = %PlayerPortrait
@onready var npc_name_panel: PanelContainer = %NPCNamePanel
@onready var player_name_panel: PanelContainer = %PlayerNamePanel
@onready var npc_name: Label = %NPCName
@onready var player_name: Label = %PlayerName
@onready var dialogue_text: RichTextLabel = %DialogueText
@onready var skip_typing_checkbox: CheckBox = %SkipTypingCheckBox
@onready var continue_button: Button = %ContinueButton
@onready var portrait_blocker: Control = %PortraitBlocker

var _source_panel: Control
var _continue_target: Button
var _level_no: int = 0
var _speaker_name: String = ""
var _last_presented_body_text: String = ""
var _typing_active: bool = false
var _typing_progress: float = 0.0
var _typing_total_characters: int = 0
var _typing_generation: int = 0


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_force_landscape()
	skip_typing_checkbox.button_pressed = bool(
		SettingsManager.get_flag(
			"dialogue_skip_typing",
			false
		)
	)
	skip_typing_checkbox.toggled.connect(
		_on_skip_typing_toggled
	)
	continue_button.pressed.connect(_on_continue_pressed)
	get_viewport().size_changed.connect(_check_orientation)
	_check_orientation()


func present(
	source_panel: Control,
	level_no: int,
	speaker_name: String,
	body_text: String,
	continue_target: Button
) -> void:
	var was_visible: bool = visible
	_source_panel = source_panel
	_continue_target = continue_target
	_level_no = level_no
	_speaker_name = speaker_name.strip_edges()

	if is_instance_valid(_source_panel):
		_source_panel.visible = false

	var formatted_body_text: String = _format_dialogue_text(
		body_text
	)

	var body_changed: bool = (
		_last_presented_body_text != formatted_body_text
	)

	if not was_visible:
		AudioManager.play_sfx("scene_dialogue_open")
	elif body_changed:
		AudioManager.play_sfx("dialogue_change")

	_last_presented_body_text = formatted_body_text
	dialogue_text.text = (
		"[center]" +
		formatted_body_text.strip_edges() +
		"[/center]"
	)

	_refresh_character_state()
	visible = true
	_check_orientation()

	if not was_visible or body_changed:
		_prepare_typing_wait()

		var reveal_generation: int = _typing_generation
		var start_typing_callback := Callable(
			self,
			"_start_typing_if_generation"
		).bind(reveal_generation)
		var name_panels: Array = [
			npc_name_panel,
			player_name_panel
		]

		if not was_visible:
			ScreenMotionPresenter.dialogue_enter(
				npc_portrait,
				player_portrait,
				name_panels,
				dialogue_text,
				start_typing_callback
			)
		else:
			ScreenMotionPresenter.dialogue_line_reveal(
				name_panels,
				dialogue_text,
				start_typing_callback
			)


func hide_presenter() -> void:
	_typing_generation += 1
	_typing_active = false
	_typing_progress = 0.0
	_typing_total_characters = 0
	dialogue_text.visible_characters = -1
	visible = false
	_source_panel = null
	_continue_target = null
	_last_presented_body_text = ""


func _process(delta: float) -> void:
	if not _typing_active:
		return

	_typing_progress += (
		delta * TYPEWRITER_CHARACTERS_PER_SECOND
	)

	var visible_count: int = mini(
		_typing_total_characters,
		int(floor(_typing_progress))
	)

	if visible_count > dialogue_text.visible_characters:
		dialogue_text.visible_characters = visible_count

	if visible_count >= _typing_total_characters:
		_finish_typing()


func _prepare_typing_wait() -> void:
	_typing_generation += 1
	_typing_active = false
	_typing_progress = 0.0
	dialogue_text.visible_characters = 0
	_typing_total_characters = (
		dialogue_text.get_total_character_count()
	)
	continue_button.disabled = true


func _start_typing_if_generation(
	generation: int
) -> void:
	if generation != _typing_generation:
		return

	if not visible:
		return

	_start_typing()


func _start_typing() -> void:
	_typing_active = false
	_typing_progress = 0.0
	dialogue_text.visible_characters = 0
	_typing_total_characters = (
		dialogue_text.get_total_character_count()
	)

	if skip_typing_checkbox.button_pressed:
		_finish_typing()
		return

	continue_button.disabled = true

	if _typing_total_characters <= 0:
		_finish_typing()
		return

	_typing_active = true


func _finish_typing() -> void:
	_typing_active = false
	_typing_progress = float(_typing_total_characters)
	dialogue_text.visible_characters = -1
	continue_button.disabled = _continue_target == null


func _format_dialogue_text(body_text: String) -> String:
	var player_display_name: String = "Pemain"

	if (
		is_instance_valid(GameState)
		and GameState.has_method("player_display_name")
	):
		player_display_name = str(
			GameState.player_display_name()
		).strip_edges()

	if player_display_name.is_empty():
		player_display_name = "Pemain"

	return body_text.replace(
		"{player_name}",
		player_display_name
	)


func _refresh_character_state() -> void:
	var npc_display_name: String = str(NPC_NAMES.get(_level_no, "NPC"))

	var player_display_name: String = "PEMAIN"

	if (
		is_instance_valid(GameState)
		and GameState.has_method("player_display_name")
	):
		player_display_name = str(
			GameState.player_display_name()
		).strip_edges().to_upper()

	if player_display_name.is_empty():
		player_display_name = "PEMAIN"

	var player_is_speaking: bool = _speaker_is_player(
		_speaker_name,
		player_display_name
	)
	var npc_is_speaking: bool = not player_is_speaking

	npc_name.text = npc_display_name
	player_name.text = player_display_name

	npc_name_panel.add_theme_stylebox_override(
		"panel",
		name_active_style if npc_is_speaking else name_inactive_style
	)
	player_name_panel.add_theme_stylebox_override(
		"panel",
		name_active_style if player_is_speaking else name_inactive_style
	)

	var npc_pose_name: String = (
		"talking"
		if npc_is_speaking
		else "standing"
	)
	var player_pose_name: String = (
		"talking"
		if player_is_speaking
		else "standing"
	)

	npc_portrait.texture = _load_texture(
		VisualAssets.npc_pose_path(_level_no, npc_pose_name)
	)

	var character_id: String = ""

	if (
		is_instance_valid(GameState)
		and GameState.has_method("selected_character_id")
	):
		character_id = str(
			GameState.selected_character_id()
		)

	player_portrait.texture = _load_texture(
		VisualAssets.character_pose_path(character_id, player_pose_name)
	)


func _speaker_is_player(
	speaker_name: String,
	player_display_name: String
) -> bool:
	var clean_speaker: String = speaker_name.strip_edges().to_lower()

	if clean_speaker.is_empty():
		return false

	if clean_speaker == "pemain":
		return true

	if clean_speaker == "player":
		return true

	return clean_speaker == player_display_name.to_lower()


func _on_skip_typing_toggled(enabled: bool) -> void:
	SettingsManager.set_flag(
		"dialogue_skip_typing",
		enabled
	)

	if enabled and _typing_active:
		_finish_typing()

func _on_continue_pressed() -> void:
	if not is_instance_valid(_continue_target):
		return

	_continue_target.emit_signal("pressed")

	var host: Node = get_parent()

	if (
		host != null
		and host.has_method("_refresh_level_dialogue_presenter")
	):
		host.call_deferred(
			"_refresh_level_dialogue_presenter"
		)


func _force_landscape() -> void:
	if DisplayServer.has_feature(
		DisplayServer.FEATURE_ORIENTATION
	):
		DisplayServer.screen_set_orientation(
			DisplayServer.SCREEN_SENSOR_LANDSCAPE
		)


func _check_orientation() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var portrait: bool = viewport_size.y > viewport_size.x

	portrait_blocker.visible = portrait
	ui_root.visible = not portrait


func _load_texture(texture_path: String) -> Texture2D:
	if texture_path.is_empty():
		return null

	if not ResourceLoader.exists(texture_path):
		return null

	var resource: Resource = load(texture_path)

	if resource is Texture2D:
		return resource as Texture2D

	return null
