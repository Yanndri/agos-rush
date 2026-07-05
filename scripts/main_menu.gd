extends Control

const TUTORIAL_WORLD_SCENE := "res://scenes/tutorial_world.tscn"

@onready var code_edit: LineEdit = %CodeEdit
@onready var status_label: Label = %StatusLabel
@onready var tutorial_button: Button = $PanelContainer/MarginContainer/VBoxContainer/TutorialButton

func _ready() -> void:
	NetworkManager.status_changed.connect(_on_network_status_changed)
	status_label.text = "Host or enter a LAN code."
	if tutorial_button != null and not tutorial_button.pressed.is_connected(_on_tutorial_button_pressed):
		tutorial_button.pressed.connect(_on_tutorial_button_pressed)

func _on_host_button_pressed() -> void:
	if not NetworkManager.host_game():
		status_label.text = NetworkManager.last_error

func _on_join_button_pressed() -> void:
	if not NetworkManager.join_game_by_code(code_edit.text):
		status_label.text = NetworkManager.last_error

func _on_tutorial_button_pressed() -> void:
	get_tree().change_scene_to_file(TUTORIAL_WORLD_SCENE)

func _on_network_status_changed(message: String) -> void:
	status_label.text = message
	#print(message)
