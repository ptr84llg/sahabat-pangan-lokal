class_name GroupingController
extends Node

const V3_GAME_ID: String = "L2-G01"
const V3_GAME_TYPE: String = "classification_drag_drop"
const V3_INSTRUCTION_ID: String = "INST-L2-G01-CLASSIFY"
const V3_INSTRUCTION_TEXT: String = "Kelompokkan setiap pangan ke jenis yang sesuai."
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
var mission_segment_started_active_ms: int = -1

func configure(level_config: Dictionary, food_data: Array[Dictionary]) -> void:
	config = level_config
	foods = food_data
	foods_by_id.clear()
	attempts_by_food.clear()
	group_counts.clear()
	matched_ids.clear()
	score = 0
	mission_segment_started_active_ms = -1
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

func begin_mission_timing() -> void:
	mission_segment_started_active_ms = (
		DurationTracker.current_active_ms()
	)


func _on_drop_received(
	food_id: String,
	card: FoodCard,
	zone: GroupDropZone
) -> void:
	if (
		food_id in matched_ids
		or food_id not in active_batch_food_ids
	):
		return

	attempts_by_food[food_id] = int(
		attempts_by_food.get(food_id, 0)
	) + 1
	var attempt_no: int = int(
		attempts_by_food[food_id]
	)
	var food: Dictionary = foods_by_id.get(
		food_id,
		{}
	)
	var actual_group: String = str(
		food.get("group_id", "")
	)
	var correct: bool = (
		actual_group == zone.accepted_group_id
	)

	AnalyticsLogger.log_event(
		"drag_attempt",
		{
			"level_session_id": DurationTracker.session_id,
			"level_no": 2,
			"food_id": food_id,
			"group_id": actual_group,
			"target_id": zone.accepted_group_id,
			"batch_id": active_batch_index + 1,
			"correct": correct,
			"attempt_no": attempt_no
		}
	)

	if correct:
		var scoring: Dictionary = config.get(
			"scoring",
			{}
		)
		score += (
			int(
				scoring.get(
					"food_first_attempt",
					5
				)
			)
			if attempt_no == 1
			else int(
				scoring.get(
					"food_after_retry",
					3
				)
			)
		)
		_record_v3_drop(
			food_id,
			card,
			zone,
			"correct_drop"
		)
		matched_ids.append(food_id)
		group_counts[actual_group] = int(
			group_counts.get(
				actual_group,
				0
			)
		) + 1
		zone.accept_card(
			card,
			int(group_counts[actual_group]),
			int(
				config.get(
					"target_per_group",
					4
				)
			)
		)
		UIMotion.play_pop(card, 1.06)
		UIMotion.play_pop(zone, 1.035)
		feedback.emit(
			"Tepat! Pangan masuk ke kelompok yang sesuai.",
			true
		)
		progress_changed.emit(
			matched_ids.size(),
			foods.size(),
			score,
			group_counts.duplicate(true)
		)

		if matched_ids.size() == foods.size():
			all_grouped.emit(score)
		elif _active_batch_complete():
			batch_completed.emit(
				active_batch_index + 1
			)
	else:
		_record_v3_drop(
			food_id,
			card,
			zone,
			"wrong_target_drop"
		)
		card.show_wrong_feedback()
		UIMotion.play_shake(card, 6.0)
		feedback.emit(
			"Belum tepat. Coba perhatikan kembali jenis pangan ini.",
			false
		)

func _active_batch_complete() -> bool:
	for food_id in active_batch_food_ids:
		if food_id not in matched_ids:
			return false
	return true

func request_hint() -> void:
	for food_id in active_batch_food_ids:
		if food_id in matched_ids:
			continue

		var food: Dictionary = foods_by_id.get(
			food_id,
			{}
		)
		var group_id: String = str(
			food.get("group_id", "")
		)

		if not zones_by_group.has(group_id):
			continue

		var zone: GroupDropZone = (
			zones_by_group[group_id]
		)
		zone.pulse_hint()

		AnalyticsLogger.log_event(
			"hint_used",
			{
				"level_no": 2,
				"context_id": food_id,
				"batch_id": active_batch_index + 1
			}
		)

		if not TelemetryManager.record_hint_event(
			2,
			V3_GAME_ID,
			V3_GAME_TYPE,
			food_id
		):
			push_warning(
				"Telemetry v3 Level 2 Game 1 belum dapat merekam hint."
			)

		feedback.emit(
			"Perhatikan kelompok yang sedang ditandai.",
			true
		)
		return


func _record_v3_drop(
	food_id: String,
	card: FoodCard,
	zone: GroupDropZone,
	result: String
) -> void:
	var drag_started_ticks_ms: Variant = null

	if card.has_meta("spl_drag_started_ticks_ms"):
		drag_started_ticks_ms = int(
			card.get_meta(
				"spl_drag_started_ticks_ms"
			)
		)

	var drag_started_at_unix: Variant = null

	if card.has_meta("spl_drag_started_at_unix"):
		drag_started_at_unix = card.get_meta(
			"spl_drag_started_at_unix"
		)

	var dropped_ticks_ms: int = Time.get_ticks_msec()
	var decision_duration_ms: Variant = null

	if drag_started_ticks_ms != null:
		var started_ticks_ms: int = int(
			drag_started_ticks_ms
		)

		if dropped_ticks_ms >= started_ticks_ms:
			decision_duration_ms = (
				dropped_ticks_ms
				- started_ticks_ms
			)

	var mission_duration_ms: Variant = null

	if (
		result == "correct_drop"
		and mission_segment_started_active_ms >= 0
	):
		var completed_active_ms: int = (
			DurationTracker.current_active_ms()
		)

		if (
			completed_active_ms
			>= mission_segment_started_active_ms
		):
			mission_duration_ms = (
				completed_active_ms
				- mission_segment_started_active_ms
			)
			mission_segment_started_active_ms = (
				completed_active_ms
			)

	var food: Dictionary = foods_by_id.get(
		food_id,
		{}
	)
	var actual_group: String = str(
		food.get(
			"group_id",
			""
		)
	)
	var selected_group: String = (
		zone.accepted_group_id
	)
	var context: Dictionary = {
		"level_no": 2,
		"game_id": V3_GAME_ID,
		"game_type": V3_GAME_TYPE,
		"result": result,
		"current_score": score,
		"round_id": (
			"L2-BATCH-"
			+ str(active_batch_index + 1)
		),
		"instruction": {
			"instruction_id": V3_INSTRUCTION_ID,
			"instruction_version": 1,
			"instruction_text": V3_INSTRUCTION_TEXT,
			"content_version": (
				ContentDatabase.content_version
			)
		},
		"dragged_item": {
			"food_id": food_id,
			"food_name_snapshot": (
				_food_display_name(food_id)
			)
		},
		"drop_result": {
			"dropped_target_id": (
				"L2-GROUP-"
				+ selected_group
			),
			"dropped_target_name_snapshot": (
				_group_display_name(
					selected_group
				)
			),
			"expected_target_ids": [
				"L2-GROUP-" + actual_group
			],
			"expected_target_name_snapshot": (
				_group_display_name(
					actual_group
				)
			)
		},
		"timing": {
			"drag_started_at_unix": (
				drag_started_at_unix
			),
			"drag_started_ticks_ms": (
				drag_started_ticks_ms
			),
			"dropped_at_ticks_ms": (
				dropped_ticks_ms
			),
			"decision_duration_ms": (
				decision_duration_ms
			),
			"mission_duration_ms": (
				mission_duration_ms
			)
		},
		"input_method": "unknown"
	}

	if not TelemetryManager.record_drop_event(
		context
	):
		push_warning(
			"Telemetry v3 Level 2 Game 1 belum dapat merekam drop event."
		)


func _food_display_name(
	food_id: String
) -> String:
	var food: Dictionary = foods_by_id.get(
		food_id,
		{}
	)
	return str(
		food.get(
			"display_name",
			food_id
		)
	)


func _group_display_name(
	group_id: String
) -> String:
	var display_name: String = (
		ContentDatabase.get_group_name(
			group_id
		)
	).strip_edges()

	if not display_name.is_empty():
		return display_name

	return (
		group_id
		.replace("group_", "")
		.replace("_", " ")
		.capitalize()
	)