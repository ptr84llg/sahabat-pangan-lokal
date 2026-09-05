class_name FestivalQuizController
extends Node

var config: Dictionary = {}
var question_order: Array = []
var current_index := -1
var current_question: Dictionary = {}
var current_answer_order: Array = []
var responses: Array = []
var score := 0

func configure(quiz_config: Dictionary) -> void:
    config = quiz_config.duplicate(true)

func begin() -> void:
    question_order = config.get("questions", []).duplicate(true)
    if bool(config.get("shuffle_questions", true)):
        question_order.shuffle()
    current_index = -1
    current_question = {}
    current_answer_order.clear()
    responses.clear()
    score = 0

func advance_question() -> Dictionary:
    current_index += 1
    if current_index >= question_order.size():
        current_question = {}
        return {}
    current_question = question_order[current_index].duplicate(true)
    current_answer_order = current_question.get("answers", []).duplicate(true)
    if bool(config.get("shuffle_answers", true)):
        current_answer_order.shuffle()
    return {"question":current_question.duplicate(true),"answers":current_answer_order.duplicate(true),"index":current_index}

func submit(answer_id: String, response_time_ms: int) -> Dictionary:
    if current_question.is_empty():
        return {}
    var correct_id := str(current_question.get("correct_answer_id", ""))
    var correct := answer_id == correct_id
    var status := "CORRECT" if correct else "WRONG"
    var gained := int(config.get("score_correct", 8)) if correct else int(config.get("score_wrong", 0))
    score += gained
    var response := _response_base(status, response_time_ms)
    response["selected_answer_id"] = answer_id
    response["score_awarded"] = gained
    responses.append(response)
    return {"status":status,"correct":correct,"score_awarded":gained,"correct_answer_id":correct_id,"response":response}

func submit_timeout(response_time_ms: int) -> Dictionary:
    if current_question.is_empty():
        return {}
    var response := _response_base("TIMEOUT", response_time_ms)
    response["selected_answer_id"] = ""
    response["score_awarded"] = int(config.get("score_timeout", 0))
    score += int(response["score_awarded"] )
    responses.append(response)
    return {"status":"TIMEOUT","correct":false,"score_awarded":int(response["score_awarded"]),"correct_answer_id":str(current_question.get("correct_answer_id", "")),"response":response}

func has_more() -> bool:
    return current_index + 1 < question_order.size()

func question_count() -> int:
    return question_order.size()

func current_correct_text() -> String:
    var correct_id := str(current_question.get("correct_answer_id", ""))
    for a in current_question.get("answers", []):
        if str(a.get("answer_id", "")) == correct_id:
            return str(a.get("text", correct_id))
    return correct_id

func snapshot() -> Dictionary:
    var qids: Array = []
    for q in question_order:
        qids.append(str(q.get("question_id", "")))
    return {"question_order":qids,"responses":responses.duplicate(true),"quiz_score":score}

func _response_base(status: String, response_time_ms: int) -> Dictionary:
    var answer_ids: Array = []
    for a in current_answer_order:
        answer_ids.append(str(a.get("answer_id", "")))
    return {"question_id":str(current_question.get("question_id", "")),"question_order_index":current_index,"answer_order_ids":answer_ids,"question_status":status,"question_response_time_ms":response_time_ms}
