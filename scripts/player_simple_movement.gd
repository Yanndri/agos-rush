extends CharacterBody3D

@export var walk_speed := 3.5
@export var run_speed := 6.0
@export var jump_velocity := 5.0
@export var gravity := 18.0
@export var turn_speed := 8.0
@export var move_left_action := "move_left"
@export var move_right_action := "move_right"
@export var move_up_action := "move_up"
@export var move_down_action := "move_down"
@export var jump_action := "jump"

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var model_pivot: Node3D = $ModelPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D

var animation_playback: AnimationNodeStateMachinePlayback
var jump_animation_time_left := 0.0
var last_animation: StringName = &"Idle"

func _ready() -> void:
	camera.current = is_multiplayer_authority()
	animation_tree.active = true
	animation_playback = animation_tree.get("parameters/playback")
	_play_animation("Idle")

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return

	jump_animation_time_left = max(jump_animation_time_left - delta, 0.0)

	var input_dir := Vector2.ZERO
	input_dir.x = int(Input.is_action_pressed(move_right_action)) - int(Input.is_action_pressed(move_left_action))
	input_dir.y = int(Input.is_action_pressed(move_down_action)) - int(Input.is_action_pressed(move_up_action))
	input_dir = input_dir.normalized()

	var direction := Vector3(input_dir.x, 0.0, input_dir.y).normalized()
	var is_running := Input.is_key_pressed(KEY_SHIFT)
	var current_speed := run_speed if is_running else walk_speed

	velocity.x = direction.x * current_speed
	velocity.z = direction.z * current_speed

	if not is_on_floor():
		velocity.y -= gravity * delta
	elif _is_jump_pressed():
		velocity.y = jump_velocity
		_start_jump_animation_lock()
	else:
		velocity.y = 0.0

	if direction != Vector3.ZERO:
		var target_y := atan2(-direction.x, -direction.z) + PI
		model_pivot.rotation.y = lerp_angle(model_pivot.rotation.y, target_y, min(turn_speed * delta, 1.0))

	move_and_slide()
	_update_animation(input_dir, is_running)
	_sync_state.rpc(global_transform, model_pivot.rotation.y, last_animation)

@rpc("any_peer", "unreliable")
func _sync_state(remote_transform: Transform3D, remote_model_y: float, remote_animation: StringName) -> void:
	if is_multiplayer_authority():
		return
	global_transform = remote_transform
	model_pivot.rotation.y = remote_model_y
	_play_animation(remote_animation)

func _update_animation(input_dir: Vector2, is_running: bool) -> void:
	if jump_animation_time_left > 0.0:
		_play_animation("Jump")
	elif input_dir != Vector2.ZERO:
		_play_animation("Running" if is_running else "Walk")
	else:
		_play_animation("Idle")

func _start_jump_animation_lock() -> void:
	if not animation_player.has_animation("Jump"):
		return
	var jump_animation := animation_player.get_animation("Jump")
	jump_animation_time_left = jump_animation.length
	_play_animation("Jump")


func _is_jump_pressed() -> bool:
	if not get_tree().get_nodes_in_group("construction_minigame_active").is_empty():
		return false

	return InputMap.has_action(jump_action) and Input.is_action_pressed(jump_action)


func _play_animation(animation_name: StringName) -> void:
	last_animation = animation_name
	if animation_playback and animation_playback.get_current_node() != String(animation_name):
		animation_playback.travel(animation_name)
