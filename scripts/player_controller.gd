extends CharacterBody3D

@export var speed := 4.0
@export var jump_velocity := 5.0
@export var gravity := 18.0
@export var water_speed_multiplier := 0.45
@export var water_gravity_multiplier := 0.35
@export var buoyancy := 4.5
@export var dash_speed := 9.0
@export var dash_duration := 0.18
@export var dash_cooldown := 0.45

@onready var animation_tree: AnimationTree = $AnimationTree

var state_machine: AnimationNodeStateMachinePlayback
var last_blend_position := Vector2(0, -1)
var in_water := false
var water_surface_y := -INF
var water_current := Vector3.ZERO
var dash_time_left := 0.0
var dash_cooldown_left := 0.0
var dash_direction := Vector3.ZERO
var has_jump_state := false
var has_dash_state := false

func _ready() -> void:
	animation_tree.active = true
	state_machine = animation_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
	var state_root := animation_tree.tree_root as AnimationNodeStateMachine
	if state_root:
		has_jump_state = state_root.has_node("Jump")
		has_dash_state = state_root.has_node("Dash")
	_set_blend_position(last_blend_position)
	if state_machine:
		state_machine.travel("Idle")

func _physics_process(delta: float) -> void:
	var input_dir := Vector2.ZERO
	input_dir.x = int(Input.is_key_pressed(KEY_D)) - int(Input.is_key_pressed(KEY_A))
	input_dir.y = int(Input.is_key_pressed(KEY_S)) - int(Input.is_key_pressed(KEY_W))
	input_dir = input_dir.normalized()

	if input_dir != Vector2.ZERO:
		last_blend_position = Vector2(input_dir.x, -input_dir.y)

	var direction := Vector3(input_dir.x, 0.0, input_dir.y)
	_update_dash(delta, direction)

	var current_speed := speed
	if in_water:
		current_speed *= water_speed_multiplier

	if dash_time_left > 0.0:
		velocity.x = dash_direction.x * dash_speed + water_current.x
		velocity.z = dash_direction.z * dash_speed + water_current.z
	else:
		velocity.x = direction.x * current_speed + water_current.x
		velocity.z = direction.z * current_speed + water_current.z

	if in_water:
		velocity.y -= gravity * water_gravity_multiplier * delta
		if global_position.y < water_surface_y:
			velocity.y += buoyancy * delta
		if Input.is_key_pressed(KEY_SPACE):
			velocity.y = max(velocity.y, jump_velocity * 0.55)
	elif not is_on_floor():
		velocity.y -= gravity * delta
	elif Input.is_key_pressed(KEY_SPACE):
		velocity.y = jump_velocity

	move_and_slide()
	_update_animation_tree(input_dir)

func _update_dash(delta: float, direction: Vector3) -> void:
	dash_cooldown_left = max(dash_cooldown_left - delta, 0.0)
	dash_time_left = max(dash_time_left - delta, 0.0)

	if Input.is_key_pressed(KEY_SHIFT) and dash_cooldown_left <= 0.0 and dash_time_left <= 0.0:
		dash_direction = direction
		if dash_direction == Vector3.ZERO:
			dash_direction = Vector3(last_blend_position.x, 0.0, -last_blend_position.y).normalized()
		dash_time_left = dash_duration
		dash_cooldown_left = dash_cooldown

func set_water_state(value: bool, surface_y: float, current_velocity: Vector3 = Vector3.ZERO) -> void:
	in_water = value
	water_surface_y = surface_y
	water_current = current_velocity if value else Vector3.ZERO

func _update_animation_tree(input_dir: Vector2) -> void:
	_set_blend_position(last_blend_position)
	if not state_machine:
		return

	if dash_time_left > 0.0 and has_dash_state:
		state_machine.travel("Dash")
	elif not is_on_floor() and has_jump_state:
		state_machine.travel("Jump")
	elif input_dir != Vector2.ZERO:
		state_machine.travel("Walk")
	else:
		state_machine.travel("Idle")

func _set_blend_position(blend_position: Vector2) -> void:
	animation_tree.set("parameters/Idle/blend_position", blend_position)
	animation_tree.set("parameters/Walk/blend_position", blend_position)
	if has_jump_state:
		animation_tree.set("parameters/Jump/blend_position", blend_position)
	if has_dash_state:
		animation_tree.set("parameters/Dash/blend_position", blend_position)
