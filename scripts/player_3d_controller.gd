extends CharacterBody3D

@export var walk_speed := 3.5
@export var run_speed := 6.0
@export var jump_velocity := 5.0
@export var gravity := 18.0
@export var turn_speed := 3.0
@export var mouse_sensitivity := 0.0025
@export var invert_mouse_y := true
@export var min_camera_pitch := -15.0
@export var max_camera_pitch := 65.0
@export var camera_path: NodePath = ^"CameraPivot/Camera3D"
@export var camera_pivot_path: NodePath = ^"CameraPivot"
@export var camera_look_height := 1.0

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var camera: Camera3D = get_node_or_null(camera_path)
@onready var camera_pivot: Node3D = get_node_or_null(camera_pivot_path)

var jump_animation_time_left := 0.0
var camera_pitch := 0.0
var camera_yaw := 0.0

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if camera_pivot:
		camera_pitch = camera_pivot.rotation.x
		camera_yaw = rotation.y + camera_pivot.rotation.y
		_apply_camera_orbit()
	_play_animation("Idle")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if event.pressed else Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_rotate_camera(event.relative)

func _physics_process(delta: float) -> void:
	jump_animation_time_left = max(jump_animation_time_left - delta, 0.0)
	var input_dir := Vector2.ZERO
	input_dir.x = int(Input.is_key_pressed(KEY_D)) - int(Input.is_key_pressed(KEY_A))
	input_dir.y = int(Input.is_key_pressed(KEY_S)) - int(Input.is_key_pressed(KEY_W))
	input_dir = input_dir.normalized()

	var direction := _get_camera_relative_direction(input_dir)
	var is_running := Input.is_key_pressed(KEY_SHIFT)
	var current_speed := run_speed if is_running else walk_speed

	velocity.x = direction.x * current_speed
	velocity.z = direction.z * current_speed

	if not is_on_floor():
		velocity.y -= gravity * delta
	elif Input.is_key_pressed(KEY_SPACE):
		velocity.y = jump_velocity
		_start_jump_animation_lock()

	if direction != Vector3.ZERO:
		var target_y := atan2(-direction.x, -direction.z)
		rotation.y = lerp_angle(rotation.y, target_y, min(turn_speed * delta, 1.0))

	move_and_slide()
	_apply_camera_orbit()
	_update_animation(input_dir, is_running)

func _rotate_camera(mouse_delta: Vector2) -> void:
	camera_yaw -= mouse_delta.x * mouse_sensitivity
	var pitch_delta := mouse_delta.y if invert_mouse_y else -mouse_delta.y
	camera_pitch = clamp(
		camera_pitch + pitch_delta * mouse_sensitivity,
		deg_to_rad(min_camera_pitch),
		deg_to_rad(max_camera_pitch)
	)
	_apply_camera_orbit()

func _apply_camera_orbit() -> void:
	if camera_pivot:
		camera_pivot.rotation.x = camera_pitch
		camera_pivot.rotation.y = camera_yaw - rotation.y
	if camera:
		camera.look_at(global_position + Vector3.UP * camera_look_height, Vector3.UP)

func _get_camera_relative_direction(input_dir: Vector2) -> Vector3:
	if input_dir == Vector2.ZERO:
		return Vector3.ZERO
	if not camera:
		return Vector3(input_dir.x, 0.0, input_dir.y).normalized()
	var forward := -camera.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := camera.global_basis.x
	right.y = 0.0
	right = right.normalized()
	return (right * input_dir.x + forward * -input_dir.y).normalized()

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

func _play_animation(animation_name: StringName) -> void:
	if animation_player.current_animation == animation_name:
		return
	if animation_player.has_animation(animation_name):
		animation_player.play(animation_name)
