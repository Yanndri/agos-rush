extends Node3D

@export var interact_action := "interact"
@export var animation_player_path: NodePath = NodePath("AnimationPlayer")
@export var prompt_area_path: NodePath = NodePath("PromptArea")
@export var upgrade_ui_path: NodePath = NodePath("UpgradeUI")
@export var upgrade_panel_path: NodePath = NodePath("UpgradeUI/MarginContainer")
@export var close_button_path: NodePath = NodePath("UpgradeUI/MarginContainer/VBoxContainer/TopBar/HBoxContainer/Close")
@export var points_amount_path: NodePath = NodePath("UpgradeUI/MarginContainer/VBoxContainer/TopBar/HBoxContainer/PointsAmount")
@export var speed_label_path: NodePath = NodePath("UpgradeUI/MarginContainer/VBoxContainer/Main/VBoxContainer/Speed/HBoxContainer/Label")
@export var speed_button_path: NodePath = NodePath("UpgradeUI/MarginContainer/VBoxContainer/Main/VBoxContainer/Speed/HBoxContainer/Buy")
@export var hotbar_label_path: NodePath = NodePath("UpgradeUI/MarginContainer/VBoxContainer/Main/VBoxContainer/Hotbar/HBoxContainer/Label")
@export var hotbar_button_path: NodePath = NodePath("UpgradeUI/MarginContainer/VBoxContainer/Main/VBoxContainer/Hotbar/HBoxContainer/Buy")
@export var map_label_path: NodePath = NodePath("UpgradeUI/MarginContainer/VBoxContainer/Main/VBoxContainer/Map/HBoxContainer/Label")
@export var map_button_path: NodePath = NodePath("UpgradeUI/MarginContainer/VBoxContainer/Main/VBoxContainer/Map/HBoxContainer/Buy")
@export var idle_animation := &"Idle"
@export var wave_animation := &"Wave"
@export var wave_interval := 4.0
@export var panel_show_time := 0.18
@export var panel_hide_time := 0.14

@onready var animation_player: AnimationPlayer = get_node_or_null(animation_player_path) as AnimationPlayer
@onready var prompt_area: PromptArea = get_node_or_null(prompt_area_path) as PromptArea
@onready var upgrade_ui: Control = get_node_or_null(upgrade_ui_path) as Control
@onready var upgrade_panel: Control = get_node_or_null(upgrade_panel_path) as Control
@onready var close_button: Button = get_node_or_null(close_button_path) as Button
@onready var points_amount_label: RichTextLabel = get_node_or_null(points_amount_path) as RichTextLabel
@onready var speed_label: Label = get_node_or_null(speed_label_path) as Label
@onready var speed_button: Button = get_node_or_null(speed_button_path) as Button
@onready var hotbar_label: Label = get_node_or_null(hotbar_label_path) as Label
@onready var hotbar_button: Button = get_node_or_null(hotbar_button_path) as Button
@onready var map_label: Label = get_node_or_null(map_label_path) as Label
@onready var map_button: Button = get_node_or_null(map_button_path) as Button

const MAP_UPGRADES := [
	{"cost": 1},
]

const SPEED_UPGRADES := [
	{"multiplier": 1.2, "cost": 1},
	{"multiplier": 1.4, "cost": 3},
	{"multiplier": 1.6, "cost": 5},
]
const HOTBAR_UPGRADES := [
	{"slots": 1, "cost": 2},
	{"slots": 1, "cost": 3},
]


var nearby_player: CharacterBody3D
var speed_upgrade_index := 0
var hotbar_upgrade_index := 0
var map_upgrade_index := 0
var previous_mouse_mode := Input.MOUSE_MODE_VISIBLE
var upgrade_canvas_layer: CanvasLayer
var upgrade_panel_tween: Tween
var upgrade_ui_open := false


func _ready() -> void:
	_setup_upgrade_ui()
	_setup_prompt_area()
	_setup_animation()


func _unhandled_input(event: InputEvent) -> void:
	if nearby_player == null or upgrade_ui == null:
		return

	if event is InputEventKey and event.echo:
		return

	if event.is_action_pressed(interact_action):
		get_viewport().set_input_as_handled()
		_show_upgrade_ui()


func _setup_upgrade_ui() -> void:
	if upgrade_ui != null:
		_move_upgrade_ui_to_canvas_layer()
		upgrade_ui.visible = false
		upgrade_ui.mouse_filter = Control.MOUSE_FILTER_STOP
		_set_child_mouse_filters(upgrade_ui)

	if upgrade_panel != null:
		upgrade_panel.visible = true
		upgrade_panel.modulate.a = 1.0
		upgrade_panel.scale = Vector2.ONE

	if speed_button != null and not speed_button.pressed.is_connected(_on_speed_buy_pressed):
		speed_button.pressed.connect(_on_speed_buy_pressed)

	if hotbar_button != null and not hotbar_button.pressed.is_connected(_on_hotbar_buy_pressed):
		hotbar_button.pressed.connect(_on_hotbar_buy_pressed)

	if map_button != null and not map_button.pressed.is_connected(_on_map_buy_pressed):
		map_button.pressed.connect(_on_map_buy_pressed)

	if close_button != null and not close_button.pressed.is_connected(_on_close_button_pressed):
		close_button.pressed.connect(_on_close_button_pressed)

	_update_shop_ui()


func _setup_prompt_area() -> void:
	if prompt_area == null:
		push_warning("UpgradeShop is missing its PromptArea.")
		return

	if not prompt_area.local_player_entered.is_connected(_on_prompt_area_local_player_entered):
		prompt_area.local_player_entered.connect(_on_prompt_area_local_player_entered)

	if not prompt_area.local_player_exited.is_connected(_on_prompt_area_local_player_exited):
		prompt_area.local_player_exited.connect(_on_prompt_area_local_player_exited)


func _setup_animation() -> void:
	if animation_player == null:
		push_warning("UpgradeShop is missing its AnimationPlayer.")
		return

	if not animation_player.animation_finished.is_connected(_on_animation_player_animation_finished):
		animation_player.animation_finished.connect(_on_animation_player_animation_finished)

	if animation_player.has_animation(idle_animation):
		animation_player.play(idle_animation)

	_start_wave_loop()


func _show_upgrade_ui() -> void:
	if upgrade_ui != null:
		_update_shop_ui()
		previous_mouse_mode = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		upgrade_ui.visible = true
		upgrade_ui_open = true
		_kill_upgrade_panel_tween()

		if upgrade_panel != null:
			upgrade_panel_tween = YapperTweens.panel_in(upgrade_panel, panel_show_time)


func _hide_upgrade_ui() -> void:
	if upgrade_ui == null or not upgrade_ui.visible:
		return

	upgrade_ui_open = false
	Input.mouse_mode = previous_mouse_mode
	_kill_upgrade_panel_tween()

	if upgrade_panel != null:
		upgrade_panel_tween = YapperTweens.panel_out(upgrade_panel, panel_hide_time)
		if upgrade_panel_tween != null:
			upgrade_panel_tween.finished.connect(func() -> void:
				if not upgrade_ui_open and is_instance_valid(upgrade_ui):
					upgrade_ui.visible = false
			)
			return

	upgrade_ui.visible = false


func _move_upgrade_ui_to_canvas_layer() -> void:
	if upgrade_ui.get_parent() is CanvasLayer:
		return

	upgrade_canvas_layer = CanvasLayer.new()
	upgrade_canvas_layer.name = "UpgradeUICanvasLayer"
	upgrade_canvas_layer.layer = 100
	add_child(upgrade_canvas_layer)
	upgrade_ui.reparent(upgrade_canvas_layer, false)


func _set_child_mouse_filters(root: Node) -> void:
	for child in root.get_children():
		var control := child as Control
		if control != null and not control is Button:
			control.mouse_filter = Control.MOUSE_FILTER_PASS

		_set_child_mouse_filters(child)


func _kill_upgrade_panel_tween() -> void:
	if upgrade_panel_tween != null and upgrade_panel_tween.is_valid():
		upgrade_panel_tween.kill()

	upgrade_panel_tween = null


func _on_prompt_area_local_player_entered(player: CharacterBody3D) -> void:
	nearby_player = player
	_update_shop_ui()


func _on_prompt_area_local_player_exited(player: CharacterBody3D) -> void:
	if player != nearby_player:
		return

	nearby_player = null
	_hide_upgrade_ui()


func _on_speed_buy_pressed() -> void:
	if speed_upgrade_index >= SPEED_UPGRADES.size():
		return

	var upgrade: Dictionary = SPEED_UPGRADES[speed_upgrade_index]
	if not _spend_stars(upgrade["cost"]):
		return

	var player := nearby_player
	if player != null:
		_apply_speed_multiplier(player, upgrade["multiplier"])

	speed_upgrade_index += 1
	_update_shop_ui()


func _on_hotbar_buy_pressed() -> void:
	if hotbar_upgrade_index >= HOTBAR_UPGRADES.size():
		return

	var upgrade: Dictionary = HOTBAR_UPGRADES[hotbar_upgrade_index]
	if not _spend_stars(upgrade["cost"]):
		return

	var inventory := _get_player_inventory()
	if inventory != null and inventory.has_method("increase_hotbar_slots"):
		inventory.increase_hotbar_slots(upgrade["slots"])

	hotbar_upgrade_index += 1
	_update_shop_ui()


func _on_map_buy_pressed() -> void:
	if map_upgrade_index >= MAP_UPGRADES.size():
		return

	var upgrade: Dictionary = MAP_UPGRADES[map_upgrade_index]
	if not _spend_stars(upgrade["cost"]):
		return

	var map_controller := _get_map_controller()
	if map_controller != null and map_controller.has_method("unlock_map"):
		map_controller.unlock_map()

	map_upgrade_index += 1
	_update_shop_ui()


func _on_close_button_pressed() -> void:
	_hide_upgrade_ui()


func _update_shop_ui() -> void:
	var score := _get_player_score()
	if points_amount_label != null:
		points_amount_label.text = str(score.stars if score != null else 0)

	_update_speed_ui()
	_update_hotbar_ui()
	_update_map_ui()


func _update_speed_ui() -> void:
	if speed_upgrade_index >= SPEED_UPGRADES.size():
		if speed_label != null:
			speed_label.text = "Speed Max"
		_set_button_max(speed_button)
		return

	var upgrade: Dictionary = SPEED_UPGRADES[speed_upgrade_index]
	if speed_label != null:
		speed_label.text = "Speed %.1fx" % upgrade["multiplier"]
	_set_button_cost(speed_button, upgrade["cost"])


func _update_hotbar_ui() -> void:
	if hotbar_upgrade_index >= HOTBAR_UPGRADES.size():
		if hotbar_label != null:
			hotbar_label.text = "Hotbar Max"
		_set_button_max(hotbar_button)
		return

	var upgrade: Dictionary = HOTBAR_UPGRADES[hotbar_upgrade_index]
	if hotbar_label != null:
		hotbar_label.text = "Increase Hotbar"
	_set_button_cost(hotbar_button, upgrade["cost"])


func _update_map_ui() -> void:
	if map_upgrade_index >= MAP_UPGRADES.size():
		if map_label != null:
			map_label.text = "Map Unlocked"
		_set_button_max(map_button)
		return

	var upgrade: Dictionary = MAP_UPGRADES[map_upgrade_index]
	if map_label != null:
		map_label.text = "Unlock Map [ m ]"
	_set_button_cost(map_button, upgrade["cost"])


func _set_button_cost(button: Button, cost: int) -> void:
	if button == null:
		return

	button.disabled = false
	button.text = str(cost)


func _set_button_max(button: Button) -> void:
	if button == null:
		return

	button.disabled = true
	button.text = "Max"


func _spend_stars(cost: int) -> bool:
	var score := _get_player_score()
	if score == null:
		return false

	return score.spend_stars(cost)


func _get_player_score() -> PlayerScore:
	if nearby_player == null:
		return null

	return nearby_player.get_node_or_null("PlayerScore") as PlayerScore


func _get_player_inventory() -> PlayerInventory:
	if nearby_player == null:
		return null

	return nearby_player.get_node_or_null("PlayerInventory") as PlayerInventory


func _get_map_controller() -> Node:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return null

	return current_scene.get_node_or_null("MapViewController")


func _apply_speed_multiplier(player: CharacterBody3D, multiplier: float) -> void:
	if not player.has_meta("base_walk_speed"):
		player.set_meta("base_walk_speed", player.get("walk_speed"))
	if not player.has_meta("base_run_speed"):
		player.set_meta("base_run_speed", player.get("run_speed"))

	player.set("walk_speed", float(player.get_meta("base_walk_speed")) * multiplier)
	player.set("run_speed", float(player.get_meta("base_run_speed")) * multiplier)


func _start_wave_loop() -> void:
	while is_inside_tree():
		await get_tree().create_timer(wave_interval).timeout

		if not is_inside_tree() or animation_player == null:
			return

		if animation_player.has_animation(wave_animation):
			animation_player.play(wave_animation)


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == wave_animation and animation_player.has_animation(idle_animation):
		animation_player.play(idle_animation)
