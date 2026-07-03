extends PanelContainer

@onready var settings_button: Button = $SettingsButton
@onready var settings_panel: Control = $SettingsPanel


func _ready() -> void:
	settings_panel.visible = false
	if not settings_button.pressed.is_connected(_on_settings_button_pressed):
		settings_button.pressed.connect(_on_settings_button_pressed)


func _on_settings_button_pressed() -> void:
	settings_panel.visible = true
