class_name ShoppingController
extends Node

signal basket_changed(selected_ids: Array, coin_remaining: int, selected_groups: Dictionary)
signal feedback(text: String, correct: bool)
signal shopping_success(final_ids: Array)

var config: Dictionary = {}
var foods: Array[Dictionary] = []
var foods_by_id: Dictionary = {}
var market_container: Control = null
var basket_slots: Array[BasketSlot] = []
var selected_by_group: Dictionary = {}
var check_attempt := 0

func configure(level_config: Dictionary, food_data: Array[Dictionary]) -> void:
    config = level_config
    foods = food_data
    foods_by_id.clear()
    selected_by_group.clear()
    check_attempt = 0
    for food in foods:
        foods_by_id[str(food.get("food_id", ""))] = food

func register_market_container(container: Control) -> void:
    market_container = container

func register_basket_slot(slot: BasketSlot) -> void:
    basket_slots.append(slot)
    slot.drop_received.connect(_on_basket_drop)
    slot.cancel_requested.connect(_on_basket_cancel_requested)

func _on_basket_drop(food_id: String, card: FoodCard, slot: BasketSlot) -> void:
    if _is_selected(food_id):
        return
    var food: Dictionary = foods_by_id.get(food_id, {})
    var group_id := str(food.get("group_id", ""))
    var coin_value := int(food.get("coin_value", 0))
    if selected_by_group.has(group_id):
        card.show_wrong_feedback()
        UIMotion.play_shake(card, 6.0)
        AudioManager.play_sfx("wrong")
        feedback.emit("Keranjangmu sudah memiliki pangan dari kelompok ini. Pilih satu saja.", false)
        _log_invalid(food_id, "DUPLICATE_GROUP")
        return
    if coin_used() + coin_value > int(config.get("coin_budget", 15)):
        card.show_wrong_feedback()
        UIMotion.play_shake(card, 6.0)
        AudioManager.play_sfx("wrong")
        feedback.emit("Koin Panganmu belum cukup untuk pilihan ini. Coba pertimbangkan pilihan lain.", false)
        _log_invalid(food_id, "INSUFFICIENT_COIN")
        return
    selected_by_group[group_id] = food_id
    slot.hold_card(card)
    card.custom_minimum_size = Vector2(106, 116)
    UIMotion.play_pop(card, 1.06)
    UIMotion.play_pop(slot, 1.035)
    AudioManager.play_sfx("drop_correct")
    AnalyticsLogger.log_event("basket_add", {"level_no":3,"level_session_id":DurationTracker.session_id,"food_id":food_id,"group_id":group_id,"coin_value":coin_value,"coin_remaining":coin_remaining()})
    _emit_basket()

func _on_basket_cancel_requested(slot: BasketSlot) -> void:
    var card: FoodCard = slot.current_card()
    if card == null:
        return
    var food_id := str(card.food_id)
    var food: Dictionary = foods_by_id.get(food_id, {})
    var group_id := str(food.get("group_id", ""))
    if not selected_by_group.has(group_id):
        return
    selected_by_group.erase(group_id)
    _return_card_to_market(card)
    UIMotion.play_pop(card, 1.03)
    slot.restore_placeholder()
    AnalyticsLogger.log_event("basket_remove", {"level_no":3,"level_session_id":DurationTracker.session_id,"food_id":food_id,"group_id":group_id,"coin_remaining":coin_remaining(),"source":"cancel_button"})
    _emit_basket()

func _return_card_to_market(card: FoodCard) -> void:
    if market_container == null:
        return
    var old_parent: Node = card.get_parent()
    if old_parent != null:
        old_parent.remove_child(card)
    market_container.add_child(card)
    card.custom_minimum_size = Vector2(124, 132)
    card.set_market_selected(false)

func check_shopping() -> void:
    check_attempt += 1
    var budget := int(config.get("coin_budget", 15))
    var valid := selected_by_group.size() == 4 and coin_used() <= budget
    AnalyticsLogger.log_event("shopping_check", {"level_no":3,"level_session_id":DurationTracker.session_id,"check_attempt":check_attempt,"selected_ids":selected_ids(),"coin_used":coin_used(),"valid":valid})
    if valid:
        feedback.emit("Belanjamu lengkap dan Koin Panganmu cukup!", true)
        shopping_success.emit(selected_ids())
    else:
        feedback.emit("Masih ada kelompok pangan yang belum ada di keranjang.", false)

func request_hint() -> void:
    for group_id_value in config.get("group_ids", []):
        var group_id := str(group_id_value)
        if not selected_by_group.has(group_id):
            AnalyticsLogger.log_event("hint_used", {"level_no":3,"context_id":group_id})
            feedback.emit("Perhatikan kelompok %s yang belum terisi pada daftar belanja." % ContentDatabase.get_group_name(group_id), true)
            return

func coin_used() -> int:
    var total := 0
    for food_id in selected_by_group.values():
        total += int(foods_by_id.get(str(food_id), {}).get("coin_value", 0))
    return total

func coin_remaining() -> int:
    return int(config.get("coin_budget", 15)) - coin_used()

func selected_ids() -> Array:
    return selected_by_group.values().duplicate()

func _is_selected(food_id: String) -> bool:
    return food_id in selected_by_group.values()

func _emit_basket() -> void:
    basket_changed.emit(selected_ids(), coin_remaining(), selected_by_group.duplicate(true))

func _log_invalid(food_id: String, reason: String) -> void:
    AnalyticsLogger.log_event("shopping_invalid", {"level_no":3,"level_session_id":DurationTracker.session_id,"food_id":food_id,"invalid_reason":reason,"coin_remaining":coin_remaining()})
