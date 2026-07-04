extends PanelContainer

@onready var settings_button: Button = $SettingsButton
@onready var settings_panel: Control = $SettingsPanel


func _ready() -> void:
	settings_panel.visible = false
	if not settings_button.pressed.is_connected(_on_settings_button_pressed):
		settings_button.pressed.connect(_on_settings_button_pressed)
	if not settings_panel.gui_input.is_connected(_on_settings_panel_gui_input):
		settings_panel.gui_input.connect(_on_settings_panel_gui_input)


func _on_settings_button_pressed() -> void:
	settings_panel.visible = not settings_panel.visible


func _on_settings_panel_gui_input(event: InputEvent) -> void:
	var mouse_button := event as InputEventMouseButton
	if mouse_button == null or not mouse_button.pressed or mouse_button.button_index != MOUSE_BUTTON_LEFT:
		return

	if settings_button.get_global_rect().has_point(mouse_button.global_position):
		settings_panel.visible = false
		settings_panel.accept_event()
