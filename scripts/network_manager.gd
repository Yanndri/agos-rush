extends Node

const PORT := 7777
const DISCOVERY_PORT := 7778
const MAX_PLAYERS := 8
const MAIN_SCENE := "res://scenes/Main.tscn"
const RURAL_MAP_SCENE := "res://scenes/rural_map.tscn"
const WAITING_LOBBY_SCENE := "res://scenes/waiting_lobby.tscn"
const BROADCAST_INTERVAL := 0.5

signal status_changed(message: String)

var last_error := ""
var host_code := ""
var join_code := ""
var broadcast_timer := 0.0
var discovery_peer: PacketPeerUDP
var is_hosting := false
var is_searching := false
var lobby_game_started := false

func _process(delta: float) -> void:
	if is_hosting:
		broadcast_timer -= delta
		if broadcast_timer <= 0.0:
			broadcast_timer = BROADCAST_INTERVAL
			_broadcast_host_code()

	if is_searching and discovery_peer:
		while discovery_peer.get_available_packet_count() > 0:
			var packet := discovery_peer.get_packet().get_string_from_utf8()
			var parts := packet.split(":")
			if parts.size() == 3 and parts[0] == "AGOS" and parts[1] == join_code:
				var host_ip := discovery_peer.get_packet_ip()
				_stop_discovery()
				status_changed.emit("Found host. Joining %s..." % host_ip)
				join_game(host_ip)
				return

func host_game() -> bool:
	_stop_discovery()
	host_code = _make_host_code()
	lobby_game_started = false
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(PORT, MAX_PLAYERS)
	if error != OK:
		last_error = "Could not host on port %d. Error: %s" % [PORT, error]
		status_changed.emit(last_error)
		return false
	multiplayer.multiplayer_peer = peer
	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	_start_broadcasting()
	status_changed.emit("Hosting. Code: %s" % host_code)
	print("network_manager: ", host_code)
	get_tree().change_scene_to_file(WAITING_LOBBY_SCENE)
	return true

func join_game(address: String) -> bool:
	address = address.strip_edges()
	if address.is_empty():
		address = "127.0.0.1"
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address, PORT)
	if error != OK:
		last_error = "Could not join %s:%d. Error: %s" % [address, PORT, error]
		status_changed.emit(last_error)
		return false
	multiplayer.multiplayer_peer = peer
	if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.connect(_on_connected_to_server)
	if not multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.connect(_on_connection_failed)
	status_changed.emit("Joining game...")
	return true

func join_game_by_code(code: String) -> bool:
	_stop_discovery()
	join_code = code.strip_edges()
	if join_code.is_empty():
		last_error = "Enter the host code first."
		status_changed.emit(last_error)
		return false
	discovery_peer = PacketPeerUDP.new()
	var error := discovery_peer.bind(DISCOVERY_PORT)
	if error != OK:
		last_error = "Could not listen for LAN hosts. Error: %s" % error
		status_changed.emit(last_error)
		return false
	is_searching = true
	status_changed.emit("Searching LAN for code %s..." % join_code)
	return true

func leave_game() -> void:
	_stop_discovery()
	lobby_game_started = false
	if multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.disconnect(_on_peer_connected)
	if multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.disconnect(_on_peer_disconnected)
	if multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.disconnect(_on_connected_to_server)
	if multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.disconnect(_on_connection_failed)
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null

func start_lobby_game(scene_path: String = MAIN_SCENE) -> void:
	if not multiplayer.is_server() or lobby_game_started:
		return

	lobby_game_started = true
	_stop_discovery()
	_load_game_scene.rpc(scene_path)

func _on_peer_connected(_peer_id: int) -> void:
	if not multiplayer.is_server() or lobby_game_started:
		return

	status_changed.emit("Player joined lobby.")


func _on_peer_disconnected(_peer_id: int) -> void:
	if not multiplayer.is_server():
		return

	status_changed.emit("Player left lobby.")


func _on_connected_to_server() -> void:
	status_changed.emit("Joined lobby.")
	get_tree().change_scene_to_file(WAITING_LOBBY_SCENE)


func _on_connection_failed() -> void:
	last_error = "Could not connect to host."
	status_changed.emit(last_error)


@rpc("authority", "call_local", "reliable")
func _load_game_scene(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)

func _start_broadcasting() -> void:
	discovery_peer = PacketPeerUDP.new()
	discovery_peer.set_broadcast_enabled(true)
	discovery_peer.set_dest_address("255.255.255.255", DISCOVERY_PORT)
	is_hosting = true
	broadcast_timer = 0.0

func _broadcast_host_code() -> void:
	if not discovery_peer:
		return
	var message := "AGOS:%s:%d" % [host_code, PORT]
	discovery_peer.put_packet(message.to_utf8_buffer())

func _stop_discovery() -> void:
	is_hosting = false
	is_searching = false
	if discovery_peer:
		discovery_peer.close()
	discovery_peer = null

func _make_host_code() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return str(rng.randi_range(1000, 9999))
