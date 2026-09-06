class_name FestivalSchemaController
extends Node

var schemas: Array = []
var invalid_counts: Dictionary = {}
var invalid_events: Array = []
var completed: Dictionary = {}

func configure(schema_data: Array) -> void:
    schemas = schema_data.duplicate(true)
    reset()

func reset() -> void:
    invalid_counts.clear()
    invalid_events.clear()
    completed.clear()
    for s in schemas:
        var sid := str(s.get("schema_id", ""))
        invalid_counts[sid] = 0
        completed[sid] = false

func register_invalid(schema_id: String, event_type: String, payload: Dictionary = {}) -> int:
    invalid_counts[schema_id] = int(invalid_counts.get(schema_id, 0)) + 1
    var event := payload.duplicate(true)
    event["schema_id"] = schema_id
    event["event_type"] = event_type
    event["invalid_index"] = int(invalid_counts[schema_id])
    invalid_events.append(event)
    return schema_score(schema_id)

func complete_schema(schema_id: String) -> int:
    completed[schema_id] = true
    return schema_score(schema_id)

func schema_score(schema_id: String) -> int:
    var data := _get_schema(schema_id)
    if data.is_empty():
        return 0
    var max_score := int(data.get("max_score", 0))
    var floor_score := int(data.get("floor_score", 0))
    var penalty := int(data.get("invalid_penalty", 1))
    return max(floor_score, max_score - int(invalid_counts.get(schema_id, 0)) * penalty)

func total_accuracy_score() -> int:
    var total := 0
    for s in schemas:
        total += schema_score(str(s.get("schema_id", "")))
    return total

func snapshot() -> Dictionary:
    var scores := {}
    for s in schemas:
        var sid := str(s.get("schema_id", ""))
        scores[sid] = schema_score(sid)
    return {"scores":scores,"invalid_counts":invalid_counts.duplicate(true),"invalid_events":invalid_events.duplicate(true),"completed":completed.duplicate(true)}

func _get_schema(schema_id: String) -> Dictionary:
    for s in schemas:
        if str(s.get("schema_id", "")) == schema_id:
            return s
    return {}
