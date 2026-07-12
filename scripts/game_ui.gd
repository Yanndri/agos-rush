extends Control

@export var timer_path: NodePath = NodePath("TopBar/GameTimer")
@export var scoreboard_path: NodePath = NodePath("Scoreboard")
@export var player_scores_path: NodePath = NodePath("Scoreboard/VBoxContainer/Main/PlayerScores")
@export var back_to_main_menu_path: NodePath = NodePath("Scoreboard/VBoxContainer/Bottom/BackToMainMenu")
@export var announcement_container_path: NodePath = NodePath("Announcement/VBoxContainer")
@export var announcement_label_template_path: NodePath = NodePath("Announcement/VBoxContainer/LabelTemplate")
@export var announcement_duration := 3.0
@export var objectives_list_path: NodePath = NodePath("Objectives/VBoxContainer/ObjectivesList")
@export var objective_template_path: NodePath = NodePath("Objectives/VBoxContainer/ObjectivesList/objectivetemplate")
@export_file("*.tscn") var main_menu_scene: String = "res://scenes/main_menu.tscn"

@onready var game_timer: GameTimer = get_node_or_null(timer_path) as GameTimer
@onready var scoreboard: Control = get_node_or_null(scoreboard_path) as Control
@onready var player_scores_container: Control = get_node_or_null(player_scores_path) as Control
@onready var back_to_main_menu_button: Button = get_node_or_null(back_to_main_menu_path) as Button
@onready var announcement_container: Control = get_node_or_null(announcement_container_path) as Control
@onready var announcement_label_template: Label = get_node_or_null(announcement_label_template_path) as Label
@onready var objectives_list: Control = get_node_or_null(objectives_list_path) as Control
@onready var objective_template: RichTextLabel = get_node_or_null(objective_template_path) as RichTextLabel

var objective_rows := {}
var next_objective_index := 1


func _ready() -> void:
	add_to_group("game_ui")

	if scoreboard != null:
		scoreboard.visible = false

	if announcement_label_template != null:
		announcement_label_template.visible = false

	if objective_template != null:
		objective_template.visible = false

	if game_timer != null and not game_timer.timer_finished.is_connected(_on_game_timer_finished):
		game_timer.timer_finished.connect(_on_game_timer_finished)

	if back_to_main_menu_button != null and not back_to_main_menu_button.pressed.is_connected(_on_back_to_main_menu_pressed):
		back_to_main_menu_button.pressed.connect(_on_back_to_main_menu_pressed)


func announce(text: String) -> void:
	if announcement_container == null or announcement_label_template == null:
		return
	if text.strip_edges().is_empty():
		return

	var label := announcement_label_template.duplicate() as Label
	if label == null:
		return

	label.text = text
	label.visible = true
	label.modulate.a = 0.0
	label.scale = Vector2(0.8, 0.8)
	announcement_container.add_child(label)
	_play_announcement_pop(label)
	_remove_announcement_after_delay(label)


func _play_announcement_pop(label: Label) -> void:
	await get_tree().process_frame
	if not is_instance_valid(label):
		return

	label.pivot_offset = label.size * 0.5
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "scale", Vector2(1.12, 1.12), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 1.0, 0.08)
	tween.chain().tween_property(label, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _remove_announcement_after_delay(label: Label) -> void:
	await get_tree().create_timer(announcement_duration).timeout
	if not is_instance_valid(label):
		return

	var tween := create_tween()
	tween.tween_property(label, "modulate:a", 0.0, 0.2)
	await tween.finished
	if is_instance_valid(label):
		label.queue_free()


func add_objective(text: String, objective_id := "") -> RichTextLabel:
	# call by: get_tree().call_group("game_ui", "add_objective", "- Drain the flooded market", "id01") -- last parameter is the id to update and remove objective
	if objectives_list == null or objective_template == null:
		return null
	if text.strip_edges().is_empty():
		return null

	var id := _get_objective_id(text, objective_id)
	var should_update_existing := not objective_id.strip_edges().is_empty()
	if should_update_existing and objective_rows.has(id):
		var existing_row := objective_rows[id] as RichTextLabel
		if is_instance_valid(existing_row):
			existing_row.text = text
			return existing_row
		objective_rows.erase(id)

	var row := objective_template.duplicate() as RichTextLabel
	if row == null:
		return null

	row.name = "Objective_%s" % id
	row.set_meta("objective_id", id)
	row.text = text
	row.visible = true
	row.modulate.a = 0.0
	row.scale = Vector2(0.92, 0.92)
	objectives_list.add_child(row)
	objective_rows[id] = row
	_play_objective_add(row)
	return row


func remove_objective(objective_id_or_text: String) -> void:
	#use by: get_tree().call_group("game_ui", "remove_objective", "id01")
	var id := _get_objective_id(objective_id_or_text, objective_id_or_text)
	var row := objective_rows.get(id) as RichTextLabel

	if row == null:
		row = _find_objective_row_by_text(objective_id_or_text)
		if row != null:
			id = String(row.get_meta("objective_id", id))

	if row == null or not is_instance_valid(row):
		objective_rows.erase(id)
		return

	objective_rows.erase(id)
	_play_objective_remove(row)


func _play_objective_add(row: RichTextLabel) -> void:
	await get_tree().process_frame
	if not is_instance_valid(row):
		return

	row.pivot_offset = row.size * 0.5
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(row, "modulate:a", 1.0, 0.12)
	tween.tween_property(row, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _play_objective_remove(row: RichTextLabel) -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(row, "modulate:a", 0.0, 0.16)
	tween.tween_property(row, "scale", Vector2(0.92, 0.92), 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tween.finished
	if is_instance_valid(row):
		row.queue_free()


func _find_objective_row_by_text(text: String) -> RichTextLabel:
	if objectives_list == null:
		return null

	for child in objectives_list.get_children():
		var row := child as RichTextLabel
		if row == null or row == objective_template:
			continue
		if row.text == text or String(row.get_meta("objective_id", "")) == text:
			return row

	return null


func _get_objective_id(text: String, objective_id: String) -> String:
	if not objective_id.strip_edges().is_empty():
		return objective_id.strip_edges().to_snake_case()

	var id := "objective_%d" % next_objective_index
	next_objective_index += 1
	return id


func _on_game_timer_finished() -> void:
	announce("Time is up!")
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
