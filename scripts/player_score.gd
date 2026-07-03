extends Node
class_name PlayerScore

@export var score_label_path: NodePath = NodePath("../PlayerUI/ScoreUI/VBoxContainer/ScoreAmount")

var score := 0

@onready var score_label := get_node_or_null(score_label_path) as RichTextLabel


func _ready() -> void:
	set_score(0)


func add_score(points: int) -> void:
	if points <= 0:
		return

	if not _can_update_local_score():
		return

	set_score(score + points)


func can_afford(cost: int) -> bool:
	return score >= cost


func spend_score(cost: int) -> bool:
	if cost <= 0:
		return true

	if not _can_update_local_score():
		return false

	if not can_afford(cost):
		return false

	set_score(score - cost)
	return true


func set_score(value: int) -> void:
	score = max(value, 0)
	_update_score_label()


func _update_score_label() -> void:
	if score_label == null:
		return

	score_label.text = str(score)


func _can_update_local_score() -> bool:
	var player := get_parent()
	if player == null:
		return true

	if player.has_method("is_multiplayer_authority"):
		return multiplayer.multiplayer_peer == null or player.is_multiplayer_authority()

	return true
