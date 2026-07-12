extends CharacterBody3D

@export var dialogue_sfx : AudioStream = preload("res://Music/36505577-pop-up-notify-smooth-modern-332448.mp3")

@export var walk_speed := 3.5
@export var run_speed := 6.0
@export var carrying_speed_multiplier := 0.5
@export var water_speed_multiplier := 0.45
@export var water_jump_multiplier := 0.35
@export var jump_velocity := 5.0
@export var low_jump_velocity_multiplier := 0.45
@export var jump_buffer_time := 0.15
@export var gravity := 18.0
@export var turn_speed := 8.0
@export var land_animation_time := 0.25
@export var max_step_height := 0.35
@export var model_yaw_offset_degrees := 180.0
@export var move_left_action := "move_left"
@export var move_right_action := "move_right"
@export var move_up_action := "move_up"
@export var move_down_action := "move_down"
@export var jump_action := "jump"
@export var player_ui_path: NodePath = NodePath("PlayerUI")
@export var dialogue_container_path: NodePath = NodePath("PlayerUI/DialogueContainer")
@export var dialogue_label_path: NodePath = NodePath("PlayerUI/DialogueContainer/VBoxContainer/MarginContainer/DialogueLabel")
@export var dialogue_next_ui_path: NodePath = NodePath("PlayerUI/DialogueContainer/VBoxContainer/MarginContainer/NextUI")
@export var dialogue_type_interval := 0.025
@export var dialogue_hold_time := 1.0
@export var dialogue_show_tween_time := 0.18
@export var dialogue_hide_tween_time := 0.18

@onready var animation_tree: AnimationTree = $PlayerModel/AnimationTree
@onready var animation_playback: AnimationNodeStateMachinePlayback = animation_tree.get("parameters/playback")
@onready var character_armature: Node3D = $PlayerModel/CharacterArmature
@onready var camera: Camera3D = $PlayerModel/CameraPivot/Camera3D
@onready var player_ui: CanvasItem = get_node_or_null(player_ui_path) as CanvasItem
@onready var dialogue_container: Control = get_node_or_null(dialogue_container_path) as Control
@onready var dialogue_label: Label = get_node_or_null(dialogue_label_path) as Label
@onready var dialogue_next_ui: CanvasItem = get_node_or_null(dialogue_next_ui_path) as CanvasItem

var last_animation: StringName = &"Idle"

var was_on_floor_last_frame := true
var land_time_left := 0.0

var jump_just_started := false
var jump_buffer_left := 0.0
var jump_cut_applied := false
var dialogue_message_id := 0
var dialogue_tween: Tween
var dialogue_start_position := Vector2.ZERO
var can_close_dialogue := false
var dialogue_hiding := false
var map_view_active := false
var in_water := false
var water_current := Vector3.ZERO



var is_driving_vehicle := false
func _ready() -> void:
	add_to_group("players")
	if dialogue_container != null:
		dialogue_start_position = dialogue_container.position
		_connect_dialogue_gui_input(dialogue_container)
	_hide_dialogue()
	visible = true
	animation_tree.active = true
	camera.current = false
	_update_local_ui()
	call_deferred("_update_local_camera")
	_play_animation(&"Idle")


func _update_local_camera() -> void:
	camera.current = is_multiplayer_authority() and not map_view_active


func _update_local_ui() -> void:
	if player_ui != null:
		player_ui.visible = multiplayer.multiplayer_peer == null or is_multiplayer_authority()

func _process(_delta: float) -> void:
	_update_local_ui()

	if map_view_active:
		camera.current = false
		return

	if is_multiplayer_authority() and not camera.current:
		camera.current = true

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return

	if is_driving_vehicle:
		velocity = Vector3.ZERO
		_play_animation(&"Idle")
		return
	var input_dir := Vector2.ZERO
	input_dir.x = int(Input.is_action_pressed(move_right_action)) - int(Input.is_action_pressed(move_left_action))
	input_dir.y = int(Input.is_action_pressed(move_down_action)) - int(Input.is_action_pressed(move_up_action))
	input_dir = input_dir.normalized()

	var direction := _get_camera_relative_direction(input_dir)
	var is_running := Input.is_key_pressed(KEY_SHIFT)
	var current_speed := run_speed if is_running else walk_speed
	if is_carrying_resident():
		current_speed *= carrying_speed_multiplier
	if in_water:
		current_speed *= water_speed_multiplier

	var jump_key_down := InputMap.has_action(jump_action) and Input.is_action_pressed(jump_action) and not _is_construction_minigame_active()
	if jump_key_down:
		jump_buffer_left = jump_buffer_time
	else:
		jump_buffer_left = max(jump_buffer_left - delta, 0.0)
		if velocity.y > 0.0 and not jump_cut_applied:
			velocity.y = min(velocity.y, jump_velocity * low_jump_velocity_multiplier)
			jump_cut_applied = true

	velocity.x = direction.x * current_speed + water_current.x
	velocity.z = direction.z * current_speed + water_current.z

	if not is_on_floor():
		velocity.y -= gravity * delta
	elif jump_buffer_left > 0.0:
		_start_jump_from_buffer()
	else:
		velocity.y = 0.0

	if direction != Vector3.ZERO:
		var target_y := atan2(-direction.x, -direction.z) + deg_to_rad(model_yaw_offset_degrees)
		character_armature.rotation.y = lerp_angle(
			character_armature.rotation.y,
			target_y,
			min(turn_speed * delta, 1.0)
		)

	var was_grounded_before_move := is_on_floor()
	var horizontal_motion := Vector3(velocity.x, 0.0, velocity.z) * delta
	move_and_slide()
	_try_step_up(was_grounded_before_move, horizontal_motion)

	if is_on_floor() and not was_on_floor_last_frame:
		land_time_left = land_animation_time
		if jump_buffer_left > 0.0:
			_start_jump_from_buffer()

	_update_animation(input_dir, is_running, delta)
	was_on_floor_last_frame = is_on_floor()
	_sync_state.rpc(global_transform, character_armature.rotation.y, last_animation)

@rpc("any_peer", "unreliable")
func _sync_state(remote_transform: Transform3D, remote_model_y: float, remote_animation: StringName) -> void:
	if is_multiplayer_authority():
		return

	global_transform = remote_transform
	character_armature.rotation.y = remote_model_y
	_play_animation(remote_animation)


func _start_jump_from_buffer() -> void:
	velocity.y = jump_velocity * water_jump_multiplier if in_water else jump_velocity
	jump_buffer_left = 0.0
	jump_just_started = true
	jump_cut_applied = false
	land_time_left = 0.0


func _try_step_up(was_grounded_before_move: bool, horizontal_motion: Vector3) -> void:
	if max_step_height <= 0.0:
		return
	if not was_grounded_before_move or not is_on_wall():
		return
	if horizontal_motion.length_squared() <= 0.0001:
		return

	var original_transform := global_transform
	var step_up := Vector3.UP * max_step_height
	var step_forward = horizontal_motion.normalized() * clamp(horizontal_motion.length(), 0.05, 0.15)
	var raised_transform := original_transform.translated(step_up)
	var stepped_transform := raised_transform.translated(step_forward)

	if test_move(original_transform, step_up):
		return
	if test_move(raised_transform, step_forward):
		return
	if not test_move(stepped_transform, Vector3.DOWN * (max_step_height + 0.08)):
		return

	global_transform = stepped_transform
	velocity.y = 0.0
	apply_floor_snap()


func _is_construction_minigame_active() -> bool:
	return not get_tree().get_nodes_in_group("construction_minigame_active").is_empty()


func _get_camera_relative_direction(input_dir: Vector2) -> Vector3:
	if input_dir == Vector2.ZERO:
		return Vector3.ZERO

	var forward := -camera.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()

	var right := camera.global_basis.x
	right.y = 0.0
	right = right.normalized()

	return (right * input_dir.x + forward * -input_dir.y).normalized()


func is_carrying_resident() -> bool:
	for child in get_children():
		if child.has_method("is_carried_resident") and child.is_carried_resident():
			return true

	return false


func _update_animation(input_dir: Vector2, is_running: bool, delta: float) -> void:
	# Jump start should play once, not every frame.
	if jump_just_started:
		jump_just_started = false
		_play_animation(&"Jump")
		return

	# Landing animation only while actually on floor.
	if is_on_floor() and land_time_left > 0.0:
		land_time_left = max(land_time_left - delta, 0.0)
		_play_animation(&"Jump_Land")
		return

	# Air animations.
	if not is_on_floor():
		if velocity.y <= 0.0:
			_play_animation(&"Jump_Idle")
		else:
			# Keep Jump while going upward.
			# Do not keep restarting it.
			var current_node := ""
			if animation_playback:
				current_node = animation_playback.get_current_node()

			if current_node != "Jump" and current_node != "Jump_Idle":
				_play_animation(&"Jump")

		return

	# Ground movement animations.
	if input_dir != Vector2.ZERO:
		if is_running:
			_play_animation(&"Run")
		else:
			_play_animation(&"Walk")
	else:
		_play_animation(&"Idle")


func _play_animation(animation_name: StringName) -> void:
	if not animation_playback:
		return

	var current_node := animation_playback.get_current_node()

	if current_node != String(animation_name):
		animation_playback.travel(animation_name)

	last_animation = animation_name

func show_dialogue_message(message: String) -> void:
	if not is_multiplayer_authority():
		return
	if dialogue_container == null or dialogue_label == null:
		return

	dialogue_message_id += 1
	var current_message_id := dialogue_message_id
	_show_dialogue_panel()
	dialogue_label.text = ""
	_set_dialogue_next_visible(false)
	can_close_dialogue = false

	for index in message.length():
		if current_message_id != dialogue_message_id:
			return
		dialogue_label.text = message.substr(0, index + 1)
		await get_tree().create_timer(dialogue_type_interval).timeout

	await get_tree().create_timer(dialogue_hold_time).timeout

	if current_message_id == dialogue_message_id:
		can_close_dialogue = true
		_set_dialogue_next_visible(true)


func set_map_view_active(value: bool) -> void:
	map_view_active = value
	if camera != null:
		camera.current = is_multiplayer_authority() and not map_view_active


func set_water_state(value: bool, _surface_y: float = 0.0, current_velocity: Vector3 = Vector3.ZERO) -> void:
	in_water = value
	water_current = current_velocity if value else Vector3.ZERO


func _hide_dialogue() -> void:
	can_close_dialogue = false
	dialogue_hiding = false
	if dialogue_label != null:
		dialogue_label.text = ""
	_set_dialogue_next_visible(false)
	if dialogue_container != null:
		dialogue_container.visible = false
		dialogue_container.modulate.a = 0.0
		dialogue_container.scale = Vector2.ONE
		dialogue_container.position = dialogue_start_position
		dialogue_container.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _set_dialogue_next_visible(value: bool) -> void:
	if dialogue_next_ui != null:
		dialogue_next_ui.visible = value


func _connect_dialogue_gui_input(control: Control) -> void:
	if not control.gui_input.is_connected(_on_dialogue_container_gui_input):
		control.gui_input.connect(_on_dialogue_container_gui_input)

	for child in control.get_children():
		var child_control := child as Control
		if child_control != null:
			_connect_dialogue_gui_input(child_control)


func _on_dialogue_container_gui_input(event: InputEvent) -> void:
	if not can_close_dialogue:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_request_close_dialogue()
	elif event is InputEventScreenTouch and event.pressed:
		_request_close_dialogue()


func _request_close_dialogue() -> void:
	if dialogue_hiding or not can_close_dialogue:
		return

	dialogue_hiding = true
	get_viewport().set_input_as_handled()
	_kill_dialogue_tween()
	_hide_dialogue()


func _show_dialogue_panel() -> void:
	if dialogue_container == null:
		return

	_kill_dialogue_tween()
	can_close_dialogue = false
	dialogue_hiding = false
	_set_dialogue_next_visible(false)
	if dialogue_sfx != null:
		AudioUtility.play_sfx(self, dialogue_sfx)
	dialogue_container.visible = true
	dialogue_container.mouse_filter = Control.MOUSE_FILTER_STOP
	dialogue_container.modulate.a = 0.0
	dialogue_container.scale = Vector2(0.96, 0.96)
	dialogue_container.position = dialogue_start_position + Vector2(0.0, 12.0)

	dialogue_tween = create_tween()
	dialogue_tween.set_parallel(true)
	dialogue_tween.tween_property(dialogue_container, "modulate:a", 1.0, dialogue_show_tween_time)
	dialogue_tween.tween_property(dialogue_container, "scale", Vector2.ONE, dialogue_show_tween_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	dialogue_tween.tween_property(dialogue_container, "position", dialogue_start_position, dialogue_show_tween_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _hide_dialogue_with_tween() -> void:
	if dialogue_container == null:
		return

	_kill_dialogue_tween()
	can_close_dialogue = false
	_set_dialogue_next_visible(false)
	dialogue_tween = create_tween()
	dialogue_tween.set_parallel(true)
	dialogue_tween.tween_property(dialogue_container, "modulate:a", 0.0, dialogue_hide_tween_time)
	dialogue_tween.tween_property(dialogue_container, "scale", Vector2(0.96, 0.96), dialogue_hide_tween_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	dialogue_tween.tween_property(dialogue_container, "position", dialogue_start_position + Vector2(0.0, 8.0), dialogue_hide_tween_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await dialogue_tween.finished
	_hide_dialogue()


func _kill_dialogue_tween() -> void:
	if dialogue_tween != null:
		dialogue_tween.kill()
		dialogue_tween = null
