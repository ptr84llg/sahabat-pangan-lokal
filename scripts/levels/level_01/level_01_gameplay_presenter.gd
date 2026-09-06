extends Control

# ============================================================================
# Level 1 Main Game - VISUAL PRESENTER ONLY
#
# Existing game mechanism remains authoritative:
# - MatchingController owns validation, progress, score, hint and completion.
# - Existing FoodDropSlot instances remain the real drop targets.
# - Existing FoodCard instances remain the real draggable objects.
# - Existing HintButton remains the real hint action.
# - Existing ProgressLabel / GameplayScoreLabel remain the data sources.
#
# This presenter only re-parents those existing interactive Controls into
# a newly recreated layout while GAMEPLAY is active.
# ============================================================================


var _level_root: Control
var _native_gameplay: Control
var _matching_board: GridContainer
var _food_tray: GridContainer
var _hint_button: Button
var _mission_source: Node
var _progress_source: Node
var _score_source: Node

#@onready var _board_panel: PanelContainer = %RecreatedMainBoard
#@onready var _header_panel: PanelContainer = %GameHeader
#@onready var _logo: TextureRect = %GameLogo
@onready var _mission_value: Label = %MissionValue
@onready var _score_value: Label = %ScoreValue
@onready var _progress_value: Label = %MatchValue
@onready var _targets_host: MarginContainer = %TargetsHost
@onready var _food_host: CenterContainer = %FoodTrayHost
@onready var _hint_host: CenterContainer = %HintHost

var _adopted: bool = false
var _bind_failed: bool = false



func _ready() -> void:
	name = "Level01GameplayPresenter"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 240
	visible = false

	resized.connect(_apply_responsive_geometry)
	call_deferred("_bind_and_adopt_native_gameplay")
	_apply_responsive_geometry()
	set_process(true)

func _process(_delta: float) -> void:
	if not is_instance_valid(_level_root):
		return

	var state_value: Variant = _level_root.get("current_state")
	var state_name: String = str(state_value)
	var gameplay_active: bool = state_name == "GAMEPLAY"

	if not gameplay_active:
		visible = false
		return

	if not _adopted and not _bind_failed:
		_bind_and_adopt_native_gameplay()

	if not _adopted:
		visible = false
		return

	_sync_native_text()

	if is_instance_valid(_native_gameplay):
		_native_gameplay.visible = false

	visible = true


func _bind_and_adopt_native_gameplay() -> void:
	if _adopted or _bind_failed:
		return

	_level_root = get_parent() as Control

	if _level_root == null:
		_bind_failed = true
		push_error("57D: Level 1 root Control tidak ditemukan.")
		return

	var gameplay_node: Node = _find_descendant_by_name(
		_level_root,
		"GameplayLayer"
	)
	_native_gameplay = gameplay_node as Control

	if _native_gameplay == null:
		_bind_failed = true
		push_error("57D: Native GameplayLayer tidak ditemukan.")
		return

	var matching_node: Node = _find_descendant_by_name(
		_native_gameplay,
		"MatchingBoard"
	)
	var food_tray_node: Node = _find_descendant_by_name(
		_native_gameplay,
		"FoodTray"
	)
	var hint_node: Node = _find_descendant_by_name(
		_native_gameplay,
		"HintButton"
	)

	_matching_board = matching_node as GridContainer
	_food_tray = food_tray_node as GridContainer
	_hint_button = hint_node as Button

	_mission_source = _find_descendant_by_name(
		_native_gameplay,
		"Mission"
	)
	_progress_source = _find_descendant_by_name(
		_native_gameplay,
		"ProgressLabel"
	)
	_score_source = _find_descendant_by_name(
		_native_gameplay,
		"GameplayScoreLabel"
	)

	var required_ok: bool = (
		_matching_board != null
		and _food_tray != null
		and _hint_button != null
		and _progress_source != null
		and _score_source != null
	)

	if not required_ok:
		_bind_failed = true
		push_error(
			"57D: node mekanisme wajib Gameplay Level 1 tidak lengkap."
		)
		return

	_matching_board.reparent(_targets_host)
	_food_tray.reparent(_food_host)
	_hint_button.reparent(_hint_host)

	_adopted = true
	_apply_interaction_layout()
	_sync_native_text()


func _apply_interaction_layout() -> void:
	if not _adopted:
		return

	_matching_board.columns = 6
	_matching_board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_matching_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_matching_board.add_theme_constant_override("h_separation", 10)
	_matching_board.add_theme_constant_override("v_separation", 8)

	for slot_variant in _matching_board.get_children():
		var slot_control: Control = slot_variant as Control

		if slot_control == null:
			continue

		slot_control.custom_minimum_size = Vector2(0.0, 120.0)
		slot_control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot_control.size_flags_vertical = Control.SIZE_EXPAND_FILL

		if slot_control is PanelContainer:
			var slot_panel: PanelContainer = slot_control as PanelContainer
			slot_panel.add_theme_stylebox_override(
				"panel",
				_make_panel_style(
					Color(0.99, 0.99, 0.975, 1.0),
					Color(0.012, 0.35, 0.23, 1.0),
					3,
					0
				)
			)

		var title_node: Node = _find_descendant_by_name(
			slot_control,
			"Title"
		)

		if title_node is Label:
			var title_label: Label = title_node as Label
			title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			title_label.add_theme_color_override(
				"font_color",
				Color(0.26, 0.49, 0.18, 1.0)
			)
			title_label.add_theme_font_size_override("font_size", 17)

		var holder_node: Node = _find_descendant_by_name(
			slot_control,
			"Holder"
		)

		if holder_node is Control:
			var holder_control: Control = holder_node as Control
			holder_control.custom_minimum_size = Vector2(0.0, 80.0)

	_food_tray.columns = 6
	_food_tray.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_food_tray.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_food_tray.add_theme_constant_override("h_separation", 12)
	_food_tray.add_theme_constant_override("v_separation", 8)

	for card_variant in _food_tray.get_children():
		var card_control: Control = card_variant as Control

		if card_control == null:
			continue

		card_control.custom_minimum_size = Vector2(92.0, 92.0)
		card_control.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		card_control.size_flags_vertical = Control.SIZE_SHRINK_CENTER

		if card_control is PanelContainer:
			var card_panel: PanelContainer = card_control as PanelContainer
			card_panel.add_theme_stylebox_override(
				"panel",
				_make_panel_style(
					Color(1.0, 1.0, 1.0, 0.0),
					Color(1.0, 1.0, 1.0, 0.0),
					0,
					0
				)
			)

	_hint_button.custom_minimum_size = Vector2(170.0, 50.0)
	_hint_button.add_theme_font_size_override("font_size", 18)
	_hint_button.add_theme_color_override(
		"font_color",
		Color(0.012, 0.35, 0.23, 1.0)
	)
	_hint_button.add_theme_color_override(
		"font_hover_color",
		Color(0.012, 0.35, 0.23, 1.0)
	)
	_hint_button.add_theme_color_override(
		"font_pressed_color",
		Color(1.0, 1.0, 1.0, 1.0)
	)
	_hint_button.add_theme_stylebox_override(
		"normal",
		_make_button_style(
			Color(0.91, 0.95, 0.84, 1.0),
			Color(0.012, 0.35, 0.23, 1.0)
		)
	)
	_hint_button.add_theme_stylebox_override(
		"hover",
		_make_button_style(
			Color(0.98, 0.95, 0.58, 1.0),
			Color(0.012, 0.35, 0.23, 1.0)
		)
	)
	_hint_button.add_theme_stylebox_override(
		"pressed",
		_make_button_style(
			Color(0.26, 0.49, 0.18, 1.0),
			Color(0.012, 0.35, 0.23, 1.0)
		)
	)


func _sync_native_text() -> void:
	var mission_text: String = _read_control_text(_mission_source)
	var progress_text: String = _read_control_text(_progress_source)
	var score_text: String = _read_control_text(_score_source)

	if not mission_text.is_empty():
		_mission_value.text = _strip_prefix(
			mission_text,
			"Misi:"
		)

	if not progress_text.is_empty():
		_progress_value.text = _normalize_progress(progress_text)

	if not score_text.is_empty():
		_score_value.text = _normalize_score(score_text)


func _read_control_text(source_node: Node) -> String:
	if source_node == null:
		return ""

	if source_node is Label:
		var label_node: Label = source_node as Label
		return label_node.text.strip_edges()

	if source_node is RichTextLabel:
		var rich_node: RichTextLabel = source_node as RichTextLabel
		return rich_node.text.strip_edges()

	if source_node is Button:
		var button_node: Button = source_node as Button
		return button_node.text.strip_edges()

	return ""


func _strip_prefix(value: String, prefix: String) -> String:
	var cleaned: String = value.strip_edges()

	if cleaned.to_lower().begins_with(prefix.to_lower()):
		return cleaned.substr(prefix.length()).strip_edges()

	return cleaned


func _normalize_progress(value: String) -> String:
	var cleaned: String = value.strip_edges()

	if cleaned.to_lower().begins_with("pangan"):
		cleaned = cleaned.substr(6).strip_edges()

	return cleaned.replace("/", " / ")


func _normalize_score(value: String) -> String:
	var cleaned: String = value.strip_edges()
	var colon_index: int = cleaned.rfind(":")

	if colon_index >= 0:
		cleaned = cleaned.substr(colon_index + 1).strip_edges()

	return cleaned.replace("/", " / ")


func _find_descendant_by_name(
	root_node: Node,
	target_name: String
) -> Node:
	for child_variant in root_node.get_children():
		var child_node: Node = child_variant as Node

		if child_node == null:
			continue

		if child_node == self:
			continue

		if str(child_node.name) == target_name:
			return child_node

		var nested_node: Node = _find_descendant_by_name(
			child_node,
			target_name
		)

		if nested_node != null:
			return nested_node

	return null


func _apply_responsive_geometry() -> void:
	var viewport_width: float = size.x
#	var compact: bool = viewport_width < 1060.0

	if _adopted:
		_apply_interaction_layout()


func _make_panel_style(
	background: Color,
	border: Color,
	border_width: int,
	radius: int
) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius
	return style


func _make_button_style(
	background: Color,
	border: Color
) -> StyleBoxFlat:
	var style: StyleBoxFlat = _make_panel_style(
		background,
		border,
		4,
		18
	)
	style.content_margin_left = 18.0
	style.content_margin_top = 10.0
	style.content_margin_right = 18.0
	style.content_margin_bottom = 10.0
	return style
