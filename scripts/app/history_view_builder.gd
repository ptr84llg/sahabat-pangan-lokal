extends RefCounted

const HISTORY_RUN_CARD_SCENE: PackedScene = preload(
	"res://scenes/app/history/history_run_card.tscn"
)

var _open_card: Control = null


func populate(host: VBoxContainer) -> void:
	var note: Label = host.get_node_or_null("HistoryIntroNote") as Label
	var state_label: Label = host.get_node_or_null("HistoryStateLabel") as Label
	var cards_host: VBoxContainer = host.get_node_or_null("HistoryCardsHost") as VBoxContainer

	if note == null or state_label == null or cards_host == null:
		push_error("HistoryViewBuilder: struktur HistoryModal scene-authored tidak lengkap.")
		return

	for child in cards_host.get_children():
		cards_host.remove_child(child)
		child.queue_free()

	_open_card = null
	note.visible = true
	state_label.visible = false

	var tree: SceneTree = host.get_tree()
	var root: Window = tree.root
	var save_manager := root.get_node_or_null("SaveManager")
	var game_state := root.get_node_or_null("GameState")
	var progress_manager := root.get_node_or_null("ProgressManager")

	if save_manager == null or game_state == null or progress_manager == null:
		state_label.text = "Riwayat belum dapat dibaca karena komponen penyimpanan belum siap."
		state_label.visible = true
		return

	var items: Array = _build_items(save_manager, game_state, progress_manager)

	if items.is_empty():
		state_label.text = "Belum ada perjalanan yang selesai. Riwayat akan muncul setelah Level 1 sampai Level 5 selesai."
		state_label.visible = true
		return

	var total_journey: int = items.size()

	for index in range(total_journey):
		var item_value: Variant = items[index]

		if not item_value is Dictionary:
			continue

		var card: Control = HISTORY_RUN_CARD_SCENE.instantiate() as Control

		if card == null:
			push_error("HistoryViewBuilder: history_run_card.tscn gagal dibuat.")
			continue

		var journey_number: int = total_journey - index
		cards_host.add_child(card)
		card.call("configure", _history_display_data(item_value, journey_number))

		if card.has_signal("accordion_toggled"):
			card.connect("accordion_toggled", Callable(self, "_on_card_toggled"))


func _build_items(
	save_manager: Node,
	game_state: Node,
	_progress_manager: Node
) -> Array:
	var items: Array = []
	var v3_by_source: Dictionary = {}
	var seen_sources: Dictionary = {}
	var records_value: Variant = save_manager.call("load_v3_history_records")

	if records_value is Array:
		for v3_payload_value in records_value:
			if not v3_payload_value is Dictionary:
				continue

			var v3_payload: Dictionary = v3_payload_value
			var v3_history: Dictionary = _as_dictionary(v3_payload.get("history", null))
			var v3_source_id: String = str(v3_history.get("source_progress_id", "")).strip_edges()

			if not v3_source_id.is_empty():
				v3_by_source[v3_source_id] = v3_payload

	var profile_value: Variant = game_state.get("profile")
	var legacy_value: Variant = null

	if profile_value is Dictionary:
		var profile: Dictionary = profile_value
		legacy_value = profile.get("completed_run_history", [])

	if legacy_value is Array:
		var legacy_history: Array = legacy_value

		for record_value in legacy_history:
			if not record_value is Dictionary:
				continue

			var record: Dictionary = record_value
			var run_id: String = str(record.get("run_id", "")).strip_edges()
			var legacy_source_id: String = "" if run_id.is_empty() else "PRG-" + run_id

			if not legacy_source_id.is_empty() and v3_by_source.has(legacy_source_id):
				var matched_payload_value: Variant = v3_by_source.get(legacy_source_id, null)

				if matched_payload_value is Dictionary:
					var matched_payload: Dictionary = matched_payload_value
					items.append(_v3_item(matched_payload))
					seen_sources[legacy_source_id] = true
			else:
				items.append(_legacy_item(record))

	for remaining_source_value in v3_by_source.keys():
		var remaining_source_id: String = str(remaining_source_value)

		if seen_sources.has(remaining_source_id):
			continue

		var remaining_payload_value: Variant = v3_by_source.get(remaining_source_id, null)

		if remaining_payload_value is Dictionary:
			var remaining_payload: Dictionary = remaining_payload_value
			items.append(_v3_item(remaining_payload))

	items.sort_custom(_sort_descending)
	return items


func _sort_descending(a: Dictionary, b: Dictionary) -> bool:
	var left: float = _history_completed_at_value(a)
	var right: float = _history_completed_at_value(b)

	if is_equal_approx(left, right):
		return str(a.get("display_id", "")) > str(b.get("display_id", ""))

	return left > right


func _history_completed_at_value(item: Dictionary) -> float:
	var value: Variant = item.get("completed_at", null)

	if value == null:
		return 0.0

	if value is float:
		return value

	if value is int:
		return value * 1.0

	if value is String:
		var text_value: String = str(value).strip_edges()

		if text_value.is_valid_float():
			return text_value.to_float()

	return 0.0


func _v3_item(payload: Dictionary) -> Dictionary:
	var history: Dictionary = _as_dictionary(payload.get("history", null))
	var character: Dictionary = _as_dictionary(payload.get("character", null))
	var summary: Dictionary = _as_dictionary(payload.get("summary", null))
	var migration: Dictionary = _as_dictionary(payload.get("migration", null))
	var legacy_snapshot: Dictionary = _as_dictionary(migration.get("legacy_snapshot", null))
	var character_label: Variant = legacy_snapshot.get("selected_character_display_name", null)

	if character_label == null:
		character_label = _character_name(character.get("character_id", null))

	return {
		"display_id": history.get("id_history", ""),
		"completed_at": history.get("completed_at_unix", null),
		"player_name": character.get("player_name", null),
		"character_name": character_label,
		"total_score": summary.get("total_score", null),
		"total_stars": summary.get("total_stars", null),
		"total_duration_ms": summary.get("total_duration_ms", null),
		"levels": payload.get("levels", null)
	}


func _legacy_item(record: Dictionary) -> Dictionary:
	return {
		"display_id": record.get("run_id", ""),
		"completed_at": record.get("completed_at", null),
		"player_name": record.get("player_name", null),
		"character_name": record.get("selected_character_display_name", null),
		"total_score": _sum_dictionary(record.get("level_scores", null)),
		"total_stars": _sum_dictionary(record.get("stars_by_level", null)),
		"total_duration_ms": _sum_dictionary(record.get("level_durations_ms", null)),
		"levels": _legacy_levels(record)
	}


func _legacy_levels(record: Dictionary) -> Dictionary:
	var levels: Dictionary = {}
	var statuses: Variant = record.get("level_status", null)
	var scores: Variant = record.get("level_scores", null)
	var stars: Variant = record.get("stars_by_level", null)
	var durations: Variant = record.get("level_durations_ms", null)

	for level_no in range(1, 6):
		var key: String = str(level_no)
		levels[key] = {
			"status": _dict_value(statuses, key),
			"games": null,
			"level_summary": {
				"legacy_score": _dict_value(scores, key),
				"legacy_stars": _dict_value(stars, key),
				"legacy_active_duration_ms": _dict_value(durations, key)
			}
		}

	return levels


func _history_display_data(item: Dictionary, display_no: int) -> Dictionary:
	var level_rows: Array = []
	var levels: Dictionary = _as_dictionary(item.get("levels", null))

	for level_no in range(1, 6):
		var level: Dictionary = _as_dictionary(levels.get(str(level_no), null))
		var summary: Dictionary = _as_dictionary(level.get("level_summary", null))

		level_rows.append({
			"level_no": level_no,
			"score": _display(summary.get("legacy_score", summary.get("score", null))),
			"stars": _display(summary.get("legacy_stars", summary.get("stars", null))),
			"duration": _duration(
				summary.get(
					"legacy_active_duration_ms",
					summary.get("total_duration_ms", null)
				)
			)
		})

	return {
		"journey": "PERJALANAN %d" % display_no,
		"completed_at": _date_text(item.get("completed_at", null)),
		"character": _display(item.get("character_name", null)),
		"total_score": _display(item.get("total_score", null)),
		"total_stars": _display(item.get("total_stars", null)),
		"total_duration": _duration(item.get("total_duration_ms", null)),
		"levels": level_rows
	}


func _on_card_toggled(card: Control, opened: bool) -> void:
	if opened:
		if _open_card != null and _open_card != card and is_instance_valid(_open_card):
			_open_card.call("set_opened", false)

		_open_card = card
		return

	if _open_card == card:
		_open_card = null


func _character_name(value: Variant) -> Variant:
	if value == null:
		return null

	var key: String = str(value).strip_edges().to_lower()

	match key:
		"rara":
			return "Rara"
		"budi":
			return "Budi"
		"anjani":
			return "Anjani"
		"riski":
			return "Riski"
		_:
			return key.capitalize() if not key.is_empty() else null


func _display(value: Variant) -> String:
	if value == null:
		return "-"

	if value is bool:
		return "Ya" if bool(value) else "Tidak"

	var text_value: String = str(value).strip_edges()
	return text_value if not text_value.is_empty() else "-"


func _duration(value: Variant) -> String:
	if value == null:
		return "-"

	var total_seconds: int = maxi(0, int(int(value) / 1000.0))
	var hours: int = int(total_seconds / 3600.0)
	var minutes: int = int((total_seconds % 3600) / 60.0)
	var seconds: int = total_seconds % 60

	if hours > 0:
		return "%02d:%02d:%02d" % [hours, minutes, seconds]

	return "%02d:%02d" % [minutes, seconds]


func _date_text(value: Variant) -> String:
	if value == null:
		return "Tanggal belum tersedia"

	var unix_time: int = int(float(value))

	if unix_time <= 0:
		return "Tanggal belum tersedia"

	var time_zone: Dictionary = Time.get_time_zone_from_system()
	var bias_minutes: int = int(time_zone.get("bias", 0))
	var local_unix_time: int = unix_time + (bias_minutes * 60)
	var date_time: Dictionary = Time.get_datetime_dict_from_unix_time(local_unix_time)
	var month_no: int = int(date_time.get("month", 0))
	var month_names: PackedStringArray = [
		"Jan", "Feb", "Mar", "Apr", "Mei", "Jun",
		"Jul", "Agu", "Sep", "Okt", "Nov", "Des"
	]

	if month_no < 1 or month_no > month_names.size():
		var fallback_text: String = Time.get_datetime_string_from_unix_time(
			local_unix_time,
			true
		)
		return fallback_text.substr(0, mini(16, fallback_text.length()))

	return "%02d %s %04d  |  %02d:%02d" % [
		int(date_time.get("day", 0)),
		month_names[month_no - 1],
		int(date_time.get("year", 0)),
		int(date_time.get("hour", 0)),
		int(date_time.get("minute", 0))
	]


func _dict_value(source_value: Variant, key: String) -> Variant:
	if not source_value is Dictionary:
		return null

	var source: Dictionary = source_value

	if not source.has(key):
		return null

	return source.get(key, null)


func _sum_dictionary(source_value: Variant) -> Variant:
	if not source_value is Dictionary:
		return null

	var source: Dictionary = source_value
	var total: int = 0
	var found: bool = false

	for value in source.values():
		if value != null:
			total += int(value)
			found = true

	return total if found else null


func _as_dictionary(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}
