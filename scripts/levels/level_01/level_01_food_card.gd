extends FoodCard

const FOOD_TEXTURES: Dictionary = {
	"food_rice": "res://assets/visual/foods/food_rice.png",
	"food_cassava": "res://assets/visual/foods/food_cassava.png",
	"food_water_spinach": "res://assets/visual/foods/food_water_spinach.png",
	"food_spinach": "res://assets/visual/foods/food_spinach.png",
	"food_banana": "res://assets/visual/foods/food_banana.png",
	"food_papaya": "res://assets/visual/foods/food_papaya.png"
}

@onready var food_image: TextureRect = %FoodImage

var _drag_visual_active: bool = false


func _ready() -> void:
	custom_minimum_size = Vector2(124.0, 104.0)
	_prepare_drag_surface()
	_apply_visual(
		bool(get_meta("show_name", false)),
		bool(get_meta("show_coin", false))
	)


func _apply_visual(
	_show_name: bool,
	_show_coin: bool
) -> void:
	glyph.visible = false
	name_label.visible = false
	coin_label.visible = false
	food_image.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var texture_path: String = str(
		FOOD_TEXTURES.get(food_id, "")
	)

	if texture_path.is_empty():
		food_image.texture = null
		return

	if not ResourceLoader.exists(texture_path):
		food_image.texture = null
		return

	var loaded_resource: Resource = load(texture_path)

	if loaded_resource is Texture2D:
		food_image.texture = loaded_resource as Texture2D


func _get_drag_data(
	_at_position: Vector2
) -> Variant:
	if locked or food_id.is_empty():
		return null

	set_meta("spl_drag_started_ticks_ms", Time.get_ticks_msec())
	set_meta("spl_drag_started_at_unix", Time.get_unix_time_from_system())

	var preview: PanelContainer = PanelContainer.new()
	preview.custom_minimum_size = Vector2(116.0, 98.0)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.z_index = 4090

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.98, 0.90, 0.98)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.33, 0.55, 0.20, 1.0)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_right = 14
	style.corner_radius_bottom_left = 14
	preview.add_theme_stylebox_override(
		"panel",
		style
	)

	var preview_image: TextureRect = TextureRect.new()
	preview_image.custom_minimum_size = Vector2(108.0, 90.0)
	preview_image.texture = food_image.texture
	preview_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_image.stretch_mode = (
		TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	)
	preview_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_image.z_index = 4091
	preview.add_child(preview_image)

	preview.modulate.a = 0.98
	set_drag_preview(preview)

	_drag_visual_active = true
	var source_color: Color = modulate
	source_color.a = 0.34
	modulate = source_color

	return {
		"kind": drag_kind,
		"food_id": food_id,
		"group_id": group_id,
		"coin_value": coin_value,
		"card": self
	}


func _notification(what: int) -> void:
	if what != NOTIFICATION_DRAG_END:
		return

	if not _drag_visual_active:
		return

	_drag_visual_active = false

	if locked:
		return

	var restored_color: Color = modulate
	restored_color.a = 1.0
	modulate = restored_color
