extends Control


const LEVEL2_TUTORIAL_FOODS: Array[Dictionary] = [
	{
		"name": "Jagung",
		"path": "res://assets/visual/foods/food_corn.png"
	},
	{
		"name": "Ubi Jalar",
		"path": "res://assets/visual/foods/food_sweet_potato.png"
	},
	{
		"name": "Terung",
		"path": "res://assets/visual/foods/food_eggplant.png"
	},
	{
		"name": "Ketimun",
		"path": "res://assets/visual/foods/food_cucumber.png"
	},
	{
		"name": "Mangga",
		"path": "res://assets/visual/foods/food_mango.png"
	},
	{
		"name": "Jambu Biji",
		"path": "res://assets/visual/foods/food_guava.png"
	}
]

@onready var tutorial_ui: Control = %TutorialUI
@onready var step_label: Label = %StepLabel
@onready var illustration_row: HBoxContainer = %IllustrationRow
@onready var illustration_a: TextureRect = %IllustrationA
@onready var illustration_b: TextureRect = %IllustrationB
@onready var illustration_c: TextureRect = %IllustrationC
@onready var instruction_text: RichTextLabel = %InstructionText
@onready var continue_button: Button = %ContinueButton
@onready var level2_rich_content: VBoxContainer = %Level2RichContent
@onready var level2_food_1: VBoxContainer = %Level2Food1
@onready var level2_food_2: VBoxContainer = %Level2Food2
@onready var level2_food_3: VBoxContainer = %Level2Food3
@onready var level2_food_4: VBoxContainer = %Level2Food4
@onready var level2_food_5: VBoxContainer = %Level2Food5
@onready var level2_food_6: VBoxContainer = %Level2Food6
@onready var portrait_blocker: Control = %PortraitBlocker

var _source_panel: Control
var _continue_target: Button


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_force_landscape()
	continue_button.pressed.connect(_on_continue_pressed)
	get_viewport().size_changed.connect(_check_orientation)
	_check_orientation()


func present(
	source_panel: Control,
	step_text: String,
	body_text: String,
	continue_target: Button
) -> void:
	_source_panel = source_panel
	_continue_target = continue_target

	if is_instance_valid(_source_panel):
		_source_panel.visible = false

	var host: Node = get_parent()
	var level_no: int = 0

	if host != null:
		level_no = int(host.get_meta("level_no", 0))

	var use_level2_rich: bool = level_no == 2

	level2_rich_content.visible = use_level2_rich
	step_label.visible = not use_level2_rich
	illustration_row.visible = false
	instruction_text.visible = not use_level2_rich

	if use_level2_rich:
		_present_level2_rich_content()
	else:
		step_label.text = step_text.strip_edges()
		step_label.visible = not step_label.text.is_empty()

		instruction_text.text = (
			"[center]" +
			body_text.strip_edges() +
			"[/center]"
		)

		_refresh_illustrations()

	continue_button.disabled = _continue_target == null
	visible = true
	_check_orientation()


func hide_presenter() -> void:
	visible = false
	_source_panel = null
	_continue_target = null


func _refresh_illustrations() -> void:
	var textures: Array[Texture2D] = []

	if is_instance_valid(_source_panel):
		_collect_textures(
			_source_panel,
			textures
		)

	var slots: Array[TextureRect] = [
		illustration_a,
		illustration_b,
		illustration_c
	]

	for index in range(slots.size()):
		var slot: TextureRect = slots[index]

		if index < textures.size():
			slot.texture = textures[index]
			slot.visible = true
		else:
			slot.texture = null
			slot.visible = false

	illustration_row.visible = textures.size() > 0


func _collect_textures(
	root_node: Node,
	output: Array[Texture2D]
) -> void:
	for child_variant in root_node.get_children():
		var child_node: Node = child_variant as Node

		if child_node == null:
			continue

		if child_node is TextureRect:
			var texture_node: TextureRect = child_node as TextureRect

			if texture_node.texture != null:
				output.append(texture_node.texture)

				if output.size() >= 3:
					return

		_collect_textures(
			child_node,
			output
		)

		if output.size() >= 3:
			return


func _present_level2_rich_content() -> void:
	var cards: Array[VBoxContainer] = [
		level2_food_1,
		level2_food_2,
		level2_food_3,
		level2_food_4,
		level2_food_5,
		level2_food_6
	]

	for index in range(LEVEL2_TUTORIAL_FOODS.size()):
		var food_data: Dictionary = LEVEL2_TUTORIAL_FOODS[index]
		var display_name: String = str(
			food_data.get("name", "")
		)
		var texture_path: String = str(
			food_data.get("path", "")
		)
		var food_texture: Texture2D = null

		if ResourceLoader.exists(texture_path):
			var texture_resource: Resource = load(texture_path)

			if texture_resource is Texture2D:
				food_texture = texture_resource as Texture2D

		_set_level2_food_card(
			cards[index],
			display_name,
			food_texture
		)


func _set_level2_food_card(
	card: VBoxContainer,
	display_name: String,
	food_texture: Texture2D
) -> void:
	if card == null:
		return

	var image_slot: TextureRect = card.get_node_or_null(
		"Card/Center/FoodImage"
	) as TextureRect
	var name_slot: Label = card.get_node_or_null(
		"FoodName"
	) as Label

	if name_slot != null:
		name_slot.text = display_name

	if image_slot != null:
		image_slot.texture = food_texture
		image_slot.visible = food_texture != null

func _on_continue_pressed() -> void:
	if not is_instance_valid(_continue_target):
		return

	_continue_target.emit_signal("pressed")

	var host: Node = get_parent()

	if (
		host != null
		and host.has_method("_refresh_level_tutorial_presenter")
	):
		host.call_deferred(
			"_refresh_level_tutorial_presenter"
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
	tutorial_ui.visible = not portrait


