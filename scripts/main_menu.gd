extends Control

@onready var code_edit: LineEdit = $PanelContainer/VBoxContainer/CodeEdit
@onready var status_label: Label = $PanelContainer/VBoxContainer/StatusLabel

func _ready() -> void:
	NetworkManager.status_changed.connect(_on_network_status_changed)
	status_label.text = "Host or enter a LAN code."

func _on_host_button_pressed() -> void:
	if not NetworkManager.host_game():
		status_label.text = NetworkManager.last_error

func _on_join_button_pressed() -> void:
	if not NetworkManager.join_game_by_code(code_edit.text):
		status_label.text = NetworkManager.last_error

func _on_network_status_changed(message: String) -> void:
	status_label.text = message
	#print(message)
