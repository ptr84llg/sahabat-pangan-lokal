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
@onready var level1_interactive_content: VBoxContainer = %Level1InteractiveContent
@onready var level1_instruction: RichTextLabel = %Level1Instruction
@onready var level1_source_holder: CenterContainer = %Level1SourceHolder
@onready var level1_demo_food: FoodCard = %Level1DemoFood
@onready var level1_demo_target: FoodDropSlot = %Level1DemoTarget
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
var _level_no: int = 0
var _level1_active: bool = false
var _level1_completed: bool = false
var _level1_demo_drag_active: bool = false


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_force_landscape()
	continue_button.pressed.connect(_on_continue_pressed)
	level1_demo_food.gui_input.connect(_on_level1_demo_food_gui_input)
	level1_demo_target.drop_received.connect(_on_level1_tutorial_drop_received)
	get_viewport().size_changed.connect(_check_orientation)
	_check_orientation()


func _notification(what: int) -> void:
	if not _level1_active:
		return

	if what == NOTIFICATION_DRAG_BEGIN:
		var drag_data: Variant = get_viewport().gui_get_drag_data()

		if _is_level1_demo_drag(drag_data):
			_level1_demo_drag_active = true
			_set_level1_instruction(
				"Sekarang pindahkan pangan ke kotak kosong di sebelah kanan, lalu lepaskan."
			)
		return

	if what != NOTIFICATION_DRAG_END or not _level1_demo_drag_active:
		return

	_level1_demo_drag_active = false

	if _level1_completed:
		return

	if not get_viewport().gui_is_drag_successful():
		_set_level1_instruction(
			"Belum masuk ke kotak target. Klik dan tahan pangan, lalu coba lagi."
		)


func present(
	source_panel: Control,
	step_text: String,
	body_text: String,
	continue_target: Button
) -> void:
	var reset_level1: bool = (
		_source_panel != source_panel
		or not visible
		or not _level1_active
	)

	_source_panel = source_panel
	_continue_target = continue_target

	if is_instance_valid(_source_panel):
		_source_panel.visible = false

	var host: Node = get_parent()
	_level_no = 0

	if host != null:
		_level_no = int(host.get_meta("level_no", 0))

	var use_level1_interactive: bool = _level_no == 1
	var use_level2_rich: bool = _level_no == 2

	level1_interactive_content.visible = use_level1_interactive
	level2_rich_content.visible = use_level2_rich
	step_label.visible = not use_level1_interactive and not use_level2_rich
	illustration_row.visible = false
	instruction_text.visible = not use_level1_interactive and not use_level2_rich

	if use_level1_interactive:
		_level1_active = true

		if reset_level1:
			_reset_level1_interactive()
		else:
			_sync_level1_continue_state()
	elif use_level2_rich:
		_level1_active = false
		_level1_demo_drag_active = false
		_present_level2_rich_content()
		continue_button.text = "LANJUTKAN"
		continue_button.disabled = _continue_target == null
	else:
		_level1_active = false
		_level1_demo_drag_active = false
		step_label.text = step_text.strip_edges()
		step_label.visible = not step_label.text.is_empty()

		instruction_text.text = (
			"[center]" +
			body_text.strip_edges() +
			"[/center]"
		)

		_refresh_illustrations()
		continue_button.text = "LANJUTKAN"
		continue_button.disabled = _continue_target == null

	visible = true
	_check_orientation()


func hide_presenter() -> void:
	visible = false
	_source_panel = null
	_continue_target = null
	_level_no = 0
	_level1_active = false
	_level1_demo_drag_active = false


func _reset_level1_interactive() -> void:
	_level1_completed = false
	_level1_demo_drag_active = false

	var current_parent: Node = level1_demo_food.get_parent()

	if current_parent != level1_source_holder:
		if current_parent != null:
			current_parent.remove_child(level1_demo_food)

		level1_source_holder.add_child(level1_demo_food)

	level1_demo_food.set_market_selected(false)
	level1_demo_food.setup(
		"food_rice",
		"",
		"",
		-1,
		false,
		false,
		"food_card"
	)
	level1_demo_target.setup("food_rice", "")
	level1_demo_target.title_label.visible = false
	_set_level1_instruction(
		"Klik dan tahan gambar pangan di sebelah kiri."
	)
	_sync_level1_continue_state()


func _sync_level1_continue_state() -> void:
	continue_button.text = "MULAI BERMAIN"
	continue_button.disabled = (
		not _level1_completed
		or _continue_target == null
	)


func _set_level1_instruction(message: String, success: bool = false) -> void:
	if success:
		level1_instruction.text = (
			"[center][b]Bagus![/b]\n"
			+ message
			+ "[/center]"
		)
		return

	level1_instruction.text = (
		"[center]" + message + "[/center]"
	)


func _on_level1_demo_food_gui_input(event: InputEvent) -> void:
	if not _level1_active or _level1_completed:
		return

	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton

		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_set_level1_instruction(
				"Sekarang pindahkan pangan ke kotak kosong di sebelah kanan, lalu lepaskan."
			)
			return

	if event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event as InputEventScreenTouch

		if touch_event.pressed:
			_set_level1_instruction(
				"Sekarang pindahkan pangan ke kotak kosong di sebelah kanan, lalu lepaskan."
			)


func _is_level1_demo_drag(data: Variant) -> bool:
	if not data is Dictionary:
		return false

	var drag_data: Dictionary = data
	var source_card: Variant = drag_data.get("card")

	return (
		source_card == level1_demo_food
		and str(drag_data.get("food_id", "")) == "food_rice"
		and str(drag_data.get("kind", "")) == "food_card"
	)


func _on_level1_tutorial_drop_received(
	food_id: String,
	source_card: FoodCard,
	slot: FoodDropSlot
) -> void:
	if not _level1_active or _level1_completed:
		return

	if source_card != level1_demo_food or slot != level1_demo_target:
		return

	if food_id != "food_rice":
		source_card.show_wrong_feedback()
		return

	level1_demo_target.accept_card(source_card)
	_level1_completed = true
	_set_level1_instruction(
		"Tutorial cara bermain sudah selesai.",
		true
	)
	_sync_level1_continue_state()

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

	if _level_no == 1 and not _level1_completed:
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


