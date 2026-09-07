extends Control
class_name LevelCompleteScreen

signal primary_action_requested

const STAR_TEXTURE_PATHS: Dictionary = {
	"full": "res://assets/ui/stars/star_full.png",
	"half": "res://assets/ui/stars/star_half.png",
	"empty": "res://assets/ui/stars/star_empty.png"
}

const TEXT_COLOR: Color = Color(0.0, 0.4078, 0.2431, 1.0)
const MUTED_COLOR: Color = Color(0.18, 0.36, 0.27, 1.0)

@onready var overlay_root: Control = %OverlayRoot
@onready var title_label: Label = %LevelCompleteTitle
@onready var completion_message: RichTextLabel = %CompletionMessage
@onready var duration_row: HBoxContainer = %DurationRow
@onready var duration_value: Label = %DurationValue
@onready var score_row: HBoxContainer = %ScoreRow
@onready var score_value: Label = %ScoreValue
@onready var result_row: HBoxContainer = %ResultRow
@onready var result_value: Label = %ResultValue
@onready var badge_row: HBoxContainer = %BadgeRow
@onready var badge_value: Label = %BadgeValue
@onready var primary_button: Button = %PrimaryButton
@onready var game_logo: TextureRect = %GameLogo
@onready var metrics_vbox: VBoxContainer = %DurationRow.get_parent() as VBoxContainer
@onready var content_vbox: VBoxContainer = %CompletionMessage.get_parent() as VBoxContainer

var _source_panel: Control
var _native_button: Button
var _structured_body: HBoxContainer
var _result_scroll: ScrollContainer
var _detail_vbox: VBoxContainer
var _logo_center: CenterContainer
var _star_textures: Dictionary = {}


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	primary_button.pressed.connect(
		_on_primary_button_pressed
	)
	_ensure_structured_layout()


func show_completion(
	source_panel: Control,
	data: Dictionary,
	native_button: Button
) -> void:
	_source_panel = source_panel
	_native_button = native_button

	var level_number_text: String = str(
		data.get("level", "")
	)

	if level_number_text.is_empty() or level_number_text == "0":
		title_label.text = "LEVEL SELESAI"
	else:
		title_label.text = (
			"LEVEL "
			+ level_number_text
			+ " SELESAI"
		)

	var message_text: String = str(
		data.get(
			"message",
			"Kamu telah menyelesaikan level ini."
		)
	)

	completion_message.clear()
	completion_message.push_paragraph(
		HORIZONTAL_ALIGNMENT_CENTER
	)
	completion_message.append_text(message_text)
	completion_message.pop()

	badge_row.visible = false
	badge_value.text = ""
	_render_completion_detail(data)

	var requested_button_text: String = str(
		data.get("button_text", "")
	).strip_edges()

	if requested_button_text.is_empty():
		requested_button_text = "LANJUT"

	primary_button.text = requested_button_text
	primary_button.disabled = false

	if is_instance_valid(_source_panel):
		_source_panel.visible = false

	overlay_root.visible = true
	visible = true
	primary_button.call_deferred("grab_focus")


func hide_presenter() -> void:
	primary_button.disabled = false
	_source_panel = null
	_native_button = null
	overlay_root.visible = false
	visible = false


func _ensure_structured_layout() -> void:
	if is_instance_valid(_structured_body):
		return

	metrics_vbox.visible = false
	result_row.visible = false
	duration_row.visible = false
	score_row.visible = false

	_structured_body = HBoxContainer.new()
	_structured_body.name = "StructuredResultBody"
	_structured_body.custom_minimum_size = Vector2(0.0, 300.0)
	_structured_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_structured_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_structured_body.add_theme_constant_override("separation", 24)
	content_vbox.add_child(_structured_body)
	content_vbox.move_child(_structured_body, 1)

	_result_scroll = ScrollContainer.new()
	_result_scroll.name = "ResultDetailScroll"
	_result_scroll.custom_minimum_size = Vector2(700.0, 300.0)
	_result_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_result_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_result_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_structured_body.add_child(_result_scroll)

	_detail_vbox = VBoxContainer.new()
	_detail_vbox.name = "ResultDetailVBox"
	_detail_vbox.custom_minimum_size = Vector2(660.0, 0.0)
	_detail_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_vbox.add_theme_constant_override("separation", 5)
	_result_scroll.add_child(_detail_vbox)

	_logo_center = CenterContainer.new()
	_logo_center.name = "FixedLogoCenter"
	_logo_center.custom_minimum_size = Vector2(300.0, 300.0)
	_logo_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_structured_body.add_child(_logo_center)

	game_logo.reparent(_logo_center)
	game_logo.scale = Vector2.ONE
	game_logo.position = Vector2.ZERO
	game_logo.custom_minimum_size = Vector2(265.0, 265.0)
	game_logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	game_logo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	game_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	game_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED


func _render_completion_detail(data: Dictionary) -> void:
	_ensure_structured_layout()
	_clear_detail_rows()

	var detail_value: Variant = data.get("detail_data", {})

	if not detail_value is Dictionary:
		_render_fallback_detail(data)
		return

	var detail: Dictionary = detail_value

	if detail.is_empty():
		_render_fallback_detail(data)
		return

	_add_metric_row(
		"Total Poin",
		str(detail.get("score_text", data.get("score_text", "")))
	)
	_add_star_metric_row(
		"Jumlah Bintang",
		detail.get("star_slots", [])
	)
	_add_metric_row(
		"Durasi Level",
		str(detail.get("duration_text", data.get("duration_text", "")))
	)
	_add_separator()

	var games_value: Variant = detail.get("games", [])

	if not games_value is Array:
		return

	var games: Array = games_value

	for game_value in games:
		if not game_value is Dictionary:
			continue

		var game: Dictionary = game_value
		_render_game_detail(game)


func _render_fallback_detail(data: Dictionary) -> void:
	_add_metric_row("Total Poin", str(data.get("score_text", "")))
	var fallback_star_slots: Variant = data.get("star_slots", [])
	if fallback_star_slots is Array:
		var star_slots: Array = fallback_star_slots
		if not star_slots.is_empty():
			_add_star_metric_row("Jumlah Bintang", star_slots)
	_add_metric_row("Durasi Level", str(data.get("duration_text", "")))
	var result_text: String = str(data.get("result_text", "")).strip_edges()
	if not result_text.is_empty():
		_add_separator()
		_add_body_label(result_text, 19, TEXT_COLOR)


func _render_game_detail(game: Dictionary) -> void:
	var game_no: int = int(game.get("game_no", 0))
	var game_title: String = str(
		game.get("title", "")
	).strip_edges()
	var heading: String = "Permainan ke-%d" % game_no

	if not game_title.is_empty():
		heading += " - " + game_title

	_add_section_heading(heading, 22)
	_add_metric_row(
		"Total Poin",
		str(game.get("score_text", ""))
	)
	_add_metric_row(
		"Durasi Permainan",
		str(game.get("duration_text", ""))
	)
	_add_metric_row(
		"Jumlah Benar",
		str(game.get("total_correct", 0))
	)
	_add_metric_row(
		"Jumlah Salah",
		str(game.get("total_wrong", 0))
	)

	var total_invalid: int = int(
		game.get("total_invalid", 0)
	)

	if total_invalid > 0:
		_add_metric_row(
			"Jumlah Tidak Valid",
			str(total_invalid)
		)

	var penalty_count: int = int(
		game.get("penalty_count", 0)
	)
	var penalty_points_total: int = int(
		game.get("penalty_points_total", 0)
	)

	if penalty_count > 0:
		_add_metric_row(
			"Jumlah Penalti",
			str(penalty_count)
		)
		_add_metric_row(
			"Total Pengurangan Poin",
			"-%d" % penalty_points_total
		)

	var missions_value: Variant = game.get(
		"missions",
		[]
	)

	if missions_value is Array:
		var missions: Array = missions_value

		if not missions.is_empty():
			_add_result_heading(
				"Hasil Permainan ke-%d" % game_no
			)

			for mission_value in missions:
				if not mission_value is Dictionary:
					continue

				_render_mission_detail(
					mission_value
				)

	_add_separator()

func _render_mission_detail(
	mission: Dictionary
) -> void:
	var mission_no: int = int(
		mission.get("mission_no", 0)
	)
	var mission_title: String = str(
		mission.get("title", "")
	).strip_edges()
	var heading: String = "Misi ke-%d" % mission_no

	if not mission_title.is_empty():
		heading += " - " + mission_title

	var mission_margin := MarginContainer.new()
	mission_margin.add_theme_constant_override(
		"margin_left",
		28
	)
	mission_margin.add_theme_constant_override(
		"margin_right",
		8
	)
	_detail_vbox.add_child(mission_margin)

	var mission_box := VBoxContainer.new()
	mission_box.add_theme_constant_override(
		"separation",
		3
	)
	mission_margin.add_child(mission_box)

	mission_box.add_child(
		_create_body_label(
			heading,
			20,
			TEXT_COLOR
		)
	)
	mission_box.add_child(
		_create_metric_row_node(
			"Durasi",
			str(
				mission.get(
					"duration_text",
					"-"
				)
			),
			165.0
		)
	)
	mission_box.add_child(
		_create_metric_row_node(
			"Percobaan",
			str(
				mission.get(
					"attempt_count",
					1
				)
			),
			165.0
		)
	)
	mission_box.add_child(
		_create_metric_row_node(
			"Jumlah Salah",
			str(
				mission.get(
					"wrong_count",
					0
				)
			),
			165.0
		)
	)

	var invalid_count: int = int(
		mission.get("invalid_count", 0)
	)

	if invalid_count > 0:
		mission_box.add_child(
			_create_metric_row_node(
				"Jumlah Tidak Valid",
				str(invalid_count),
				165.0
			)
		)

	mission_box.add_child(
		_create_metric_row_node(
			"Status Hasil",
			str(
				mission.get(
					"status_text",
					"-"
				)
			),
			165.0
		)
	)

	var base_point_text: String = str(
		mission.get(
			"base_point_text",
			"-"
		)
	)

	if (
		not base_point_text.is_empty()
		and base_point_text != "-"
	):
		mission_box.add_child(
			_create_metric_row_node(
				"Poin Dasar",
				base_point_text,
				165.0
			)
		)

	var penalty_points: int = int(
		mission.get(
			"penalty_points",
			0
		)
	)

	if penalty_points > 0:
		mission_box.add_child(
			_create_metric_row_node(
				"Penalti",
				"-%d" % penalty_points,
				165.0
			)
		)

	mission_box.add_child(
		_create_metric_row_node(
			"Poin Akhir",
			str(
				mission.get(
					"point_text",
					"-"
				)
			),
			165.0
		)
	)

	_render_attempt_history(
		mission_box,
		mission.get(
			"attempt_details",
			[]
		)
	)

	_add_optional_click_row(
		mission_box,
		"Klik Petunjuk",
		int(
			mission.get(
				"hint_click_count",
				0
			)
		)
	)
	_add_optional_click_row(
		mission_box,
		"Klik Reset",
		int(
			mission.get(
				"reset_click_count",
				0
			)
		)
	)
	_add_optional_click_row(
		mission_box,
		"Klik ke-Peta",
		int(
			mission.get(
				"back_to_map_click_count",
				0
			)
		)
	)


func _render_attempt_history(
	container: VBoxContainer,
	attempts_value: Variant
) -> void:
	if not attempts_value is Array:
		return

	var attempts: Array = attempts_value

	if attempts.is_empty():
		return

	var history_label := _create_body_label(
		"Riwayat Percobaan",
		18,
		MUTED_COLOR
	)
	history_label.custom_minimum_size = Vector2(
		0.0,
		28.0
	)
	container.add_child(history_label)

	for attempt_value in attempts:
		if not attempt_value is Dictionary:
			continue

		var attempt: Dictionary = attempt_value
		var attempt_margin := MarginContainer.new()
		attempt_margin.add_theme_constant_override(
			"margin_left",
			20
		)
		attempt_margin.add_theme_constant_override(
			"margin_right",
			4
		)
		container.add_child(attempt_margin)

		var attempt_box := VBoxContainer.new()
		attempt_box.add_theme_constant_override(
			"separation",
			2
		)
		attempt_margin.add_child(attempt_box)

		attempt_box.add_child(
			_create_body_label(
				"Percobaan %d" % int(
					attempt.get(
						"attempt_no",
						0
					)
				),
				18,
				TEXT_COLOR
			)
		)
		attempt_box.add_child(
			_create_metric_row_node(
				"Hasil",
				str(
					attempt.get(
						"result_text",
						"-"
					)
				),
				150.0
			)
		)

		var selected_label: String = str(
			attempt.get(
				"selected_label",
				""
			)
		).strip_edges()

		if not selected_label.is_empty():
			attempt_box.add_child(
				_create_metric_row_node(
					selected_label,
					str(
						attempt.get(
							"selected_value",
							"-"
						)
					),
					150.0
				)
			)

		var correct_label: String = str(
			attempt.get(
				"correct_label",
				""
			)
		).strip_edges()

		if not correct_label.is_empty():
			attempt_box.add_child(
				_create_metric_row_node(
					correct_label,
					str(
						attempt.get(
							"correct_value",
							"-"
						)
					),
					150.0
				)
			)

		attempt_box.add_child(
			_create_metric_row_node(
				"Durasi",
				str(
					attempt.get(
						"duration_text",
						"-"
					)
				),
				150.0
			)
		)

func _add_optional_click_row(
	container: VBoxContainer,
	label_text: String,
	count: int
) -> void:
	if count <= 0:
		return

	container.add_child(
		_create_metric_row_node(
			label_text,
			str(count),
			165.0
		)
	)


func _add_metric_row(
	label_text: String,
	value_text: String
) -> void:
	_detail_vbox.add_child(
		_create_metric_row_node(
			label_text,
			value_text,
			185.0
		)
	)


func _create_metric_row_node(
	label_text: String,
	value_text: String,
	label_width: float
) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var title := _create_body_label(
		label_text,
		19,
		TEXT_COLOR
	)
	title.custom_minimum_size = Vector2(label_width, 0.0)
	row.add_child(title)

	var value := _create_body_label(
		value_text,
		19,
		TEXT_COLOR
	)
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(value)
	return row


func _add_star_metric_row(
	label_text: String,
	slots_value: Variant
) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_detail_vbox.add_child(row)

	var title := _create_body_label(
		label_text,
		19,
		TEXT_COLOR
	)
	title.custom_minimum_size = Vector2(185.0, 0.0)
	row.add_child(title)

	var stars := HBoxContainer.new()
	stars.add_theme_constant_override("separation", 5)
	row.add_child(stars)

	var slots: Array = []

	if slots_value is Array:
		slots = slots_value

	for slot_value in slots:
		var slot: String = str(slot_value)
		var texture: Texture2D = _load_star_texture(slot)

		if texture == null:
			continue

		var star := TextureRect.new()
		star.custom_minimum_size = Vector2(38.0, 38.0)
		star.texture = texture
		star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stars.add_child(star)


func _load_star_texture(slot: String) -> Texture2D:
	var cached_value: Variant = _star_textures.get(slot, null)

	if cached_value is Texture2D:
		return cached_value as Texture2D

	var path: String = str(
		STAR_TEXTURE_PATHS.get(slot, "")
	)

	if path.is_empty():
		return null

	var texture: Texture2D = load(path) as Texture2D

	if texture != null:
		_star_textures[slot] = texture

	return texture


func _add_section_heading(
	text_value: String,
	font_size: int
) -> void:
	var label := _create_body_label(
		text_value,
		font_size,
		TEXT_COLOR
	)
	label.custom_minimum_size = Vector2(0.0, 34.0)
	_detail_vbox.add_child(label)


func _add_result_heading(text_value: String) -> void:
	var label := _create_body_label(
		text_value,
		19,
		MUTED_COLOR
	)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(0.0, 30.0)
	_detail_vbox.add_child(label)


func _add_body_label(
	text_value: String,
	font_size: int,
	color: Color
) -> void:
	_detail_vbox.add_child(
		_create_body_label(
			text_value,
			font_size,
			color
		)
	)


func _create_body_label(
	text_value: String,
	font_size: int,
	color: Color
) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _add_separator() -> void:
	var separator := HSeparator.new()
	separator.custom_minimum_size = Vector2(0.0, 10.0)
	_detail_vbox.add_child(separator)


func _clear_detail_rows() -> void:
	if not is_instance_valid(_detail_vbox):
		return

	for child_value in _detail_vbox.get_children():
		var child: Node = child_value as Node

		if child == null:
			continue

		_detail_vbox.remove_child(child)
		child.queue_free()


func _on_primary_button_pressed() -> void:
	if not is_instance_valid(_native_button):
		return

	primary_button.disabled = true
	primary_action_requested.emit()
	_native_button.emit_signal("pressed")