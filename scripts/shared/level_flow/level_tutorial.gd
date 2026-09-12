extends Control


const LEVEL1_TUTORIAL_FOODS: Array[Dictionary] = [
	{
		"name": "Beras",
		"path": "res://assets/visual/foods/food_rice.png"
	},
	{
		"name": "Singkong",
		"path": "res://assets/visual/foods/food_cassava.png"
	},
	{
		"name": "Kangkung",
		"path": "res://assets/visual/foods/food_water_spinach.png"
	},
	{
		"name": "Bayam",
		"path": "res://assets/visual/foods/food_spinach.png"
	},
	{
		"name": "Pisang",
		"path": "res://assets/visual/foods/food_banana.png"
	},
	{
		"name": "Pepaya",
		"path": "res://assets/visual/foods/food_papaya.png"
	}
]

const LEVEL3_TUTORIAL_FOODS: Array[Dictionary] = [
    {
        "name": "Ikan Nila",
        "path": "res://assets/visual/foods/food_tilapia.png"
    },
    {
        "name": "Ikan Lele",
        "path": "res://assets/visual/foods/food_catfish.png"
    }
]

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
@onready var level1_rich_content: VBoxContainer = %Level1RichContent
@onready var level1_food_1: VBoxContainer = %Level1Food1
@onready var level1_food_2: VBoxContainer = %Level1Food2
@onready var level1_food_3: VBoxContainer = %Level1Food3
@onready var level1_food_4: VBoxContainer = %Level1Food4
@onready var level1_food_5: VBoxContainer = %Level1Food5
@onready var level1_food_6: VBoxContainer = %Level1Food6
@onready var level1_interactive_content: VBoxContainer = %Level1InteractiveContent
@onready var level1_instruction: RichTextLabel = %Level1Instruction
@onready var level1_source_holder: CenterContainer = %Level1SourceHolder
@onready var level1_demo_food: FoodCard = %Level1DemoFood
@onready var level1_demo_target: FoodDropSlot = %Level1DemoTarget
@onready var level3_rich_content: VBoxContainer = %Level3RichContent
@onready var level3_food_1: VBoxContainer = %Level3Food1
@onready var level3_food_2: VBoxContainer = %Level3Food2
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
var _level1_intro_active: bool = true
var _level3_intro_active: bool = true
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
				"Bagus. Sekarang [b]geser gambar itu ke kotak kosong di sebelah kanan[/b], lalu lepaskan."
			)
		return

	if what != NOTIFICATION_DRAG_END or not _level1_demo_drag_active:
		return

	_level1_demo_drag_active = false

	if _level1_completed:
		return

	if not get_viewport().gui_is_drag_successful():
		_set_level1_instruction(
			"Belum masuk, [b]{player_name}[/b]. Coba lagi, ya.\n[b]Klik dan tahan gambarnya, lalu geser sampai ke kotak.[/b]"
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
	var reset_level3: bool = (
		_source_panel != source_panel
		or not visible
		or _level_no != 3
	)

	_source_panel = source_panel
	_continue_target = continue_target

	if is_instance_valid(_source_panel):
		_source_panel.visible = false

	var host: Node = get_parent()
	_level_no = 0

	if host != null:
		_level_no = int(host.get_meta("level_no", 0))

	var use_level1_flow: bool = _level_no == 1
	var use_level2_rich: bool = _level_no == 2
	var use_level3_flow: bool = _level_no == 3

	level1_rich_content.visible = false
	level1_interactive_content.visible = false
	level2_rich_content.visible = use_level2_rich
	level3_rich_content.visible = false
	illustration_row.visible = false

	step_label.text = step_text.strip_edges()
	instruction_text.text = (
		"[center]" +
		body_text.strip_edges() +
		"[/center]"
	)

	if use_level1_flow:
		_level1_active = true
		_level3_intro_active = true

		if reset_level1:
			_level1_intro_active = true
			_reset_level1_interactive()
			_present_level1_rich_content()

		_sync_level1_stage_visibility()
		_sync_level1_continue_state()
	elif use_level2_rich:
		_level1_active = false
		_level1_demo_drag_active = false
		_level3_intro_active = true
		step_label.visible = false
		instruction_text.visible = false
		_present_level2_rich_content()
		continue_button.text = "LANJUTKAN"
		continue_button.disabled = _continue_target == null
	elif use_level3_flow:
		_level1_active = false
		_level1_demo_drag_active = false

		if reset_level3:
			_level3_intro_active = true
			_present_level3_rich_content()

		_sync_level3_stage_visibility()
		_sync_level3_continue_state()
	else:
		_level1_active = false
		_level1_demo_drag_active = false
		_level3_intro_active = true
		step_label.visible = not step_label.text.is_empty()
		instruction_text.visible = true

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
	_level1_intro_active = true
	_level3_intro_active = true
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
		"Nah, [b]{player_name}[/b], kita coba satu dulu, ya.\n[b]Klik dan tahan gambar pangan di sebelah kiri.[/b]"
	)
	_sync_level1_continue_state()


func _sync_level1_continue_state() -> void:
	if _level1_intro_active:
		continue_button.text = "LANJUTKAN"
		continue_button.disabled = _continue_target == null
		return

	continue_button.text = "MULAI BERMAIN"
	continue_button.disabled = (
		not _level1_completed
		or _continue_target == null
	)

func _set_level1_instruction(
	message: String,
	_success: bool = false
) -> void:
	var formatted_message: String = _format_level1_tutorial_text(
		message
	)

	level1_instruction.text = (
		"[center]"
		+ formatted_message
		+ "[/center]"
	)

func _on_level1_demo_food_gui_input(event: InputEvent) -> void:
	if not _level1_active or _level1_completed:
		return

	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton

		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_set_level1_instruction(
				"Bagus. Sekarang [b]geser gambar itu ke kotak kosong di sebelah kanan[/b], lalu lepaskan."
			)
			return

	if event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event as InputEventScreenTouch

		if touch_event.pressed:
			_set_level1_instruction(
				"Bagus. Sekarang [b]geser gambar itu ke kotak kosong di sebelah kanan[/b], lalu lepaskan."
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
		"[b]Bagus, {player_name}![/b] Kamu sudah tahu caranya.\nSekarang kamu siap mencocokkan pangan yang lain dengan namanya.",
		true
	)
	_sync_level1_continue_state()

func _sync_level1_stage_visibility() -> void:
	level1_rich_content.visible = _level1_intro_active
	level1_interactive_content.visible = not _level1_intro_active


func _present_level1_rich_content() -> void:
	var cards: Array[VBoxContainer] = [
		level1_food_1,
		level1_food_2,
		level1_food_3,
		level1_food_4,
		level1_food_5,
		level1_food_6
	]

	for index in range(LEVEL1_TUTORIAL_FOODS.size()):
		var food_data: Dictionary = LEVEL1_TUTORIAL_FOODS[index]
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

		_set_level1_food_card(
			cards[index],
			display_name,
			food_texture
		)


func _set_level1_food_card(
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


func _format_level1_tutorial_text(message: String) -> String:
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

	return message.replace(
		"{player_name}",
		player_display_name
	)

func _sync_level3_stage_visibility() -> void:
	level3_rich_content.visible = _level3_intro_active
	step_label.visible = (
		not _level3_intro_active
		and not step_label.text.is_empty()
	)
	instruction_text.visible = not _level3_intro_active


func _sync_level3_continue_state() -> void:
	if _level3_intro_active:
		continue_button.text = "LANJUTKAN"
	else:
		continue_button.text = "COBA SEKARANG"

	continue_button.disabled = _continue_target == null


func _present_level3_rich_content() -> void:
	var cards: Array[VBoxContainer] = [
		level3_food_1,
		level3_food_2
	]

	for index in range(LEVEL3_TUTORIAL_FOODS.size()):
		var food_data: Dictionary = LEVEL3_TUTORIAL_FOODS[index]
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

		_set_level3_food_card(
			cards[index],
			display_name,
			food_texture
		)


func _set_level3_food_card(
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

	if _level_no == 1:
		if _level1_intro_active:
			_level1_intro_active = false
			_sync_level1_stage_visibility()
			_sync_level1_continue_state()
			return

		if not _level1_completed:
			return

	if _level_no == 3 and _level3_intro_active:
		_level3_intro_active = false
		_sync_level3_stage_visibility()
		_sync_level3_continue_state()
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


