extends Control

@export var timer_path: NodePath = NodePath("TopBar/GameTimer")
@export var scoreboard_path: NodePath = NodePath("Scoreboard")
@export var player_scores_path: NodePath = NodePath("Scoreboard/VBoxContainer/Main/PlayerScores")

@onready var game_timer: GameTimer = get_node_or_null(timer_path) as GameTimer
@onready var scoreboard: Control = get_node_or_null(scoreboard_path) as Control
@onready var player_scores_container: Control = get_node_or_null(player_scores_path) as Control


func _ready() -> void:
	if scoreboard != null:
		scoreboard.visible = false

	if game_timer != null and not game_timer.timer_finished.is_connected(_on_game_timer_finished):
		game_timer.timer_finished.connect(_on_game_timer_finished)


func _on_game_timer_finished() -> void:
	_show_scoreboard()


func _show_scoreboard() -> void:
	if scoreboard != null:
		scoreboard.visible = true

	_update_scoreboard()


func _update_scoreboard() -> void:
	if player_scores_container == null:
		return

	var players := get_tree().get_nodes_in_group("players")
	players.sort_custom(_sort_players_by_name)

	for index in range(players.size()):
		var player := players[index] as CharacterBody3D
		if player == null:
			continue

		var player_score := player.get_node_or_null("PlayerScore") as PlayerScore
		_update_player_score_column(index, player, player_score)


func _update_player_score_column(player_index: int, player: CharacterBody3D, player_score: PlayerScore) -> void:
	var column := player_scores_container.get_node_or_null("Player%d" % (player_index + 1))
	if column == null:
		return

	var player_name_label := column.get_node_or_null("VBoxContainer/PlayerName") as Label
	if player_name_label != null:
		player_name_label.text = _get_player_display_name(player)

	var achievement_name_label := column.get_node_or_null("VBoxContainer/Score1/scoreName") as Label
	if achievement_name_label != null:
		achievement_name_label.text = player_score.get_achievement_summary() if player_score != null else "No achievements"

	var achievement_score_label := column.get_node_or_null("VBoxContainer/Score1/scoreAmount") as Label
	if achievement_score_label != null:
		achievement_score_label.text = str(player_score.score if player_score != null else 0)

	var total_score_label := column.get_node_or_null("VBoxContainer/TotalScore/scoreAmount") as Label
	if total_score_label != null:
		total_score_label.text = str(player_score.score if player_score != null else 0)


func _get_player_display_name(player: Node) -> String:
	if player == null:
		return "Player"

	var raw_name := String(player.name)
	if raw_name.is_valid_int():
		return "Player %s" % raw_name
	if raw_name.is_empty():
		return "Player"

	return raw_name


func _sort_players_by_name(a: Node, b: Node) -> bool:
	return String(a.name) < String(b.name)
