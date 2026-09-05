class_name GroupingController
extends Node

signal progress_changed(matched: int, total: int, score: int, group_counts: Dictionary)
signal batch_completed(batch_id: int)
signal all_grouped(score: int)
signal feedback(text: String, correct: bool)

var config: Dictionary = {}
var foods: Array[Dictionary] = []
var foods_by_id: Dictionary = {}
var zones_by_group: Dictionary = {}
var attempts_by_food: Dictionary = {}
var group_counts: Dictionary = {}
var matched_ids: Array[String] = []
var batch_ids: Array = []
var active_batch_index := 0
var active_batch_food_ids: Array[String] = []
var score := 0

func configure(level_config: Dictionary, food_data: Array[Dictionary]) -> void:
	config = level_config
	foods = food_data
	foods_by_id.clear()
	attempts_by_food.clear()
	group_counts.clear()
	matched_ids.clear()
	score = 0
	for group_id in config.get("group_ids", []):
		group_counts[str(group_id)] = 0
	for food in foods:
		var food_id := str(food.get("food_id", ""))
		foods_by_id[food_id] = food
		attempts_by_food[food_id] = 0
	_prepare_balanced_batches()

func _prepare_balanced_batches() -> void:
	var by_group: Dictionary = {}
	for group_id in config.get("group_ids", []):
		by_group[str(group_id)] = []
	for food in foods:
		var group_id := str(food.get("group_id", ""))
		by_group[group_id].append(str(food.get("food_id", "")))
	var first: Array = []
	var second: Array = []
	for group_id in config.get("group_ids", []):
		var ids: Array = by_group.get(str(group_id), []).duplicate()
		ids.shuffle()
		first.append_array(ids.slice(0, 2))
		second.append_array(ids.slice(2, 4))
	first.shuffle()
	second.shuffle()
	batch_ids = [first, second]

func get_batch_food_ids(index: int) -> Array:
	if index < 0 or index >= batch_ids.size():
		return []
	return batch_ids[index].duplicate()

func activate_batch(index: int) -> void:
	active_batch_index = index
	active_batch_food_ids.clear()
	for value in get_batch_food_ids(index):
		active_batch_food_ids.append(str(value))

func register_zone(group_id: String, zone: GroupDropZone) -> void:
	zones_by_group[group_id] = zone
	zone.drop_received.connect(_on_drop_received)

func _on_drop_received(food_id: String, card: FoodCard, zone: GroupDropZone) -> void:
	if food_id in matched_ids or food_id not in active_batch_food_ids:
		return
	attempts_by_food[food_id] = int(attempts_by_food.get(food_id, 0)) + 1
	var attempt_no := int(attempts_by_food[food_id])
	var food: Dictionary = foods_by_id.get(food_id, {})
	var actual_group := str(food.get("group_id", ""))
	var correct := actual_group == zone.accepted_group_id
	AnalyticsLogger.log_event("drag_attempt", {
		"level_session_id": DurationTracker.session_id,
		"level_no": 2,
		"food_id": food_id,
		"group_id": actual_group,
		"target_id": zone.accepted_group_id,
		"batch_id": active_batch_index + 1,
		"correct": correct,
		"attempt_no": attempt_no
	})
	if correct:
		var scoring: Dictionary = config.get("scoring", {})
		score += int(scoring.get("food_first_attempt", 5)) if attempt_no == 1 else int(scoring.get("food_after_retry", 3))
		matched_ids.append(food_id)
		group_counts[actual_group] = int(group_counts.get(actual_group, 0)) + 1
		zone.accept_card(card, int(group_counts[actual_group]), int(config.get("target_per_group", 4)))
		UIMotion.play_pop(card, 1.06)
		UIMotion.play_pop(zone, 1.035)
		feedback.emit("Tepat! Pangan masuk ke kelompok yang sesuai.", true)
		progress_changed.emit(matched_ids.size(), foods.size(), score, group_counts.duplicate(true))
		if matched_ids.size() == foods.size():
			all_grouped.emit(score)
		elif _active_batch_complete():
			batch_completed.emit(active_batch_index + 1)
	else:
		card.show_wrong_feedback()
		UIMotion.play_shake(card, 6.0)
		feedback.emit("Belum tepat. Coba perhatikan kembali jenis pangan ini.", false)

func _active_batch_complete() -> bool:
	for food_id in active_batch_food_ids:
		if food_id not in matched_ids:
			return false
	return true

func request_hint() -> void:
	for food_id in active_batch_food_ids:
		if food_id not in matched_ids:
			var food: Dictionary = foods_by_id.get(food_id, {})
			var group_id := str(food.get("group_id", ""))
			if zones_by_group.has(group_id):
				var zone: GroupDropZone = zones_by_group[group_id]
				zone.pulse_hint()
				AnalyticsLogger.log_event("hint_used", {"level_no":2,"context_id":food_id,"batch_id":active_batch_index+1})
				feedback.emit("Perhatikan kelompok yang sedang ditandai.", true)
				return
