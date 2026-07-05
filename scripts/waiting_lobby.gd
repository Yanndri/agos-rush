extends Control

@export var room_code_label_path: NodePath = NodePath("Top/VBoxContainer/RoomCodeLabel")
@export var start_button_path: NodePath = NodePath("StartSettings/VBoxContainer/Start")
@export var preview_player_2_shaun_path: NodePath = NodePath("PlayerPreview/SubViewport/PreviewWorld/PreviewPlayer2/PlayerModel/CharacterArmature/Skeleton3D/Shaun")

@onready var room_code_label: Label = get_node_or_null(room_code_label_path) as Label
@onready var start_button: Button = get_node_or_null(start_button_path) as Button
@onready var preview_player_2_shaun: MeshInstance3D = get_node_or_null(preview_player_2_shaun_path) as MeshInstance3D


func _ready() -> void:
	_update_room_code_label()
	if not NetworkManager.status_changed.is_connected(_on_network_status_changed):
		NetworkManager.status_changed.connect(_on_network_status_changed)
	if not multiplayer.peer_connected.is_connected(_on_peer_count_changed):
		multiplayer.peer_connected.connect(_on_peer_count_changed)
	if not multiplayer.peer_disconnected.is_connected(_on_peer_count_changed):
		multiplayer.peer_disconnected.connect(_on_peer_count_changed)
	if start_button != null and not start_button.pressed.is_connected(_on_start_pressed):
		start_button.pressed.connect(_on_start_pressed)
	_update_lobby_state()


func _exit_tree() -> void:
	if NetworkManager.status_changed.is_connected(_on_network_status_changed):
		NetworkManager.status_changed.disconnect(_on_network_status_changed)
	if multiplayer.peer_connected.is_connected(_on_peer_count_changed):
		multiplayer.peer_connected.disconnect(_on_peer_count_changed)
	if multiplayer.peer_disconnected.is_connected(_on_peer_count_changed):
		multiplayer.peer_disconnected.disconnect(_on_peer_count_changed)


func _on_network_status_changed(_message: String) -> void:
	_update_room_code_label()
	_update_lobby_state()


func _on_peer_count_changed(_peer_id: int) -> void:
	_update_lobby_state()


func _on_start_pressed() -> void:
	NetworkManager.start_lobby_game()


func _update_room_code_label() -> void:
	if room_code_label == null:
		return
	if NetworkManager.host_code.is_empty():
		room_code_label.text = "----"
	else:
		room_code_label.text = "%s" % NetworkManager.host_code


func _update_lobby_state() -> void:
	var has_other_player := _has_other_player()

	if preview_player_2_shaun != null and has_other_player:
		preview_player_2_shaun.material_override = null

	if start_button != null:
		start_button.disabled = not multiplayer.is_server() or not has_other_player


func _has_other_player() -> bool:
	if multiplayer.multiplayer_peer == null:
		return false

	return not multiplayer.get_peers().is_empty()
