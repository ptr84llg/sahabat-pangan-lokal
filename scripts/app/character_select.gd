extends Control

const CHARACTER_POSE_TEXTURES := {
	"rara": {
		"standing": "res://assets/visual/character_select/character_01_female_standing.png",
		"happy": "res://assets/visual/character_select/character_01_female_happy.png"
	},
	"budi": {
		"standing": "res://assets/visual/character_select/character_02_male_standing.png",
		"happy": "res://assets/visual/character_select/character_02_male_happy.png"
	},
	"anjani": {
		"standing": "res://assets/visual/character_select/character_03_female_standing.png",
		"happy": "res://assets/visual/character_select/character_03_female_happy.png"
	},
	"riski": {
		"standing": "res://assets/visual/character_select/character_04_male_standing.png",
		"happy": "res://assets/visual/character_select/character_04_male_happy.png"
	}
}

var selected_character_id: String = ""
var available_character_ids: Array[String] = []

func _ready() -> void:
	if not GameState.has_active_run():
		SceneRouter.goto("player_setup")
		return

	available_character_ids = GameState.available_character_ids_for_current_run()

	if available_character_ids.size() < 2:
		SceneRouter.goto("player_setup")
		return

	%SlotAButton.pressed.connect(_select_character.bind(available_character_ids[0]))
	%SlotBButton.pressed.connect(_select_character.bind(available_character_ids[1]))
	%BackButton.pressed.connect(func(): SceneRouter.goto("player_setup"))
	%ContinueButton.pressed.connect(_continue_to_intro)

	UIMotion.bind_button(%SlotAButton)
	UIMotion.bind_button(%SlotBButton)
	UIMotion.bind_button(%BackButton)
	UIMotion.bind_button(%ContinueButton)

	selected_character_id = GameState.selected_character_id()

	if selected_character_id not in available_character_ids:
		selected_character_id = ""

	_render()

func _apply_character_pose(
	texture_node: TextureRect,
	character_id: String,
	use_happy_pose: bool
) -> void:
	var pose_data: Dictionary = CHARACTER_POSE_TEXTURES.get(character_id, {})
	var pose_key: String = "happy" if use_happy_pose else "standing"
	var texture_path: String = str(pose_data.get(pose_key, ""))

	if texture_path.is_empty():
		texture_path = str(
			GameState.CHARACTER_DATA.get(character_id, {}).get("texture_path", "")
		)

	if not texture_path.is_empty():
		texture_node.texture = load(texture_path)

func _select_character(character_id: String) -> void:
	if not GameState.set_selected_character(character_id):
		return

	selected_character_id = character_id
	_render()

	var card: Control = %SlotACard if character_id == available_character_ids[0] else %SlotBCard
	card.pivot_offset = card.size * 0.5

	var tween: Tween = create_tween()
	tween.tween_property(card, "scale", Vector2(1.025, 1.025), 0.10)
	tween.tween_property(card, "scale", Vector2.ONE, 0.12)

func _continue_to_intro() -> void:
	if selected_character_id.is_empty():
		return

	SceneRouter.goto("intro")

func _render() -> void:
	var slot_a_selected: bool = selected_character_id == available_character_ids[0]
	var slot_b_selected: bool = selected_character_id == available_character_ids[1]

	_apply_character_pose(
		%SlotAAvatar,
		available_character_ids[0],
		slot_a_selected
	)
	_apply_character_pose(
		%SlotBAvatar,
		available_character_ids[1],
		slot_b_selected
	)

	%SlotASelectedFrame.visible = slot_a_selected
	%SlotBSelectedFrame.visible = slot_b_selected
	%SlotACheck.visible = slot_a_selected
	%SlotBCheck.visible = slot_b_selected

	%SlotAButton.text = "TERPILIH" if slot_a_selected else "PILIH"
	%SlotBButton.text = "TERPILIH" if slot_b_selected else "PILIH"

	_apply_choice_button_style(%SlotAButton, slot_a_selected)
	_apply_choice_button_style(%SlotBButton, slot_b_selected)

	%ContinueButton.disabled = selected_character_id.is_empty()
	%GreetingLabel.text = "Hai.. %s" % GameState.player_display_name()

	if selected_character_id.is_empty():
		%SelectedLabel.text = "%s, pilih salah satu karakter untuk memulai perjalanan." % GameState.player_display_name()
		%SelectedLabel.add_theme_color_override(
			"font_color",
			Color(0.20, 0.34, 0.14, 1)
		)
	else:
		%SelectedLabel.text = "Karakter sudah dipilih. Tekan Lanjutkan untuk melanjutkan cerita."
		%SelectedLabel.add_theme_color_override(
			"font_color",
			Color(0.82, 0.22, 0.12, 1)
		)

func _apply_choice_button_style(button: Button, selected: bool) -> void:
	var normal := StyleBoxFlat.new()
	normal.corner_radius_top_left = 8
	normal.corner_radius_top_right = 8
	normal.corner_radius_bottom_left = 8
	normal.corner_radius_bottom_right = 8

	var hover := StyleBoxFlat.new()
	hover.corner_radius_top_left = 8
	hover.corner_radius_top_right = 8
	hover.corner_radius_bottom_left = 8
	hover.corner_radius_bottom_right = 8

	if selected:
		normal.bg_color = Color(0.35, 0.52, 0.22, 1)
		hover.bg_color = Color(0.40, 0.59, 0.25, 1)
		button.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		button.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	else:
		normal.bg_color = Color(0.48, 0.50, 0.44, 0.92)
		hover.bg_color = Color(0.38, 0.52, 0.28, 0.96)
		button.add_theme_color_override("font_color", Color(0.98, 0.98, 0.92, 1))
		button.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
