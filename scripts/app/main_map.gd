extends Control

const REFERENCE_SIZE := Vector2(1671.0, 941.0)


const HAPPY_CHARACTER_TEXTURES := {
	"rara": "res://assets/visual/character_select/character_01_female_happy.png",
	"budi": "res://assets/visual/character_select/character_02_male_happy.png",
	"anjani": "res://assets/visual/character_select/character_03_female_happy.png",
	"riski": "res://assets/visual/character_select/character_04_male_happy.png"
}

const LOCATION_DATA := [
	{
		"level_no": 1,
		"scene_key": "level_01",
		"title": "Rumah",
		"description": "Kenali pangan lokal pertama melalui kegiatan memilih dan mencocokkan bahan pangan di rumah."
	},
	{
		"level_no": 2,
		"scene_key": "level_02",
		"title": "Sekolah",
		"description": "Kelompokkan pangan lokal sesuai jenis dan kategorinya melalui tantangan di sekolah."
	},
	{
		"level_no": 3,
		"scene_key": "level_03",
		"title": "Pasar",
		"description": "Belanja pangan lokal dengan cermat menggunakan koin yang tersedia dan pilih bahan yang dibutuhkan."
	},
	{
		"level_no": 4,
		"scene_key": "level_04",
		"title": "Dapur",
		"description": "Padukan dua bahan pangan lokal dan tentukan proses pengolahan yang tepat di dapur."
	},
	{
		"level_no": 5,
		"scene_key": "level_05",
		"title": "Festival",
		"description": "Selesaikan tantangan akhir pangan lokal dan uji literasimu dalam Festival Pangan Lokal."
	}
]

@onready var canvas: Control = %MapCanvas
@onready var info_title: Label = %LevelTitle
@onready var info_title_underline: ColorRect = %LevelTitleUnderline
@onready var info_status: Label = %LevelStatus
@onready var info_description: Label = %LevelDescription
@onready var start_button: Button = %StartLevelButton
@onready var exit_mask: ColorRect = %ExitModalMask
@onready var exit_modal: PanelContainer = %ExitConfirmationModal
@onready var exit_cancel_button: Button = %ExitCancelButton
@onready var exit_confirm_button: Button = %ExitConfirmButton
@onready var score_label: Label = %ScoreLabel
@onready var medal_label: Label = %MedalLabel
@onready var player_name_label: Label = %PlayerNameLabel
@onready var player_avatar: TextureRect = %PlayerAvatar

var location_buttons: Dictionary = {}
var selected_level_no: int = 1


func _ready() -> void:
	name = "MainMapRoot"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true

	if GameState.active_run.is_empty():
		SceneRouter.goto("main_menu")
		return

	_bind_scene_authored_ui()
	resized.connect(_layout_canvas)
	_refresh_map()
	_layout_canvas()

func _bind_scene_authored_ui() -> void:
	location_buttons = {
		1: %Location_1,
		2: %Location_2,
		3: %Location_3,
		4: %Location_4,
		5: %Location_5
	}

	%BackButton.pressed.connect(_on_back_pressed)
	%ExitButton.pressed.connect(_show_exit_confirmation)
	start_button.pressed.connect(_on_start_pressed)
	exit_cancel_button.pressed.connect(_close_exit_confirmation)
	exit_confirm_button.pressed.connect(_confirm_exit)

	UIMotion.bind_button(%BackButton)
	UIMotion.bind_button(%ExitButton)
	UIMotion.bind_button(start_button)
	UIMotion.bind_button(exit_cancel_button)
	UIMotion.bind_button(exit_confirm_button)

	for level_no in range(1, 6):
		var button: TextureButton = location_buttons[level_no]
		button.pressed.connect(_select_location.bind(level_no))

func _layout_canvas() -> void:
	if not is_instance_valid(canvas):
		return

	var scale_value: float = min(size.x / REFERENCE_SIZE.x, size.y / REFERENCE_SIZE.y)
	var scaled_size: Vector2 = REFERENCE_SIZE * scale_value
	canvas.scale = Vector2(scale_value, scale_value)
	canvas.position = (size - scaled_size) * 0.5

func _refresh_map() -> void:
	selected_level_no = _default_selected_level()

	for location_value in LOCATION_DATA:
		var location: Dictionary = location_value
		var level_no: int = int(location["level_no"])
		var button: TextureButton = location_buttons[level_no]
		var status: String = GameState.level_status(level_no)
		var locked: bool = status == "LOCKED"

		button.disabled = locked
		button.modulate = Color(1, 1, 1, 1)

	_refresh_profile()
	_refresh_selection()

func _refresh_profile() -> void:
	score_label.text = "SKOR %d / 500" % clampi(GameState.total_points(), 0, 500)
	medal_label.text = "MEDALI %d / 5" % _earned_medal_count()
	player_name_label.text = GameState.player_display_name()

	var character_id: String = GameState.selected_character_id()
	var texture_path: String = str(HAPPY_CHARACTER_TEXTURES.get(character_id, ""))

	if texture_path.is_empty():
		texture_path = GameState.selected_character_texture_path()

	if not texture_path.is_empty():
		player_avatar.texture = _make_face_texture(texture_path)

func _make_face_texture(texture_path: String) -> Texture2D:
	var source_texture: Texture2D = load(texture_path)

	if source_texture == null:
		return null

	var source_width: float = float(source_texture.get_width())
	var source_height: float = float(source_texture.get_height())
	var crop_width: float = source_width * 0.58
	var crop_height: float = source_height * 0.43
	var crop_x: float = (source_width - crop_width) * 0.5

	var face_texture := AtlasTexture.new()
	face_texture.atlas = source_texture
	face_texture.region = Rect2(
		crop_x,
		0.0,
		crop_width,
		crop_height
	)

	return face_texture

func _refresh_selection() -> void:
	var location := _get_location(selected_level_no)

	if location.is_empty():
		return

	var status: String = GameState.level_status(selected_level_no)
	info_title.text = str(location["title"])
	info_title_underline.size.x = clampf(
		float(info_title.text.length()) * 24.0,
		120.0,
		210.0
	)
	info_description.text = str(location["description"])
	info_status.text = _status_label(status)
	info_status.add_theme_color_override("font_color", _status_color(status))
	start_button.disabled = status == "LOCKED"

	for key_value in location_buttons.keys():
		var level_no: int = int(key_value)
		var button: TextureButton = location_buttons[level_no]
		button.pivot_offset = button.size * 0.5
		button.scale = Vector2(1.035, 1.035) if level_no == selected_level_no else Vector2.ONE

func _select_location(level_no: int) -> void:
	_play_click()
	selected_level_no = level_no
	_refresh_selection()

func _on_start_pressed() -> void:
	var status: String = GameState.level_status(selected_level_no)

	if status == "LOCKED":
		return

	var location := _get_location(selected_level_no)

	if location.is_empty():
		return

	_play_click()
	SceneRouter.goto(str(location["scene_key"]))

func _show_exit_confirmation() -> void:
	_play_click()
	exit_mask.visible = true
	exit_modal.visible = true
	UIMotion.play_pop(exit_modal, 1.02)

func _close_exit_confirmation() -> void:
	exit_modal.visible = false
	exit_mask.visible = false

func _confirm_exit() -> void:
	get_tree().quit()

func _on_back_pressed() -> void:
	_play_click()
	SceneRouter.goto("main_menu")

func _default_selected_level() -> int:
	var fallback: int = 1

	for level_no in range(1, 6):
		var status: String = GameState.level_status(level_no)

		if status == "AVAILABLE":
			return level_no

		if status == "COMPLETED":
			fallback = level_no

	return fallback

func _get_location(level_no: int) -> Dictionary:
	for location_value in LOCATION_DATA:
		var location: Dictionary = location_value

		if int(location["level_no"]) == level_no:
			return location

	return {}

func _status_label(status: String) -> String:
	match status:
		"AVAILABLE":
			return "TERSEDIA"
		"COMPLETED":
			return "SELESAI"
		_:
			return "TERKUNCI"

func _status_color(status: String) -> Color:
	match status:
		"AVAILABLE":
			return Color(0.03, 0.50, 0.08, 1)
		"COMPLETED":
			return Color(0.18, 0.48, 0.62, 1)
		_:
			return Color(0.45, 0.45, 0.42, 1)

func _earned_medal_count() -> int:
	return GameState.active_run_badge_count()

func _play_click() -> void:
	if is_instance_valid(AudioManager) and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("click")
