extends Node3D

@export var toggle_action := "map"
@export var fallback_toggle_action := "map_view"
@export var secondary_fallback_toggle_action := "view_map"
@export var map_camera_path: NodePath = NodePath("MapCamera3D")
@export var default_effect_path: NodePath = NodePath("../VHSCanvas/FilterCanvas/DotDitherEffect")
@export var map_effect_path: NodePath = NodePath("../VHSCanvas/FilterCanvas/VHSEffect")
@export var follow_local_player := true
@export var unlocked := false
@export var map_height := 60.0
@export var map_size := 40.0

var map_active := false

@onready var map_camera: Camera3D = get_node_or_null(map_camera_path) as Camera3D


func _ready() -> void:
	process_priority = 100

	if map_camera == null:
		push_warning("MapViewController is missing its map camera.")
		return

	map_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	map_camera.size = map_size
	map_camera.position = Vector3.ZERO
	map_camera.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	map_camera.current = false


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return

	if not unlocked:
		return

	if _is_toggle_pressed(event):
		_set_map_active(not map_active)
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if map_active:
		_update_map_camera()


func _update_map_camera() -> void:
	if map_camera == null:
		return

	if not map_active:
		map_camera.current = false
		return

	var target_position := global_position
	if follow_local_player:
		var player := _get_local_player()
		if player != null:
			target_position = player.global_position

	global_position = Vector3(target_position.x, map_height, target_position.z)
	rotation = Vector3.ZERO
	map_camera.position = Vector3.ZERO
	map_camera.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	map_camera.size = map_size
	map_camera.current = true


func _set_map_active(value: bool) -> void:
	map_active = value
	_update_player_camera(not map_active)
	_update_map_effects()
	_update_map_camera()


func unlock_map() -> void:
	unlocked = true


func _update_map_effects() -> void:
	var default_effect := get_node_or_null(default_effect_path) as CanvasItem
	var map_effect := get_node_or_null(map_effect_path) as CanvasItem

	if default_effect != null:
		default_effect.visible = not map_active

	if map_effect != null:
		map_effect.visible = map_active


func _is_toggle_pressed(event: InputEvent) -> bool:
	if InputMap.has_action(toggle_action) and event.is_action_pressed(toggle_action):
		return true

	if InputMap.has_action(fallback_toggle_action) and event.is_action_pressed(fallback_toggle_action):
		return true

	if InputMap.has_action(secondary_fallback_toggle_action) and event.is_action_pressed(secondary_fallback_toggle_action):
		return true

	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_M:
		return true

	return false


func _update_player_camera(enabled: bool) -> void:
	var player := _get_local_player()
	if player == null:
		return

	if player.has_method("set_map_view_active"):
		player.set_map_view_active(not enabled)
		return

	var player_camera := player.get_node_or_null("PlayerModel/CameraPivot/Camera3D") as Camera3D
	if player_camera != null:
		player_camera.current = enabled


func _get_local_player() -> Node3D:
	for player in get_tree().get_nodes_in_group("players"):
		var node := player as Node3D
		if node == null:
			continue

		if node.has_method("is_multiplayer_authority"):
			if multiplayer.multiplayer_peer != null and not node.is_multiplayer_authority():
				continue

		return node

	return null
