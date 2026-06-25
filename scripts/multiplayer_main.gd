extends Node3D

@export var PLAYER_SCENE := preload("res://scenes/PlayerShaun.tscn")
@export var AMBULANCE_SCENE := preload("res://scenes/Interactables/ambulance.tscn")
@export var spawn_node_path: NodePath = NodePath("Spawn")
@export var waiting_players_path: NodePath = NodePath("WaitingPlayers")

func _ready() -> void:
	_update_room_code_label("LAN Code: %s" % NetworkManager.host_code if multiplayer.multiplayer_peer and multiplayer.is_server() and not NetworkManager.host_code.is_empty() else "")
	
	if multiplayer.multiplayer_peer == null:
		_spawn_player(1)
		return

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	if multiplayer.is_server():
		_spawn_player.rpc(1)
		for peer_id in multiplayer.get_peers():
			_spawn_player.rpc(peer_id)

func _update_room_code_label(message: String) -> void:
	var room_code_label := get_node_or_null("%RoomCodeLabel") as Label
	if room_code_label:
		room_code_label.text = message

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

	var ambulance := find_child("Ambulance_%s" % peer_id, true, false)
	if ambulance:
		ambulance.queue_free()

@rpc("authority", "call_local", "reliable")
func _spawn_player(peer_id: int) -> void:
	if has_node(str(peer_id)):
		return
	var spawn_index := get_tree().get_nodes_in_group("players").size()
	var player := PLAYER_SCENE.instantiate()
	player.name = str(peer_id)
	player.add_to_group("players")
	player.set_multiplayer_authority(peer_id)
	add_child(player)
	player.global_position = _get_spawn_position(spawn_index)
	_assign_ambulance_to_player(peer_id)

func _assign_ambulance_to_player(peer_id: int) -> void:
	if find_child("Ambulance_%s" % peer_id, true, false) != null:
		return

	var slot := _get_waiting_player_slot(peer_id)
	if slot == null:
		push_warning("No WaitingPlayers slot for player: " + str(peer_id))
		return

	var ambulance := AMBULANCE_SCENE.instantiate()
	ambulance.name = "Ambulance_%s" % peer_id
	ambulance.set_multiplayer_authority(peer_id)
	ambulance.set("ambulance_owner", str(peer_id))
	slot.add_child(ambulance)
	ambulance.global_transform = slot.global_transform

func _get_waiting_player_slot(peer_id: int) -> Node3D:
	var waiting_players := get_node_or_null(waiting_players_path)
	if waiting_players == null:
		waiting_players = find_child("WaitingPlayers", true, false)

	if waiting_players == null:
		return null

	var slots := waiting_players.get_children()
	var slot_index := peer_id - 1
	if slot_index < 0 or slot_index >= slots.size():
		return null

	return slots[slot_index] as Node3D

func _get_spawn_position(spawn_index: int) -> Vector3:
	var spawn := get_node_or_null(spawn_node_path) as Node3D
	if spawn == null:
		spawn = find_child("Spawn", true, false) as Node3D

	var base_position := Vector3(-4.8, 1.25, 2.2)
	if spawn != null:
		base_position.x = spawn.global_position.x
		base_position.z = spawn.global_position.z
	var offset := Vector3(float(spawn_index) * 0.0, 1.5, 0.0)
	return base_position + offset

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
	print("MultiplayerMain2: ", NetworkManager.host_code)
	label.position = Vector2(12, 12)
	label.add_theme_font_size_override("font_size", 22)
	layer.add_child(label)
