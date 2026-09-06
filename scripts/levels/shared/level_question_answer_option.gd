extends Button

@export_group("Scene-owned visual resources")
@export var neutral_normal_style: StyleBoxFlat
@export var neutral_hover_style: StyleBoxFlat
@export var neutral_pressed_style: StyleBoxFlat
@export var disabled_style: StyleBoxFlat
@export var correct_style: StyleBoxFlat
@export var wrong_style: StyleBoxFlat

@export_group("Scene-owned text colors")
@export var neutral_text_color: Color
@export var correct_text_color: Color
@export var wrong_text_color: Color
@export var disabled_text_color: Color

@onready var answer_text: RichTextLabel = %AnswerText

var _visual_state: String = "neutral"


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	answer_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	answer_text.scroll_active = false
	answer_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	set_visual_state("neutral", true)


func set_option_text(value: String) -> void:
	var cleaned: String = value.strip_edges()
	answer_text.clear()
	answer_text.push_paragraph(HORIZONTAL_ALIGNMENT_LEFT)
	answer_text.add_text(cleaned)
	answer_text.pop()

	var estimated_lines: int = maxi(1, int(ceil(float(cleaned.length()) / 64.0)))
	estimated_lines = mini(estimated_lines, 4)
	custom_minimum_size.y = 50.0 + float(estimated_lines - 1) * 22.0


func set_visual_state(state_name: String, interactive: bool) -> void:
	_visual_state = state_name
	disabled = not interactive

	var normal_style: StyleBoxFlat = neutral_normal_style
	var hover_style: StyleBoxFlat = neutral_hover_style
	var pressed_style: StyleBoxFlat = neutral_pressed_style
	var current_disabled_style: StyleBoxFlat = disabled_style
	var text_color: Color = neutral_text_color

	match _visual_state:
		"correct":
			normal_style = correct_style
			hover_style = correct_style
			pressed_style = correct_style
			current_disabled_style = correct_style
			text_color = correct_text_color
		"wrong":
			normal_style = wrong_style
			hover_style = wrong_style
			pressed_style = wrong_style
			current_disabled_style = wrong_style
			text_color = wrong_text_color
		"disabled":
			normal_style = disabled_style
			hover_style = disabled_style
			pressed_style = disabled_style
			current_disabled_style = disabled_style
			text_color = disabled_text_color
		_:
			pass

	if normal_style != null:
		add_theme_stylebox_override("normal", normal_style)
	if hover_style != null:
		add_theme_stylebox_override("hover", hover_style)
		add_theme_stylebox_override("focus", hover_style)
	if pressed_style != null:
		add_theme_stylebox_override("pressed", pressed_style)
	if current_disabled_style != null:
		add_theme_stylebox_override("disabled", current_disabled_style)

	answer_text.add_theme_color_override(
		"default_color",
		text_color
	)

