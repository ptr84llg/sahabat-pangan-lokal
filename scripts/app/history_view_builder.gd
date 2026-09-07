extends RefCounted

var _open_button: Button = null
var _open_body: Control = null


func populate(host: VBoxContainer) -> void:
	for child in host.get_children():
		host.remove_child(child)
		child.queue_free()

	_open_button = null
	_open_body = null

	var note := Label.new()
	note.text = "Tanda — berarti data tidak tersedia atau mekanisme permainan tidak mencatat data tersebut."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 14)
	note.add_theme_color_override(
		"font_color",
		Color(0.42, 0.42, 0.32, 1)
	)
	host.add_child(note)

	var tree: SceneTree = host.get_tree()
	var root: Window = tree.root
	var save_manager := root.get_node_or_null("SaveManager")
	var game_state := root.get_node_or_null("GameState")
	var progress_manager := root.get_node_or_null("ProgressManager")

	if (
		save_manager == null
		or game_state == null
		or progress_manager == null
	):
		var unavailable := Label.new()
		unavailable.text = "Riwayat belum dapat dibaca karena komponen penyimpanan belum siap."
		unavailable.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		unavailable.add_theme_font_size_override("font_size", 18)
		unavailable.add_theme_color_override(
			"font_color",
			Color(0.48, 0.18, 0.10, 1)
		)
		host.add_child(unavailable)
		return

	var items: Array = _build_items(
		save_manager,
		game_state,
		progress_manager
	)

	if items.is_empty():
		var empty := Label.new()
		empty.text = "Belum ada permainan yang ditamatkan. Riwayat akan muncul setelah Level 1 sampai Level 5 selesai."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.add_theme_font_size_override("font_size", 18)
		empty.add_theme_color_override(
			"font_color",
			Color(0.36, 0.36, 0.28, 1)
		)
		host.add_child(empty)
		return

	var display_no: int = 1

	for item_value in items:
		if not item_value is Dictionary:
			continue

		host.add_child(
			_make_accordion_card(item_value, display_no)
		)
		display_no += 1


func _build_items(
	save_manager: Node,
	game_state: Node,
	_progress_manager: Node
) -> Array:
	var items: Array = []
	var v3_by_source: Dictionary = {}
	var seen_sources: Dictionary = {}
	var records_value: Variant = save_manager.call(
		"load_v3_history_records"
	)

	if records_value is Array:
		for v3_payload_value in records_value:
			if not v3_payload_value is Dictionary:
				continue

			var v3_payload: Dictionary = v3_payload_value
			var v3_history: Dictionary = _as_dictionary(
				v3_payload.get("history", null)
			)
			var v3_source_id: String = str(
				v3_history.get("source_progress_id", "")
			).strip_edges()

			if not v3_source_id.is_empty():
				v3_by_source[v3_source_id] = v3_payload

	var profile_value: Variant = game_state.get("profile")
	var legacy_value: Variant = null

	if profile_value is Dictionary:
		var profile: Dictionary = profile_value
		legacy_value = profile.get(
			"completed_run_history",
			[]
		)

	if legacy_value is Array:
		var legacy_history: Array = legacy_value

		for record_value in legacy_history:
			if not record_value is Dictionary:
				continue

			var record: Dictionary = record_value
			var run_id: String = str(
				record.get("run_id", "")
			).strip_edges()
			var legacy_source_id: String = (
				""
				if run_id.is_empty()
				else "PRG-" + run_id
			)

			if (
				not legacy_source_id.is_empty()
				and v3_by_source.has(legacy_source_id)
			):
				var matched_payload_value: Variant = v3_by_source.get(
					legacy_source_id,
					null
				)

				if matched_payload_value is Dictionary:
					var matched_payload: Dictionary = matched_payload_value
					items.append(_v3_item(matched_payload))
					seen_sources[legacy_source_id] = true
			else:
				items.append(_legacy_item(record))

	for remaining_source_value in v3_by_source.keys():
		var remaining_source_id: String = str(
			remaining_source_value
		)

		if seen_sources.has(remaining_source_id):
			continue

		var remaining_payload_value: Variant = v3_by_source.get(
			remaining_source_id,
			null
		)

		if remaining_payload_value is Dictionary:
			var remaining_payload: Dictionary = remaining_payload_value
			items.append(_v3_item(remaining_payload))

	items.sort_custom(_sort_descending)
	return items


func _sort_descending(
	a: Dictionary,
	b: Dictionary
) -> bool:
	var left: float = _history_completed_at_value(a)
	var right: float = _history_completed_at_value(b)

	if is_equal_approx(left, right):
		return str(a.get("display_id", "")) > str(
			b.get("display_id", "")
		)

	return left > right


func _history_completed_at_value(
	item: Dictionary
) -> float:
	var value: Variant = item.get(
		"completed_at",
		null
	)

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
	var history: Dictionary = _as_dictionary(
		payload.get("history", null)
	)
	var character: Dictionary = _as_dictionary(
		payload.get("character", null)
	)
	var summary: Dictionary = _as_dictionary(
		payload.get("summary", null)
	)
	var migration: Dictionary = _as_dictionary(
		payload.get("migration", null)
	)
	var legacy_snapshot: Dictionary = _as_dictionary(
		migration.get("legacy_snapshot", null)
	)
	var character_label: Variant = legacy_snapshot.get(
		"selected_character_display_name",
		null
	)

	if character_label == null:
		character_label = _character_name(
			character.get("character_id", null)
		)

	return {
		"display_id": history.get("id_history", ""),
		"completed_at": history.get(
			"completed_at_legacy_unix",
			null
		),
		"player_name": character.get("player_name", null),
		"character_name": character_label,
		"total_score": summary.get("total_score", null),
		"total_stars": summary.get("total_stars", null),
		"total_duration_ms": summary.get(
			"total_duration_ms",
			null
		),
		"levels": payload.get("levels", null)
	}


func _legacy_item(record: Dictionary) -> Dictionary:
	return {
		"display_id": record.get("run_id", ""),
		"completed_at": record.get("completed_at", null),
		"player_name": record.get("player_name", null),
		"character_name": record.get(
			"selected_character_display_name",
			null
		),
		"total_score": _sum_dictionary(
			record.get("level_scores", null)
		),
		"total_stars": _sum_dictionary(
			record.get("stars_by_level", null)
		),
		"total_duration_ms": _sum_dictionary(
			record.get("level_durations_ms", null)
		),
		"levels": _legacy_levels(record)
	}


func _legacy_levels(record: Dictionary) -> Dictionary:
	var levels: Dictionary = {}
	var statuses: Variant = record.get("level_status", null)
	var scores: Variant = record.get("level_scores", null)
	var stars: Variant = record.get("stars_by_level", null)
	var durations: Variant = record.get(
		"level_durations_ms",
		null
	)

	for level_no in range(1, 6):
		var key: String = str(level_no)
		levels[key] = {
			"status": _dict_value(statuses, key),
			"games": null,
			"level_summary": {
				"legacy_score": _dict_value(scores, key),
				"legacy_stars": _dict_value(stars, key),
				"legacy_active_duration_ms": _dict_value(
					durations,
					key
				)
			}
		}

	return levels


func _history_header_style(
	background_color: Color,
	border_color: Color
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = border_color
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	style.content_margin_left = 14.0
	style.content_margin_top = 10.0
	style.content_margin_right = 14.0
	style.content_margin_bottom = 10.0
	return style


func _history_body_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.995, 0.97, 0.98)
	style.border_width_left = 3
	style.border_color = Color(0.32, 0.48, 0.24, 0.48)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.content_margin_left = 16.0
	style.content_margin_top = 14.0
	style.content_margin_right = 16.0
	style.content_margin_bottom = 14.0
	return style


func _make_accordion_card(
	item: Dictionary,
	display_no: int
) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.98, 0.97, 0.91, 0.98)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.48, 0.40, 0.24, 0.32)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	var header := Button.new()
	header.toggle_mode = true
	header.flat = false
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.mouse_filter = Control.MOUSE_FILTER_PASS
	header.mouse_force_pass_scroll_events = true
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.custom_minimum_size = Vector2(0, 68)
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override(
		"font_color",
		Color(0.18, 0.31, 0.12, 1)
	)
	header.add_theme_color_override(
		"font_hover_color",
		Color(0.18, 0.31, 0.12, 1)
	)
	header.add_theme_color_override(
		"font_pressed_color",
		Color(0.18, 0.31, 0.12, 1)
	)
	header.add_theme_color_override(
		"font_hover_pressed_color",
		Color(0.18, 0.31, 0.12, 1)
	)
	header.add_theme_color_override(
		"font_focus_color",
		Color(0.18, 0.31, 0.12, 1)
	)
	header.add_theme_stylebox_override(
		"normal",
		_history_header_style(
			Color(0.965, 0.955, 0.89, 1.0),
			Color(0.48, 0.40, 0.24, 0.26)
		)
	)
	header.add_theme_stylebox_override(
		"hover",
		_history_header_style(
			Color(0.93, 0.95, 0.84, 1.0),
			Color(0.32, 0.48, 0.24, 0.48)
		)
	)
	header.add_theme_stylebox_override(
		"pressed",
		_history_header_style(
			Color(0.89, 0.93, 0.79, 1.0),
			Color(0.28, 0.43, 0.20, 0.64)
		)
	)
	header.add_theme_stylebox_override(
		"hover_pressed",
		_history_header_style(
			Color(0.87, 0.92, 0.76, 1.0),
			Color(0.28, 0.43, 0.20, 0.68)
		)
	)
	header.add_theme_stylebox_override(
		"focus",
		_history_header_style(
			Color(0.93, 0.95, 0.84, 0.35),
			Color(0.30, 0.49, 0.21, 0.72)
		)
	)

	var base_text: String = (
		"PERJALANAN %d • %s\n"
		+ "%s • %s • Skor %s • Bintang %s • %s"
	) % [
		display_no,
		_datetime(item.get("completed_at", null)),
		_display(item.get("player_name", null)),
		_display(item.get("character_name", null)),
		_display(item.get("total_score", null)),
		_display(item.get("total_stars", null)),
		_duration(item.get("total_duration_ms", null))
	]

	header.set_meta("history_header_base", base_text)
	header.text = "▶ " + base_text
	column.add_child(header)

	var body := RichTextLabel.new()
	body.bbcode_enabled = true
	body.fit_content = true
	body.visible = false
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_color_override(
		"default_color",
		Color(0.20, 0.22, 0.17, 1.0)
	)
	body.add_theme_font_size_override(
		"normal_font_size",
		16
	)
	body.add_theme_font_size_override(
		"bold_font_size",
		16
	)
	body.add_theme_constant_override(
		"line_separation",
		4
	)
	body.add_theme_constant_override(
		"paragraph_separation",
		5
	)
	body.add_theme_stylebox_override(
		"normal",
		_history_body_style()
	)
	body.text = _detail_bbcode(item)
	column.add_child(body)

	header.toggled.connect(
		_on_toggled.bind(body, header)
	)

	return panel


func _on_toggled(
	opened: bool,
	body: Control,
	header: Button
) -> void:
	if opened:
		if (
			_open_button != null
			and _open_button != header
			and is_instance_valid(_open_button)
		):
			_open_button.set_pressed_no_signal(false)

		if (
			_open_body != null
			and _open_body != body
			and is_instance_valid(_open_body)
		):
			_open_body.visible = false

		_open_button = header
		_open_body = body
		body.visible = true
	else:
		body.visible = false

		if _open_button == header:
			_open_button = null
			_open_body = null

	var base_text: String = str(
		header.get_meta("history_header_base", "")
	)
	header.text = (
		"▼ " + base_text
		if opened
		else "▶ " + base_text
	)


func _detail_bbcode(item: Dictionary) -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append(
		"[color=#315F23][b]RINGKASAN PERJALANAN[/b][/color]"
	)
	lines.append(
		"[b]Pemain:[/b] %s    [b]Karakter:[/b] %s" % [
			_display(item.get("player_name", null)),
			_display(item.get("character_name", null))
		]
	)
	lines.append(
		"[b]Total skor:[/b] %s    [b]Total bintang:[/b] %s    [b]Durasi:[/b] %s" % [
			_display(item.get("total_score", null)),
			_display(item.get("total_stars", null)),
			_duration(item.get("total_duration_ms", null))
		]
	)
	lines.append("")

	var levels_value: Variant = item.get("levels", null)

	if not levels_value is Dictionary:
		lines.append("Detail level dan permainan: —")
		return "\n".join(lines)

	var levels: Dictionary = levels_value

	for level_no in range(1, 6):
		var level: Dictionary = _as_dictionary(
			levels.get(str(level_no), null)
		)
		_append_level(lines, level, level_no)

	return "\n".join(lines)


func _append_level(
	lines: PackedStringArray,
	level: Dictionary,
	level_no: int
) -> void:
	var summary: Dictionary = _as_dictionary(
		level.get("level_summary", null)
	)
	var games_value: Variant = level.get("games", null)

	lines.append(
		"[color=#315F23][b]LEVEL %d[/b][/color]" % level_no
	)
	lines.append(
		"Status: %s    Skor: %s    Bintang: %s    Durasi: %s" % [
			_display(level.get("status", null)),
			_display(
				summary.get(
					"legacy_score",
					summary.get("score", null)
				)
			),
			_display(
				summary.get(
					"legacy_stars",
					summary.get("stars", null)
				)
			),
			_duration(
				summary.get(
					"legacy_active_duration_ms",
					summary.get(
						"active_duration_ms",
						null
					)
				)
			)
		]
	)
	lines.append(
		"Kesalahan: %s    Petunjuk: %s    Reset: %s    Kembali: %s" % [
			_metric_text(
				_metric_total(
					games_value,
					[
						"wrong_target_drop_count",
						"wrong_answer_count"
					]
				)
			),
			_metric_text(
				_metric_total(
					games_value,
					["hint_click_count"]
				)
			),
			_metric_text(
				_metric_total(
					games_value,
					["in_game_reset_click_count"]
				)
			),
			_metric_text(
				_metric_total(
					games_value,
					["back_to_map_click_count"]
				)
			)
		]
	)

	if not games_value is Dictionary:
		lines.append("Detail permainan: —")
		lines.append("")
		return

	var games: Dictionary = games_value
	var game_ids: Array = games.keys()
	game_ids.sort()

	if game_ids.is_empty():
		lines.append("Detail permainan: —")
		lines.append("")
		return

	for game_id_value in game_ids:
		var game_value: Variant = games.get(
			game_id_value,
			null
		)

		if game_value is Dictionary:
			_append_game(
				lines,
				game_value,
				str(game_id_value)
			)

	lines.append("")


func _append_game(
	lines: PackedStringArray,
	game: Dictionary,
	fallback_id: String
) -> void:
	var game_id: String = str(
		game.get("game_id", fallback_id)
	).strip_edges()
	var game_type: String = str(
		game.get("game_type", "")
	).strip_edges()
	var score: Dictionary = _as_dictionary(
		game.get("score", null)
	)
	var metrics: Dictionary = _as_dictionary(
		game.get("interaction_metrics", null)
	)

	lines.append(
		"[color=#596B49][b]%s • %s[/b][/color]" % [
			game_id if not game_id.is_empty() else "GAME",
			_game_type(game_type)
		]
	)
	lines.append(
		"Status: %s    Skor: %s    Durasi: %s    Percobaan: %s" % [
			_display(game.get("status", null)),
			_display(
				score.get(
					"final_score",
					score.get("current_score", null)
				)
			),
			_duration(game.get("total_duration_ms", null)),
			_display(game.get("attempt_count", null))
		]
	)
	lines.append(
		"Kesalahan: %s    Drop tidak valid: %s    Petunjuk: %s    Reset: %s    Kembali: %s" % [
			_metric_text(_game_mistakes(metrics)),
			_display(
				_metric_value(
					metrics,
					"invalid_drop_count"
				)
			),
			_display(
				_metric_value(
					metrics,
					"hint_click_count"
				)
			),
			_display(
				_metric_value(
					metrics,
					"in_game_reset_click_count"
				)
			),
			_display(
				_metric_value(
					metrics,
					"back_to_map_click_count"
				)
			)
		]
	)

	_append_units(
		lines,
		game.get("rounds_or_sections", null)
	)
	_append_questions(
		lines,
		game.get("questions", null)
	)


func _append_units(
	lines: PackedStringArray,
	units_value: Variant
) -> void:
	if not units_value is Array:
		lines.append("Ronde / bagian / fase: —")
		return

	var units: Array = units_value

	if units.is_empty():
		lines.append("Ronde / bagian / fase: —")
		return

	for unit_value in units:
		if not unit_value is Dictionary:
			continue

		var unit: Dictionary = unit_value
		lines.append(
			"  ↳ %s    Status: %s    Skor: %s    Durasi: %s" % [
				_unit_id(unit),
				_display(unit.get("status", null)),
				_display(unit.get("score", null)),
				_duration(
					unit.get("active_duration_ms", null)
				)
			]
		)


func _append_questions(
	lines: PackedStringArray,
	questions_value: Variant
) -> void:
	if not questions_value is Array:
		lines.append("Soal: —")
		return

	var questions: Array = questions_value

	if questions.is_empty():
		lines.append("Soal: —")
		return

	for question_value in questions:
		if not question_value is Dictionary:
			continue

		var question: Dictionary = question_value
		lines.append(
			"  ↳ %s    Hasil: %s    Jawaban: %s    Benar: %s    Respons: %s    Hint: %s    Timeout: %s" % [
				_display(question.get("question_id", null)),
				_display(question.get("result", null)),
				_display(
					question.get(
						"selected_answer_id",
						null
					)
				),
				_display(
					question.get(
						"correct_answer_id",
						null
					)
				),
				_response_ms(
					question.get(
						"response_time_ms",
						null
					)
				),
				_display(question.get("hint_used", null)),
				_display(question.get("timeout", null))
			]
		)


func _metric_total(
	games_value: Variant,
	keys: Array
) -> Dictionary:
	var result: Dictionary = {
		"value": null,
		"partial": false
	}

	if not games_value is Dictionary:
		return result

	var games: Dictionary = games_value
	var total: int = 0
	var any_available: bool = false
	var partial: bool = false

	for game_value in games.values():
		if not game_value is Dictionary:
			partial = true
			continue

		var game: Dictionary = game_value
		var metrics_value: Variant = game.get(
			"interaction_metrics",
			null
		)

		if not metrics_value is Dictionary:
			partial = true
			continue

		var metrics: Dictionary = metrics_value
		var game_available: bool = false

		for key_value in keys:
			var value: Variant = metrics.get(
				str(key_value),
				null
			)

			if value == null:
				partial = true
				continue

			total += int(value)
			any_available = true
			game_available = true

		if not game_available:
			partial = true

	if any_available:
		result["value"] = total
		result["partial"] = partial

	return result


func _metric_text(result: Dictionary) -> String:
	var value: Variant = result.get("value", null)

	if value == null:
		return "—"

	var text_value: String = str(int(value))

	if bool(result.get("partial", false)):
		return text_value + " (parsial)"

	return text_value


func _game_mistakes(metrics: Dictionary) -> Dictionary:
	var result: Dictionary = {
		"value": null,
		"partial": false
	}

	if metrics.is_empty():
		return result

	var total: int = 0
	var found: bool = false
	var partial: bool = false

	for key in [
		"wrong_target_drop_count",
		"wrong_answer_count"
	]:
		var value: Variant = metrics.get(key, null)

		if value == null:
			partial = true
			continue

		total += int(value)
		found = true

	if found:
		result["value"] = total
		result["partial"] = partial

	return result


func _metric_value(
	metrics: Dictionary,
	key: String
) -> Variant:
	if metrics.is_empty() or not metrics.has(key):
		return null

	return metrics.get(key, null)


func _unit_id(unit: Dictionary) -> String:
	for key in ["round_id", "section_id", "phase_id"]:
		var text_value: String = str(
			unit.get(key, "")
		).strip_edges()

		if not text_value.is_empty():
			return text_value

	return "—"


func _game_type(value: String) -> String:
	match value:
		"matching_drag_drop":
			return "Cocokkan Pangan"
		"literacy_question":
			return "Pertanyaan Literasi"
		"classification_drag_drop":
			return "Klasifikasi Pangan"
		"complete_group":
			return "Lengkapi Kelompok"
		"selective_shopping":
			return "Belanja Selektif"
		"complete_shopping":
			return "Lengkapi Belanja"
		"two_ingredient_process":
			return "Olahan Dua Bahan"
		"complete_processing_chain":
			return "Lengkapi Proses"
		"festival_composite":
			return "Festival Pangan"
		"literacy_quiz":
			return "Kuis Literasi"
		_:
			return value if not value.is_empty() else "Permainan"


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
			if not key.is_empty():
				return key
			return null


func _display(value: Variant) -> String:
	if value == null:
		return "—"

	if value is bool:
		return "Ya" if bool(value) else "Tidak"

	var text_value: String = str(value).strip_edges()
	return text_value if not text_value.is_empty() else "—"


func _duration(value: Variant) -> String:
	if value == null:
		return "—"

	var total_seconds: int = maxi(
		0,
		int(int(value) / 1000.0)
	)
	var hours: int = int(total_seconds / 3600.0)
	var minutes: int = int(
		(total_seconds % 3600) / 60.0
	)
	var seconds: int = total_seconds % 60

	if hours > 0:
		return "%02d:%02d:%02d" % [
			hours,
			minutes,
			seconds
		]

	return "%02d:%02d" % [minutes, seconds]


func _response_ms(value: Variant) -> String:
	if value == null:
		return "—"

	return "%d ms" % maxi(0, int(value))


func _datetime(value: Variant) -> String:
	if value == null:
		return "Waktu belum tersedia"

	var unix_time: int = int(float(value))

	if unix_time <= 0:
		return "Waktu belum tersedia"

	return Time.get_datetime_string_from_unix_time(
		unix_time,
		true
	)


func _dict_value(
	source_value: Variant,
	key: String
) -> Variant:
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

	if found:
		return total
	return null


func _as_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value

	return {}