class_name ProgressionRules
extends RefCounted

const CONFIG_PATH: String = "res://resources/config/progression_config.tres"

static func _config() -> ProgressionConfig:
	var resource := load(CONFIG_PATH)

	if resource is ProgressionConfig:
		return resource as ProgressionConfig

	push_error("ProgressionConfig tidak dapat dimuat.")
	return null

static func star_value_for_score(score: int) -> float:
	var config := _config()

	if config == null:
		return 0.0

	var safe_score: int = clampi(score, 0, 100)

	if safe_score >= config.three_star_score:
		return 3.0
	if safe_score >= config.two_half_star_score:
		return 2.5
	if safe_score >= config.two_star_score:
		return 2.0
	if safe_score >= config.one_half_star_score:
		return 1.5
	if safe_score >= config.one_star_score:
		return 1.0
	if safe_score >= config.half_star_min_score:
		return 0.5

	return 0.0

static func star_slots_for_value(star_value: float) -> Array[String]:
	var slots: Array[String] = []
	var remainder: float = clampf(star_value, 0.0, 3.0)

	for _index in range(3):
		if remainder >= 1.0:
			slots.append("full")
			remainder -= 1.0
		elif remainder >= 0.5:
			slots.append("half")
			remainder -= 0.5
		else:
			slots.append("empty")

	return slots