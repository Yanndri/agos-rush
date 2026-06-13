extends Node3D

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const SPAWN_POINTS := [
	Vector3(-4.8, 0.8, 2.2),
	Vector3(-2.8, 0.8, 2.2),
	Vector3(-4.8, 0.8, 0.2),
	Vector3(-2.8, 0.8, 0.2),
]

func _ready() -> void:
	if multiplayer.multiplayer_peer == null:
		_spawn_player(1)
		return

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	if multiplayer.is_server():
		_spawn_player.rpc(1)
		for peer_id in multiplayer.get_peers():
			_spawn_player.rpc(peer_id)

func _on_peer_connected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	for player in get_tree().get_nodes_in_group("players"):
		_spawn_player.rpc_id(peer_id, int(player.name))
	_spawn_player.rpc(peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	var player := get_node_or_null(str(peer_id))
	if player:
		player.queue_free()

@rpc("authority", "call_local", "reliable")
func _spawn_player(peer_id: int) -> void:
	if has_node(str(peer_id)):
		return
	var player := PLAYER_SCENE.instantiate()
	player.name = str(peer_id)
	player.add_to_group("players")
	player.set_multiplayer_authority(peer_id)
	add_child(player)
	player.global_position = SPAWN_POINTS[abs(peer_id) % SPAWN_POINTS.size()]
func _show_host_code_label() -> void:
	if multiplayer.multiplayer_peer == null or not multiplayer.is_server():
		return
	if NetworkManager.host_code.is_empty():
		return
	var layer := CanvasLayer.new()
	layer.name = "HostCodeLayer"
	add_child(layer)
	var label := Label.new()
	label.name = "HostCodeLabel"
	label.text = "LAN Code: %s" % NetworkManager.host_code
	label.position = Vector2(12, 12)
	label.add_theme_font_size_override("font_size", 22)
	layer.add_child(label)
