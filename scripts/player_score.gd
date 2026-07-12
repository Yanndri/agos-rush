extends Node
class_name PlayerScore

signal score_changed(new_score: int)
signal stars_changed(new_stars: int)
signal achievements_changed

@export var score_sfx: AudioStream = preload("res://Music/freesound_community-short-success-sound-glockenspiel-treasure-video-game-6346.mp3")
@export var score_label_path: NodePath = NodePath("../PlayerUI/ScoreUI/VBoxContainer/ScoreAmount")
@export var stars_label_path: NodePath = NodePath("../PlayerUI/StarsUI/VBoxContainer/StarsHbox/StarsAmount")
@export var score_effect_path: NodePath = NodePath("../PlayerUI/ScoreUI/VBoxContainer/ScoreAmount")
@export var stars_effect_path: NodePath = NodePath("../PlayerUI/StarsUI/VBoxContainer/StarsHbox")
@export var value_pop_scale := Vector2(1.25, 1.25)
@export var value_pop_out_time := 0.1
@export var value_pop_in_time := 0.16

var score := 0
var stars := 0
var achievements: Array[Dictionary] = []

@onready var score_label := get_node_or_null(score_label_path) as RichTextLabel
@onready var stars_label := get_node_or_null(stars_label_path) as Label
@onready var score_effect_control := get_node_or_null(score_effect_path) as Control
@onready var stars_effect_control := get_node_or_null(stars_effect_path) as Control

var _syncing_remote_state := false
var score_effect_tween: Tween
var stars_effect_tween: Tween


func _ready() -> void:
	set_score(0)
	set_stars(0)


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


func add_stars(amount: int) -> bool:
	if amount <= 0:
		return false

	if not _can_update_local_score():
		return false

	set_stars(stars + amount)
	return true


func can_afford_stars(cost: int) -> bool:
	return stars >= cost


func spend_stars(cost: int) -> bool:
	if cost <= 0:
		return true

	if not _can_update_local_score():
		return false

	if not can_afford_stars(cost):
		return false

	set_stars(stars - cost)
	return true


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
	var previous_score := score
	score = max(value, 0)
	_update_score_label()
	if score != previous_score:
		_play_score_effect()
	score_changed.emit(score)
	_sync_score_to_peers()


func set_stars(value: int) -> void:
	var previous_stars := stars
	stars = max(value, 0)
	_update_stars_label()
	if stars != previous_stars:
		_play_stars_effect()
		_play_score_sfx()
	stars_changed.emit(stars)
	_sync_stars_to_peers()


func _sync_score_to_peers() -> void:
	if _syncing_remote_state or not _can_update_local_score():
		return
	if multiplayer.multiplayer_peer == null:
		return

	_sync_score.rpc(score)


func _sync_stars_to_peers() -> void:
	if _syncing_remote_state or not _can_update_local_score():
		return
	if multiplayer.multiplayer_peer == null:
		return

	_sync_stars.rpc(stars)


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
func _sync_stars(remote_stars: int) -> void:
	_syncing_remote_state = true
	stars = max(remote_stars, 0)
	_update_stars_label()
	stars_changed.emit(stars)
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


func _update_stars_label() -> void:
	if stars_label == null:
		return

	stars_label.text = str(stars)


func _play_score_effect() -> void:
	score_effect_tween = _play_pop_effect(score_effect_control, score_effect_tween)


func _play_stars_effect() -> void:
	stars_effect_tween = _play_pop_effect(stars_effect_control, stars_effect_tween)


func _play_score_sfx() -> void:
	if score_sfx != null:
		AudioUtility.play_sfx(self, score_sfx)


func _play_pop_effect(control: Control, current_tween: Tween) -> Tween:
	if control == null:
		return null

	if current_tween != null and current_tween.is_valid():
		current_tween.kill()

	control.pivot_offset = control.size * 0.5
	control.scale = Vector2.ONE

	var tween := control.create_tween()
	tween.tween_property(control, "scale", value_pop_scale, value_pop_out_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", Vector2.ONE, value_pop_in_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	return tween


func _can_update_local_score() -> bool:
	var player := get_parent()
	if player == null:
		return true

	if player.has_method("is_multiplayer_authority"):
		return multiplayer.multiplayer_peer == null or player.is_multiplayer_authority()

	return true
