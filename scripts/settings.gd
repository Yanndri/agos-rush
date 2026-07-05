extends PanelContainer

@export var back_to_main_menu_button_path: NodePath = NodePath("SettingsPanel/PanelContainer/VBoxContainer/Main/VBoxContainer/BackToMainMenu/Button")
@export_file("*.tscn") var main_menu_scene: String = "res://scenes/main_menu.tscn"

@onready var settings_button: Button = $SettingsButton
@onready var settings_panel: Control = $SettingsPanel
@onready var back_to_main_menu_button: Button = get_node_or_null(back_to_main_menu_button_path) as Button


func _ready() -> void:
	settings_panel.visible = false
	if not settings_button.pressed.is_connected(_on_settings_button_pressed):
		settings_button.pressed.connect(_on_settings_button_pressed)
	if not settings_panel.gui_input.is_connected(_on_settings_panel_gui_input):
		settings_panel.gui_input.connect(_on_settings_panel_gui_input)
	if back_to_main_menu_button != null and not back_to_main_menu_button.pressed.is_connected(_on_back_to_main_menu_button_pressed):
		back_to_main_menu_button.pressed.connect(_on_back_to_main_menu_button_pressed)


func _on_settings_button_pressed() -> void:
	settings_panel.visible = not settings_panel.visible


func _on_settings_panel_gui_input(event: InputEvent) -> void:
	var mouse_button := event as InputEventMouseButton
	if mouse_button == null or not mouse_button.pressed or mouse_button.button_index != MOUSE_BUTTON_LEFT:
		return

	if settings_button.get_global_rect().has_point(mouse_button.global_position):
		settings_panel.visible = false
		settings_panel.accept_event()


func _on_back_to_main_menu_button_pressed() -> void:
	if multiplayer.multiplayer_peer != null:
		NetworkManager.leave_game()

	get_tree().change_scene_to_file(main_menu_scene)
