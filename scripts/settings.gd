extends PanelContainer

@export var back_to_main_menu_button_path: NodePath = NodePath("SettingsPanel/PanelContainer/VBoxContainer/Main/VBoxContainer/BackToMainMenu/MainMenuButton")
@export var master_volume_slider_path: NodePath = NodePath("SettingsPanel/PanelContainer/VBoxContainer/Main/VBoxContainer/MasterVolume/HBoxContainer/MasterVolumeSlider")
@export var music_volume_slider_path: NodePath = NodePath("SettingsPanel/PanelContainer/VBoxContainer/Main/VBoxContainer/MusicVolume/HBoxContainer/MusicVolumeSlider")
@export var sfx_volume_slider_path: NodePath = NodePath("SettingsPanel/PanelContainer/VBoxContainer/Main/VBoxContainer/SFXVolume/HBoxContainer/SFXVolumeSlider")
@export_file("*.tscn") var main_menu_scene: String = "res://scenes/main_menu.tscn"

@onready var settings_button: Button = $SettingsButton
@onready var settings_panel: Control = $SettingsPanel
@onready var back_to_main_menu_button: Button = get_node_or_null(back_to_main_menu_button_path) as Button
@onready var master_volume_slider: Slider = get_node_or_null(master_volume_slider_path) as Slider
@onready var music_volume_slider: Slider = get_node_or_null(music_volume_slider_path) as Slider
@onready var sfx_volume_slider: Slider = get_node_or_null(sfx_volume_slider_path) as Slider


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	settings_panel.visible = false
	settings_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not settings_button.pressed.is_connected(_on_settings_button_pressed):
		settings_button.pressed.connect(_on_settings_button_pressed)
	if not settings_panel.gui_input.is_connected(_on_settings_panel_gui_input):
		settings_panel.gui_input.connect(_on_settings_panel_gui_input)
	if back_to_main_menu_button != null and not back_to_main_menu_button.pressed.is_connected(_on_back_to_main_menu_button_pressed):
		back_to_main_menu_button.pressed.connect(_on_back_to_main_menu_button_pressed)
	_setup_volume_slider(master_volume_slider, &"Master", _on_master_volume_changed)
	_setup_volume_slider(music_volume_slider, &"Music", _on_music_volume_changed)
	_setup_volume_slider(sfx_volume_slider, &"SFX", _on_sfx_volume_changed)


func _on_settings_button_pressed() -> void:
	settings_panel.visible = not settings_panel.visible
	settings_panel.mouse_filter = Control.MOUSE_FILTER_STOP if settings_panel.visible else Control.MOUSE_FILTER_IGNORE


func _on_settings_panel_gui_input(event: InputEvent) -> void:
	var mouse_button := event as InputEventMouseButton
	if mouse_button == null or not mouse_button.pressed or mouse_button.button_index != MOUSE_BUTTON_LEFT:
		return

	if settings_button.get_global_rect().has_point(mouse_button.global_position):
		settings_panel.visible = false
		settings_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		settings_panel.accept_event()


func _on_back_to_main_menu_button_pressed() -> void:
	if multiplayer.multiplayer_peer != null:
		NetworkManager.leave_game()

	get_tree().change_scene_to_file(main_menu_scene)


func _on_master_volume_changed(value: float) -> void:
	_set_bus_volume_percent(&"Master", value)


func _on_music_volume_changed(value: float) -> void:
	_set_bus_volume_percent(&"Music", value)


func _on_sfx_volume_changed(value: float) -> void:
	_set_bus_volume_percent(&"SFX", value)


func _setup_volume_slider(slider: Slider, bus_name: StringName, callback: Callable) -> void:
	if slider == null:
		return

	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.value = _get_bus_volume_percent(bus_name)
	if not slider.value_changed.is_connected(callback):
		slider.value_changed.connect(callback)


func _set_bus_volume_percent(bus_name: StringName, percent: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		return

	var normalized_volume : float = clamp(percent / 100.0, 0.0, 1.0)
	AudioServer.set_bus_mute(bus_index, normalized_volume <= 0.0)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(max(normalized_volume, 0.0001)))


func _get_bus_volume_percent(bus_name: StringName) -> float:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		return 100.0
	if AudioServer.is_bus_mute(bus_index):
		return 0.0

	return clamp(db_to_linear(AudioServer.get_bus_volume_db(bus_index)) * 100.0, 0.0, 100.0)
