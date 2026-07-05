extends Node
class_name PlayerScore

signal score_changed(new_score: int)
signal achievements_changed

@export var score_sfx: AudioStream = preload("res://Music/freesound_community-short-success-sound-glockenspiel-treasure-video-game-6346.mp3")
@export var score_label_path: NodePath = NodePath("../PlayerUI/ScoreUI/VBoxContainer/ScoreAmount")

var score := 0
var achievements: Array[Dictionary] = []

@onready var score_label := get_node_or_null(score_label_path) as RichTextLabel

var _syncing_remote_state := false


func _ready() -> void:
	set_score(0)


func add_score(points: int) -> bool:
	if points <= 0:
		return false

	if not _can_update_local_score():
		return false

	set_score(score + points)
	if score_sfx != null:
		AudioUtility.play_sfx(self, score_sfx)
	return true


func record_achievement(achievement_name: String, points: int) -> void:
	if achievement_name.strip_edges().is_empty():
		return

	achievements.append({
		"name": achievement_name,
		"points": points,
	})
	achievements_changed.emit()
	_sync_achievements_to_peers()


func get_achievement_summary() -> String:
	if achievements.is_empty():
		return "No achievements"

	var achievement_names: Array[String] = []
	for achievement in achievements:
		achievement_names.append(String(achievement.get("name", "")))

	return ", ".join(achievement_names)


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
	score_changed.emit(score)
	_sync_score_to_peers()


func _sync_score_to_peers() -> void:
	if _syncing_remote_state or not _can_update_local_score():
		return
	if multiplayer.multiplayer_peer == null:
		return

	_sync_score.rpc(score)


func _sync_achievements_to_peers() -> void:
	if _syncing_remote_state or not _can_update_local_score():
		return
	if multiplayer.multiplayer_peer == null:
		return

	_sync_achievements.rpc(achievements)


@rpc("authority", "call_remote", "reliable")
func _sync_score(remote_score: int) -> void:
	_syncing_remote_state = true
	score = max(remote_score, 0)
	_update_score_label()
	score_changed.emit(score)
	_syncing_remote_state = false


@rpc("authority", "call_remote", "reliable")
func _sync_achievements(remote_achievements: Array) -> void:
	_syncing_remote_state = true
	achievements.clear()
	for achievement in remote_achievements:
		if typeof(achievement) == TYPE_DICTIONARY:
			achievements.append(achievement)
	achievements_changed.emit()
	_syncing_remote_state = false


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
