class_name MovingLaneController
extends Node

const FOOD_CARD_SCENE := preload("res://scenes/shared/food_card.tscn")

var top_lane: Control
var bottom_lane: Control
var food_ids: Array = []
var cards_by_id: Dictionary = {}
var origin_lane: Dictionary = {}
var top_order: Array = []
var bottom_order: Array = []
var speed := 72.0
var moving := false
var show_coin := false
const CARD_SIZE := Vector2(112, 104)
const GAP := 24.0

func attach(new_top_lane: Control, new_bottom_lane: Control) -> void:
    top_lane = new_top_lane
    bottom_lane = new_bottom_lane

func configure(new_food_ids: Array, lane_speed: float) -> void:
    food_ids = new_food_ids.duplicate()
    speed = max(10.0, lane_speed)

func build_assignment() -> void:
    clear_cards()
    var shuffled := food_ids.duplicate()
    shuffled.shuffle()
    var split := int(shuffled.size() / 2.0)
    top_order = shuffled.slice(0, split)
    bottom_order = shuffled.slice(split, shuffled.size())
    for fid_value in top_order:
        _spawn_card(str(fid_value), top_lane, "top")
    for fid_value in bottom_order:
        _spawn_card(str(fid_value), bottom_lane, "bottom")
    call_deferred("_layout_all")

func start() -> void:
    moving = true

func stop() -> void:
    moving = false

func set_coin_visible(visible: bool) -> void:
    show_coin = visible
    for fid in cards_by_id.keys():
        var card: FoodCard = cards_by_id[fid]
        var food := ContentDatabase.get_food(str(fid))
        card.setup(str(fid), str(food.get("display_name", "")), str(food.get("group_id", "")), int(food.get("coin_value", -1)), false, show_coin, "festival_food_card")

func card_for(food_id: String) -> FoodCard:
    return cards_by_id.get(food_id, null)

func hold_card(card: FoodCard, holder: Node) -> void:
    if card == null:
        return
    var parent := card.get_parent()
    if parent != null:
        parent.remove_child(card)
    holder.add_child(card)
    card.position = Vector2.ZERO
    card.lock_card()

func return_card(card: FoodCard) -> void:
    if card == null:
        return
    var lane_key := str(origin_lane.get(card.food_id, "top"))
    var lane := top_lane if lane_key == "top" else bottom_lane
    var parent := card.get_parent()
    if parent != null:
        parent.remove_child(card)
    lane.add_child(card)
    card.size = CARD_SIZE
    card.locked = false
    card.mouse_filter = Control.MOUSE_FILTER_STOP
    card.modulate = Color.WHITE
    var food := ContentDatabase.get_food(card.food_id)
    card.setup(card.food_id, str(food.get("display_name", "")), str(food.get("group_id", "")), int(food.get("coin_value", -1)), false, show_coin, "festival_food_card")
    _insert_position(card, lane, lane_key)

func return_all_held() -> void:
    for fid in cards_by_id.keys():
        var card: FoodCard = cards_by_id[fid]
        if card.get_parent() != top_lane and card.get_parent() != bottom_lane:
            return_card(card)

func cards_in_lane_count() -> int:
    var total := 0
    for card in cards_by_id.values():
        if card.get_parent() == top_lane or card.get_parent() == bottom_lane:
            total += 1
    return total

func assignment_snapshot() -> Dictionary:
    return {"top":top_order.duplicate(),"bottom":bottom_order.duplicate()}

func clear_cards() -> void:
    if top_lane != null:
        for c in top_lane.get_children():
            c.queue_free()
    if bottom_lane != null:
        for c in bottom_lane.get_children():
            c.queue_free()
    cards_by_id.clear()
    origin_lane.clear()
    top_order.clear()
    bottom_order.clear()

func _spawn_card(food_id: String, lane: Control, lane_key: String) -> void:
    var food := ContentDatabase.get_food(food_id)
    var card: FoodCard = FOOD_CARD_SCENE.instantiate()
    lane.add_child(card)
    card.size = CARD_SIZE
    card.setup(food_id, str(food.get("display_name", "")), str(food.get("group_id", "")), int(food.get("coin_value", -1)), false, show_coin, "festival_food_card")
    cards_by_id[food_id] = card
    origin_lane[food_id] = lane_key

func _layout_all() -> void:
    _layout_lane(top_lane, top_order)
    _layout_lane(bottom_lane, bottom_order)

func _layout_lane(lane: Control, order: Array) -> void:
    if lane == null:
        return
    var step := CARD_SIZE.x + GAP
    for i in range(order.size()):
        var card: FoodCard = cards_by_id.get(str(order[i]), null)
        if card != null and card.get_parent() == lane:
            card.size = CARD_SIZE
            card.position = Vector2(i * step, max(0.0, (lane.size.y - CARD_SIZE.y) * 0.5))

func _insert_position(card: FoodCard, lane: Control, lane_key: String) -> void:
    var xs: Array[float] = []
    for child in lane.get_children():
        if child != card and child is FoodCard:
            xs.append(child.position.x)
    if xs.is_empty():
        card.position = Vector2(0, max(0.0, (lane.size.y - CARD_SIZE.y) * 0.5))
        return
    if lane_key == "top":
        card.position = Vector2(xs.max() + CARD_SIZE.x + GAP, max(0.0, (lane.size.y - CARD_SIZE.y) * 0.5))
    else:
        card.position = Vector2(xs.min() - CARD_SIZE.x - GAP, max(0.0, (lane.size.y - CARD_SIZE.y) * 0.5))

func _process(delta: float) -> void:
    if not moving or top_lane == null or bottom_lane == null:
        return
    _move_lane(top_lane, -1.0, delta)
    _move_lane(bottom_lane, 1.0, delta)

func _move_lane(lane: Control, direction: float, delta: float) -> void:
    var cards: Array[FoodCard] = []
    for child in lane.get_children():
        if child is FoodCard:
            cards.append(child as FoodCard)
    if cards.is_empty():
        return
    for card in cards:
        card.position.x += direction * speed * delta
    var step := CARD_SIZE.x + GAP
    if direction < 0.0:
        var max_x := cards[0].position.x
        for card in cards:
            max_x = max(max_x, card.position.x)
        for card in cards:
            if card.position.x + CARD_SIZE.x < 0.0:
                max_x += step
                card.position.x = max_x
    else:
        var min_x := cards[0].position.x
        for card in cards:
            min_x = min(min_x, card.position.x)
        for card in cards:
            if card.position.x > lane.size.x:
                min_x -= step
                card.position.x = min_x
