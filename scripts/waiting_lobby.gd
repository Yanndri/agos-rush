extends Control

@export var room_code_label_path: NodePath = NodePath("Top/VBoxContainer/RoomCodeLabel")

@onready var room_code_label: Label = get_node_or_null(room_code_label_path) as Label


func _ready() -> void:
	_update_room_code_label()
	if not NetworkManager.status_changed.is_connected(_on_network_status_changed):
		NetworkManager.status_changed.connect(_on_network_status_changed)


func _exit_tree() -> void:
	if NetworkManager.status_changed.is_connected(_on_network_status_changed):
		NetworkManager.status_changed.disconnect(_on_network_status_changed)


func _on_network_status_changed(_message: String) -> void:
	_update_room_code_label()


func _update_room_code_label() -> void:
	if room_code_label == null:
		return
	if NetworkManager.host_code.is_empty():
		room_code_label.text = "----"
	else:
		room_code_label.text = "%s" % NetworkManager.host_code
