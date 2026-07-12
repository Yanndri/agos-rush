extends Area3D

@export var stars_amount := 1


func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	var player := body as CharacterBody3D
	if player == null or not player.is_in_group("players"):
		return
	if not _is_local_player(player):
		return

	if multiplayer.multiplayer_peer == null:
		_collect_for_player(player.name)
	elif multiplayer.is_server():
		_collect_for_player.rpc(player.name)
	else:
		_request_collect_for_player.rpc_id(1, player.name)


@rpc("any_peer", "reliable")
func _request_collect_for_player(player_name: StringName) -> void:
	if not multiplayer.is_server():
		return

	_collect_for_player.rpc(player_name)


@rpc("authority", "call_local", "reliable")
func _collect_for_player(player_name: StringName) -> void:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		queue_free()
		return

	var player := current_scene.get_node_or_null(String(player_name)) as CharacterBody3D
	if player != null:
		var player_score := player.get_node_or_null("PlayerScore") as PlayerScore
		if player_score != null:
			player_score.add_stars(stars_amount)

	queue_free()


func _is_local_player(player: CharacterBody3D) -> bool:
	if multiplayer.multiplayer_peer == null:
		return true

	return player.is_multiplayer_authority()
