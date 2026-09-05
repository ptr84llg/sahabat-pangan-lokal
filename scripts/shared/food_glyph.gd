class_name FoodGlyph
extends Control

const FOOD_TEXTURE_PATHS := {
	"food_rice": "res://assets/visual/foods/food_rice.png",
	"food_cassava": "res://assets/visual/foods/food_cassava.png",
	"food_water_spinach": "res://assets/visual/foods/food_water_spinach.png",
	"food_spinach": "res://assets/visual/foods/food_spinach.png",
	"food_banana": "res://assets/visual/foods/food_banana.png",
	"food_papaya": "res://assets/visual/foods/food_papaya.png",
	"food_corn": "res://assets/visual/foods/food_corn.png",
	"food_sweet_potato": "res://assets/visual/foods/food_sweet_potato.png",
	"food_eggplant": "res://assets/visual/foods/food_eggplant.png",
	"food_cucumber": "res://assets/visual/foods/food_cucumber.png",
	"food_mango": "res://assets/visual/foods/food_mango.png",
	"food_guava": "res://assets/visual/foods/food_guava.png",
	"food_tilapia": "res://assets/visual/foods/food_tilapia.png",
	"food_catfish": "res://assets/visual/foods/food_catfish.png"
}

@export var food_id := "":
	set(value):
		food_id = value
		_refresh_texture()
		queue_redraw()

var _food_texture: Texture2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh_texture()
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _refresh_texture() -> void:
	_food_texture = null
	var texture_path: String = str(FOOD_TEXTURE_PATHS.get(food_id, ""))

	if texture_path.is_empty() or not ResourceLoader.exists(texture_path):
		return

	var loaded_resource: Resource = load(texture_path)

	if loaded_resource is Texture2D:
		_food_texture = loaded_resource

func _draw() -> void:
	if _food_texture == null:
		_draw_missing_food()
		return

	var source_size: Vector2 = _food_texture.get_size()

	if source_size.x <= 0.0 or source_size.y <= 0.0:
		return

	var available_size: Vector2 = size * 0.94
	var scale_value: float = min(
		available_size.x / source_size.x,
		available_size.y / source_size.y
	)
	var draw_size: Vector2 = source_size * scale_value
	var draw_position: Vector2 = (size - draw_size) * 0.5

	draw_texture_rect(
		_food_texture,
		Rect2(draw_position, draw_size),
		false
	)

func _draw_missing_food() -> void:
	var radius: float = min(size.x, size.y) * 0.30
	var center: Vector2 = size * 0.5
	draw_circle(center, radius, Color(0.92, 0.94, 0.86, 0.95))
	draw_arc(
		center,
		radius,
		0.0,
		TAU,
		32,
		Color(0.35, 0.55, 0.21, 0.90),
		2.0
	)