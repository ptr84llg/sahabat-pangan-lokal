extends Node

const CONFIG_PATH: String = "res://resources/config/achievement_config.tres"

var config: AchievementConfig

func _ready() -> void:
	_load_config()

func _load_config() -> bool:
	if config != null:
		return true

	var loaded := load(CONFIG_PATH)

	if loaded is AchievementConfig:
		config = loaded as AchievementConfig
		return true

	push_error("AchievementConfig tidak dapat dimuat.")
	return false

func reconcile_current_run() -> void:
	if not _load_config():
		return

	_ensure_profile_state()

	if GameState.active_run.is_empty():
		return

	for level_no in range(1, 6):
		if GameState.level_status(level_no) != GameState.STATUS_COMPLETED:
			continue

		var key: String = str(level_no)
		var score: int = int(
			GameState.active_run.get(
				"level_scores",
				{}
			).get(
				key,
				0
			)
		)
		var duration_ms: int = int(
			GameState.active_run.get(
				"level_durations_ms",
				{}
			).get(
				key,
				0
			)
		)

		evaluate_level_completion(
			level_no,
			score,
			duration_ms
		)

func evaluate_level_completion(
	level_no: int,
	final_score: int,
	duration_ms: int
) -> Array[String]:
	if not _load_config():
		return []

	_ensure_profile_state()

	var definitions: Array[Dictionary] = _sorted_definitions()
	var unlocked_ids: Array[String] = []
	var achievements: Dictionary = GameState.profile.get(
		"achievements",
		{}
	)

	for definition in definitions:
		var title_id: String = str(
			definition.get(
				"title_id",
				""
			)
		)

		if title_id.is_empty():
			continue

		var existing: Dictionary = achievements.get(
			title_id,
			{}
		)

		if bool(existing.get("earned", false)):
			continue

		if not _rule_met(
			definition,
			level_no,
			final_score,
			duration_ms,
			achievements
		):
			continue

		achievements[title_id] = {
			"earned": true,
			"earned_at": Time.get_unix_time_from_system(),
			"display_name": str(
				definition.get(
					"display_name",
					"Gelar"
				)
			),
			"google_play_id": str(
				definition.get(
					"google_play_id",
					""
				)
			)
		}
		unlocked_ids.append(title_id)

	GameState.profile["achievements"] = achievements

	if not unlocked_ids.is_empty():
		SaveManager.request_save()

	return unlocked_ids

func title_entries() -> Array[Dictionary]:
	if not _load_config():
		return []

	_ensure_profile_state()

	var achievements: Dictionary = GameState.profile.get(
		"achievements",
		{}
	)
	var entries: Array[Dictionary] = []

	for definition in _sorted_definitions():
		var title_id: String = str(
			definition.get(
				"title_id",
				""
			)
		)
		var earned_data: Dictionary = achievements.get(
			title_id,
			{}
		)
		var entry: Dictionary = definition.duplicate(true)
		entry["earned"] = bool(
			earned_data.get(
				"earned",
				false
			)
		)
		entry["earned_at"] = earned_data.get(
			"earned_at",
			null
		)
		entries.append(entry)

	return entries

func earned_count() -> int:
	var total: int = 0

	for entry in title_entries():
		if bool(entry.get("earned", false)):
			total += 1

	return total

func total_count() -> int:
	if not _load_config():
		return 0

	return config.definitions.size()

func google_play_id_for(title_id: String) -> String:
	if not _load_config():
		return ""

	var definition: Dictionary = config.definitions.get(
		title_id,
		{}
	)
	return str(
		definition.get(
			"google_play_id",
			""
		)
	)

func pending_google_play_bindings() -> Dictionary:
	var result: Dictionary = {}

	for entry in title_entries():
		if not bool(entry.get("earned", false)):
			continue

		var google_play_id: String = str(
			entry.get(
				"google_play_id",
				""
			)
		).strip_edges()

		if google_play_id.is_empty():
			continue

		result[str(entry.get("title_id", ""))] = google_play_id

	return result

func icon_path_for(title_id: String) -> String:
	if not _load_config():
		return ""

	var definition: Dictionary = config.definitions.get(
		title_id,
		{}
	)

	return str(
		definition.get(
			"icon_path",
			""
		)
	)


func gallery_palette_for(earned: bool) -> Dictionary:
	if not _load_config():
		return {}

	if earned:
		return {
			"panel": config.earned_panel_color,
			"border": config.earned_border_color,
			"thumb": config.earned_thumb_color,
			"title": config.earned_title_color,
			"chip_bg": config.earned_chip_bg_color,
			"chip_border": config.earned_chip_border_color,
			"chip_text": config.earned_chip_text_color
		}

	return {
		"panel": config.locked_panel_color,
		"border": config.locked_border_color,
		"thumb": config.locked_thumb_color,
		"title": config.locked_title_color,
		"chip_bg": config.locked_chip_bg_color,
		"chip_border": config.locked_chip_border_color,
		"chip_text": config.locked_chip_text_color
	}


func icon_modulate_for(earned: bool) -> Color:
	if not _load_config():
		return Color.WHITE

	return (
		config.earned_icon_modulate
		if earned
		else config.locked_icon_modulate
	)

func _ensure_profile_state() -> void:
	if not GameState.profile.has("achievements"):
		GameState.profile["achievements"] = {}

func _sorted_definitions() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []

	if not _load_config():
		return entries

	for title_id_value in config.definitions.keys():
		var title_id: String = str(title_id_value)
		var definition_value: Variant = config.definitions.get(
			title_id,
			{}
		)

		if not definition_value is Dictionary:
			continue

		var definition: Dictionary = (
			definition_value as Dictionary
		).duplicate(true)
		definition["title_id"] = title_id
		entries.append(definition)

	entries.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return int(a.get("sort_order", 0)) < int(
				b.get(
					"sort_order",
					0
				)
			)
	)

	return entries

func _rule_met(
	definition: Dictionary,
	level_no: int,
	final_score: int,
	_duration_ms: int,
	achievements: Dictionary
) -> bool:
	var rule_type: String = str(
		definition.get(
			"rule_type",
			""
		)
	)

	match rule_type:
		"level_speed_perfect":
			return _level_speed_perfect(
				definition,
				level_no,
				final_score
			)
		"level_three_star":
			return (
				int(definition.get("level_no", 0)) == level_no
				and ProgressionRules.star_value_for_score(
					final_score
				) >= 3.0
			)
		"level_clean_perfect":
			return _level_clean_perfect(
				definition,
				level_no,
				final_score
			)
		"journey_all_three_star":
			return _journey_all_three_star()
		"collector_current_run":
			return _collector_current_run()
		"journey_no_retry":
			return _journey_no_retry()
		"all_other_titles":
			return _all_other_titles_earned(
				achievements,
				str(definition.get("title_id", ""))
			)
		_:
			return false

func _level_speed_perfect(
	definition: Dictionary,
	level_no: int,
	final_score: int
) -> bool:
	if int(definition.get("level_no", 0)) != level_no:
		return false

	if final_score != 100:
		return false

	var snapshot: Dictionary = _telemetry_level_snapshot(
		level_no
	)
	var games: Dictionary = snapshot.get(
		"games",
		{}
	)

	if games.size() < 2:
		return false

	var max_duration_ms: int = int(
		definition.get(
			"max_game_duration_ms",
			30000
		)
	)

	for game_value in games.values():
		if not game_value is Dictionary:
			return false

		var game: Dictionary = game_value

		if str(game.get("status", "")) != "completed":
			return false

		var duration_ms: int = int(
			game.get(
				"duration_ms",
				0
			)
		)

		if duration_ms <= 0 or duration_ms > max_duration_ms:
			return false

	return true

func _level_clean_perfect(
	definition: Dictionary,
	level_no: int,
	final_score: int
) -> bool:
	if int(definition.get("level_no", 0)) != level_no:
		return false

	if final_score != 100:
		return false

	var snapshot: Dictionary = _telemetry_level_snapshot(
		level_no
	)
	var games: Dictionary = snapshot.get(
		"games",
		{}
	)

	if games.size() < 2:
		return false

	for game_value in games.values():
		if not game_value is Dictionary:
			return false

		var game: Dictionary = game_value

		if str(game.get("status", "")) != "completed":
			return false

		for metric_name in [
			"total_wrong",
			"total_invalid",
			"total_hint",
			"total_reset",
			"total_back_to_map"
		]:
			if int(game.get(metric_name, 0)) > 0:
				return false

	return true

func _journey_all_three_star() -> bool:
	if GameState.active_run.is_empty():
		return false

	var scores: Dictionary = GameState.active_run.get(
		"level_scores",
		{}
	)

	for level_no in range(1, 6):
		if GameState.level_status(level_no) != GameState.STATUS_COMPLETED:
			return false

		if ProgressionRules.star_value_for_score(
			int(scores.get(str(level_no), 0))
		) < 3.0:
			return false

	return true

func _collector_current_run() -> bool:
	if GameState.active_run.is_empty():
		return false

	var fresh_unlocks: Array = GameState.current_gallery_unlocks(true)
	var processed_unlocks: Array = (
		GameState.current_processed_gallery_unlocks(true)
	)
	var all_fresh: Array = ContentDatabase.master.get(
		"foods",
		[]
	)
	var all_processed: Array = ContentDatabase.master.get(
		"processed_foods",
		[]
	)

	return (
		fresh_unlocks.size() >= all_fresh.size()
		and processed_unlocks.size() >= all_processed.size()
		and GameState.active_run_badge_count() >= 5
	)

func _journey_no_retry() -> bool:
	if GameState.active_run.is_empty():
		return false

	for level_no in range(1, 6):
		if GameState.level_status(level_no) != GameState.STATUS_COMPLETED:
			return false

		var snapshot: Dictionary = _telemetry_level_snapshot(
			level_no
		)

		if int(snapshot.get("attempt_no", 0)) != 1:
			return false

		var games: Dictionary = snapshot.get(
			"games",
			{}
		)

		if games.size() < 2:
			return false

		for game_value in games.values():
			if not game_value is Dictionary:
				return false

			var game: Dictionary = game_value

			if int(game.get("total_reset", 0)) > 0:
				return false
			if int(game.get("total_back_to_map", 0)) > 0:
				return false

	return true

func _all_other_titles_earned(
	achievements: Dictionary,
	current_title_id: String
) -> bool:
	if not _load_config():
		return false

	for title_id_value in config.definitions.keys():
		var title_id: String = str(title_id_value)

		if title_id == current_title_id:
			continue

		var value: Dictionary = achievements.get(
			title_id,
			{}
		)

		if not bool(value.get("earned", false)):
			return false

	return true

func _telemetry_level_snapshot(level_no: int) -> Dictionary:
	var current: Dictionary = SaveManager.load_v3_active_current()

	if current.is_empty():
		return {}

	var levels: Dictionary = current.get(
		"levels",
		{}
	)
	var level_value: Variant = levels.get(
		str(level_no),
		{}
	)

	if not level_value is Dictionary:
		return {}

	var level: Dictionary = level_value
	var level_attempt: Dictionary = _resolve_level_attempt(
		level
	)

	if level_attempt.is_empty():
		return {}

	var level_attempt_id: String = str(
		level_attempt.get(
			"level_attempt_id",
			""
		)
	).strip_edges()
	var games_value: Variant = level.get(
		"games",
		{}
	)
	var games: Dictionary = {}

	if games_value is Dictionary:
		games = games_value

	var result_games: Dictionary = {}

	for game_id_value in games.keys():
		var game_id: String = str(game_id_value)
		var game_value: Variant = games.get(
			game_id,
			{}
		)

		if not game_value is Dictionary:
			continue

		var attempt: Dictionary = _resolve_game_attempt(
			game_value,
			level_attempt_id
		)

		if attempt.is_empty():
			continue

		var summary: Dictionary = attempt.get(
			"game_summary",
			{}
		)

		result_games[game_id] = {
			"status": str(attempt.get("status", "")),
			"final_score": int(attempt.get("final_score", 0)),
			"duration_ms": int(attempt.get("duration_ms", 0)),
			"total_wrong": int(summary.get("total_wrong", 0)),
			"total_invalid": int(summary.get("total_invalid", 0)),
			"total_hint": int(summary.get("total_hint", 0)),
			"total_reset": int(summary.get("total_reset", 0)),
			"total_back_to_map": int(
				summary.get(
					"total_back_to_map",
					0
				)
			)
		}

	return {
		"level_no": level_no,
		"level_attempt_id": level_attempt_id,
		"attempt_no": int(
			level_attempt.get(
				"attempt_no",
				0
			)
		),
		"games": result_games
	}

func _resolve_level_attempt(level: Dictionary) -> Dictionary:
	var attempts: Array = level.get(
		"level_attempts",
		[]
	)
	var active_id: String = str(
		level.get(
			"active_level_attempt_id",
			""
		)
	).strip_edges()

	if not active_id.is_empty():
		for value in attempts:
			if value is Dictionary:
				var attempt: Dictionary = value
				if str(
					attempt.get(
						"level_attempt_id",
						""
					)
				) == active_id:
					return attempt

	for index in range(
		attempts.size() - 1,
		-1,
		-1
	):
		var value: Variant = attempts[index]

		if not value is Dictionary:
			continue

		var attempt: Dictionary = value

		if str(attempt.get("status", "")) in [
			"completed",
			"in_progress"
		]:
			return attempt

	return {}

func _resolve_game_attempt(
	game_value: Dictionary,
	level_attempt_id: String
) -> Dictionary:
	var attempts: Array = game_value.get(
		"attempts",
		[]
	)

	for index in range(
		attempts.size() - 1,
		-1,
		-1
	):
		var attempt_value: Variant = attempts[index]

		if not attempt_value is Dictionary:
			continue

		var attempt: Dictionary = attempt_value

		if str(attempt.get("status", "")) != "completed":
			continue

		if not level_attempt_id.is_empty():
			if str(
				attempt.get(
					"level_attempt_id",
					""
				)
			) != level_attempt_id:
				continue

		return attempt

	return {}