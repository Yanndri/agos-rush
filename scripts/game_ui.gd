extends Control

@export var timer_path: NodePath = NodePath("TopBar/GameTimer")
@export var scoreboard_path: NodePath = NodePath("Scoreboard")
@export var player_scores_path: NodePath = NodePath("Scoreboard/VBoxContainer/Main/PlayerScores")
@export var back_to_main_menu_path: NodePath = NodePath("Scoreboard/VBoxContainer/Bottom/BackToMainMenu")
@export_file("*.tscn") var main_menu_scene: String = "res://scenes/main_menu.tscn"

@onready var game_timer: GameTimer = get_node_or_null(timer_path) as GameTimer
@onready var scoreboard: Control = get_node_or_null(scoreboard_path) as Control
@onready var player_scores_container: Control = get_node_or_null(player_scores_path) as Control
@onready var back_to_main_menu_button: Button = get_node_or_null(back_to_main_menu_path) as Button


func _ready() -> void:
	if scoreboard != null:
		scoreboard.visible = false

	if game_timer != null and not game_timer.timer_finished.is_connected(_on_game_timer_finished):
		game_timer.timer_finished.connect(_on_game_timer_finished)

	if back_to_main_menu_button != null and not back_to_main_menu_button.pressed.is_connected(_on_back_to_main_menu_pressed):
		back_to_main_menu_button.pressed.connect(_on_back_to_main_menu_pressed)


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
	var highest_score := _get_highest_score(players)

	for index in range(players.size()):
		var player := players[index] as CharacterBody3D
		if player == null:
			continue

		var player_score := player.get_node_or_null("PlayerScore") as PlayerScore
		_update_player_score_column(index, player, player_score, highest_score)


func _update_player_score_column(player_index: int, player: CharacterBody3D, player_score: PlayerScore, highest_score: int) -> void:
	var column := player_scores_container.get_node_or_null("Player%d" % (player_index + 1))
	if column == null:
		return

	var current_score := player_score.score if player_score != null else 0

	var player_name_label := column.get_node_or_null("VBoxContainer/PlayerName") as Label
	if player_name_label != null:
		player_name_label.text = _get_player_display_name(player)

	_update_achievement_rows(column, player_score)

	var total_score_label := column.get_node_or_null("VBoxContainer/TotalScore/scoreAmount") as Label
	if total_score_label != null:
		total_score_label.text = str(current_score)

	_update_result_ui(column, current_score, highest_score)


func _update_achievement_rows(column: Node, player_score: PlayerScore) -> void:
	var score_list := column.get_node_or_null("VBoxContainer/Scores/ScoreList") as Control
	if score_list == null:
		return

	var template_row := score_list.get_node_or_null("Score1") as Control
	if template_row == null:
		return

	for child in score_list.get_children():
		if child == template_row:
			continue

		score_list.remove_child(child)
		child.queue_free()

	template_row.visible = true

	if player_score == null or player_score.achievements.is_empty():
		_set_achievement_row(template_row, "No achievements", 0)
		return

	for index in range(player_score.achievements.size()):
		var row: Control = template_row
		if index > 0:
			row = template_row.duplicate() as Control
			if row == null:
				continue

			row.name = "Score%d" % (index + 1)
			score_list.add_child(row)

		var achievement: Dictionary = player_score.achievements[index]
		var achievement_name := String(achievement.get("name", "Achievement"))
		var achievement_points := int(achievement.get("points", 0))
		_set_achievement_row(row, achievement_name, achievement_points)


func _set_achievement_row(row: Node, achievement_name: String, points: int) -> void:
	var achievement_name_label := row.get_node_or_null("scoreName") as Label
	if achievement_name_label != null:
		achievement_name_label.text = achievement_name

	var achievement_score_label := row.get_node_or_null("scoreAmount") as Label
	if achievement_score_label != null:
		achievement_score_label.text = str(points)


func _get_highest_score(players: Array[Node]) -> int:
	var highest_score := 0
	for player in players:
		var player_score := player.get_node_or_null("PlayerScore") as PlayerScore
		var score := player_score.score if player_score != null else 0
		highest_score = max(highest_score, score)

	return highest_score


func _update_result_ui(column: Node, current_score: int, highest_score: int) -> void:
	var victory_text := column.get_node_or_null("VBoxContainer/ResultUI/VictoryText") as CanvasItem
	var defeat_text := column.get_node_or_null("VBoxContainer/ResultUI/DefeatText") as CanvasItem
	var is_highest_scorer := current_score >= highest_score

	if victory_text != null:
		victory_text.visible = is_highest_scorer
	if defeat_text != null:
		defeat_text.visible = not is_highest_scorer


func _on_back_to_main_menu_pressed() -> void:
	if multiplayer.multiplayer_peer != null:
		NetworkManager.leave_game()

	get_tree().change_scene_to_file(main_menu_scene)


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
