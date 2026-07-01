extends CharacterBody3D

@export var walk_speed := 3.5
@export var run_speed := 6.0
@export var jump_velocity := 5.0
@export var low_jump_velocity_multiplier := 0.45
@export var jump_buffer_time := 0.15
@export var gravity := 18.0
@export var turn_speed := 8.0
@export var land_animation_time := 0.25
@export var model_yaw_offset_degrees := 180.0
@export var move_left_action := "move_left"
@export var move_right_action := "move_right"
@export var move_up_action := "move_up"
@export var move_down_action := "move_down"
@export var dialogue_container_path: NodePath = NodePath("PlayerUI/DialogueContainer")
@export var dialogue_label_path: NodePath = NodePath("PlayerUI/DialogueContainer/VBoxContainer/MarginContainer/DialogueLabel")
@export var dialogue_type_interval := 0.025
@export var dialogue_hold_time := 1.0
@export var dialogue_show_tween_time := 0.18
@export var dialogue_hide_tween_time := 0.18

@onready var animation_tree: AnimationTree = $PlayerModel/AnimationTree
@onready var animation_playback: AnimationNodeStateMachinePlayback = animation_tree.get("parameters/playback")
@onready var character_armature: Node3D = $PlayerModel/CharacterArmature
@onready var camera: Camera3D = $PlayerModel/CameraPivot/Camera3D
@onready var dialogue_container: CanvasItem = get_node_or_null(dialogue_container_path) as CanvasItem
@onready var dialogue_label: Label = get_node_or_null(dialogue_label_path) as Label

var last_animation: StringName = &"Idle"

var was_on_floor_last_frame := true
var land_time_left := 0.0

var was_jump_key_down := false
var jump_just_started := false
var jump_buffer_left := 0.0
var jump_cut_applied := false
var dialogue_message_id := 0
var dialogue_tween: Tween
var dialogue_start_position := Vector2.ZERO



var is_driving_vehicle := false
func _ready() -> void:
	if dialogue_container != null:
		dialogue_start_position = dialogue_container.position
	_hide_dialogue()
	visible = true
	animation_tree.active = true
	camera.current = false
	call_deferred("_update_local_camera")
	_play_animation(&"Idle")


func _update_local_camera() -> void:
	camera.current = is_multiplayer_authority()

func _process(_delta: float) -> void:
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

	var jump_key_down := Input.is_key_pressed(KEY_SPACE)
	var jump_pressed := jump_key_down and not was_jump_key_down
	was_jump_key_down = jump_key_down
	if jump_key_down:
		jump_buffer_left = jump_buffer_time
	else:
		jump_buffer_left = max(jump_buffer_left - delta, 0.0)
		if velocity.y > 0.0 and not jump_cut_applied:
			velocity.y = min(velocity.y, jump_velocity * low_jump_velocity_multiplier)
			jump_cut_applied = true

	velocity.x = direction.x * current_speed
	velocity.z = direction.z * current_speed

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

	move_and_slide()

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
	velocity.y = jump_velocity
	jump_buffer_left = 0.0
	jump_just_started = true
	jump_cut_applied = false
	land_time_left = 0.0

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

	for index in message.length():
		if current_message_id != dialogue_message_id:
			return
		dialogue_label.text = message.substr(0, index + 1)
		await get_tree().create_timer(dialogue_type_interval).timeout

	await get_tree().create_timer(dialogue_hold_time).timeout

	if current_message_id == dialogue_message_id:
		await _hide_dialogue_with_tween()


func _hide_dialogue() -> void:
	if dialogue_label != null:
		dialogue_label.text = ""
	if dialogue_container != null:
		dialogue_container.visible = false
		dialogue_container.modulate.a = 0.0
		dialogue_container.scale = Vector2.ONE
		dialogue_container.position = dialogue_start_position
func _show_dialogue_panel() -> void:
	if dialogue_container == null:
		return

	_kill_dialogue_tween()
	dialogue_container.visible = true
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