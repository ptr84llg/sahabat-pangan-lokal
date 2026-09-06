extends Control

const PLAYER_POSES: Dictionary = {
	"rara": {
		"standing": "res://assets/visual/character_select/character_01_female_standing.png",
		"talking": "res://assets/visual/character_select/character_01_female_talking.png"
	},
	"budi": {
		"standing": "res://assets/visual/character_select/character_02_male_standing.png",
		"talking": "res://assets/visual/character_select/character_02_male_talking.png"
	},
	"anjani": {
		"standing": "res://assets/visual/character_select/character_03_female_standing.png",
		"talking": "res://assets/visual/character_select/character_03_female_talking.png"
	},
	"riski": {
		"standing": "res://assets/visual/character_select/character_04_male_standing.png",
		"talking": "res://assets/visual/character_select/character_04_male_talking.png"
	}
}

const NPC_PROFILES: Dictionary = {
	1: {
		"name": "IBU",
		"standing": "res://assets/visual/npc/ibu/standing.png",
		"talking": "res://assets/visual/npc/ibu/talking.png"
	},
	2: {
		"name": "IBU GURU",
		"standing": "res://assets/visual/npc/ibu_guru/standing.png",
		"talking": "res://assets/visual/npc/ibu_guru/talking.png"
	},
	3: {
		"name": "PEDAGANG",
		"standing": "res://assets/visual/npc/pedagang/standing.png",
		"talking": "res://assets/visual/npc/pedagang/talking.png"
	},
	4: {
		"name": "NENEK",
		"standing": "res://assets/visual/npc/nenek/standing.png",
		"talking": "res://assets/visual/npc/nenek/talking.png"
	},
	5: {
		"name": "LURAH",
		"standing": "res://assets/visual/npc/lurah/standing.png",
		"talking": "res://assets/visual/npc/lurah/talking.png"
	}
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
@onready var continue_button: Button = %ContinueButton
@onready var portrait_blocker: Control = %PortraitBlocker

var _source_panel: Control
var _continue_target: Button
var _level_no: int = 0
var _speaker_name: String = ""


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_force_landscape()
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
	_source_panel = source_panel
	_continue_target = continue_target
	_level_no = level_no
	_speaker_name = speaker_name.strip_edges()

	if is_instance_valid(_source_panel):
		_source_panel.visible = false

	dialogue_text.text = (
		"[center]" +
		body_text.strip_edges() +
		"[/center]"
	)

	_refresh_character_state()
	continue_button.disabled = _continue_target == null
	visible = true
	_check_orientation()


func hide_presenter() -> void:
	visible = false
	_source_panel = null
	_continue_target = null


func _refresh_character_state() -> void:
	var profile: Dictionary = NPC_PROFILES.get(
		_level_no,
		{}
	)
	var npc_display_name: String = str(
		profile.get("name", "NPC")
	)

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
		str(profile.get(npc_pose_name, ""))
	)

	var character_id: String = ""

	if (
		is_instance_valid(GameState)
		and GameState.has_method("selected_character_id")
	):
		character_id = str(
			GameState.selected_character_id()
		)

	var pose_map: Dictionary = PLAYER_POSES.get(
		character_id,
		{}
	)

	player_portrait.texture = _load_texture(
		str(pose_map.get(player_pose_name, ""))
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


