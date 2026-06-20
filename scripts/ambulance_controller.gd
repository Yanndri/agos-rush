extends CharacterBody3D

@export var acceleration := 10.0
@export var reverse_acceleration := 7.0
@export var max_forward_speed := 11.0
@export var max_reverse_speed := 5.0
@export var brake_force := 18.0
@export var coast_drag := 5.0
@export var steer_speed := 2.2
@export var gravity := 18.0
@export var exit_offset := Vector3(2.4, 0.0, 0.0)

@onready var driver_area: Area3D = $DriverArea

var drive_speed := 0.0
var nearby_player: CharacterBody3D
var driver: CharacterBody3D
var driver_collision_layer := 0
var driver_collision_mask := 0


func _ready() -> void:
	driver_area.body_entered.connect(_on_driver_area_body_entered)
	driver_area.body_exited.connect(_on_driver_area_body_exited)


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	if event.echo or not event.pressed:
		return
	if event.keycode != KEY_E:
		return

	if driver != null and _is_local_player(driver):
		exit_vehicle()
	elif driver == null and nearby_player != null and _is_local_player(nearby_player):
		enter_vehicle(nearby_player)


func _physics_process(delta: float) -> void:
	if driver == null:
		drive_speed = move_toward(drive_speed, 0.0, coast_drag * delta)
		_apply_gravity(delta)
		move_and_slide()
		return

	var throttle := int(Input.is_key_pressed(KEY_W)) - int(Input.is_key_pressed(KEY_S))
	var steering := int(Input.is_key_pressed(KEY_A)) - int(Input.is_key_pressed(KEY_D))
	var braking := Input.is_key_pressed(KEY_SPACE)

	if throttle > 0:
		drive_speed = move_toward(drive_speed, max_forward_speed, acceleration * delta)
	elif throttle < 0:
		drive_speed = move_toward(drive_speed, -max_reverse_speed, reverse_acceleration * delta)
	elif braking:
		drive_speed = move_toward(drive_speed, 0.0, brake_force * delta)
	else:
		drive_speed = move_toward(drive_speed, 0.0, coast_drag * delta)

	if abs(drive_speed) > 0.1 and steering != 0:
		var reverse_turn_multiplier := -1.0 if drive_speed < 0.0 else 1.0
		rotate_y(steering * steer_speed * reverse_turn_multiplier * delta)

	var forward := -global_basis.z
	velocity.x = forward.x * drive_speed
	velocity.z = forward.z * drive_speed
	_apply_gravity(delta)
	move_and_slide()

	if driver != null:
		driver.global_position = global_position + Vector3.UP * 0.5


func enter_vehicle(player: CharacterBody3D) -> void:
	driver = player
	nearby_player = null
	driver_collision_layer = player.collision_layer
	driver_collision_mask = player.collision_mask
	player.collision_layer = 0
	player.collision_mask = 0
	player.visible = false
	player.set("is_driving_vehicle", true)


func exit_vehicle() -> void:
	if driver == null:
		return

	var player := driver
	driver = null
	player.visible = true
	player.collision_layer = driver_collision_layer
	player.collision_mask = driver_collision_mask
	player.global_position = global_position + global_basis * exit_offset
	player.set("is_driving_vehicle", false)


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0


func _on_driver_area_body_entered(body: Node3D) -> void:
	var player := body as CharacterBody3D
	if player == null or not player.is_in_group("players"):
		return
	if not _is_local_player(player):
		return
	nearby_player = player


func _on_driver_area_body_exited(body: Node3D) -> void:
	if body == nearby_player:
		nearby_player = null


func _is_local_player(player: CharacterBody3D) -> bool:
	if multiplayer.multiplayer_peer == null:
		return true
	return player.is_multiplayer_authority()