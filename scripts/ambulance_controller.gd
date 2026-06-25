extends CharacterBody3D

const TRANSPARENT_AMBULANCE_MATERIAL := preload("res://Themes/transparent_ambulance_material.tres")

@export var ambulance_owner := "Player1"
@export var acceleration := 10.0
@export var reverse_acceleration := 7.0
@export var max_forward_speed := 11.0
@export var max_reverse_speed := 5.0
@export var brake_force := 18.0
@export var coast_drag := 5.0
@export var steer_speed := 2.2
@export var gravity := 18.0
@export var exit_offset := Vector3(2.4, 0.0, 0.0)
@export var wheel_spin_speed := 2.0
@export var wheel_spin_axis := Vector3.UP
@export var max_wheel_steer_degrees := 35.0
@export var wheel_steer_speed := 12.0

@onready var driver_area: Area3D = $DriverArea
@onready var truck: MeshInstance3D = $"Model/Ambulance-Truck"
@onready var front_left_wheel: Node3D = $"Model/Ambulance-Truck/FrontWheels/Ambulance-Truck_TireFL"
@onready var front_right_wheel: Node3D = $"Model/Ambulance-Truck/FrontWheels/Ambulance-Truck_TireFR"
@onready var front_left_wheel_mesh: Node3D = $"Model/Ambulance-Truck/FrontWheels/Ambulance-Truck_TireFL/Ambulance-Truck_TireFL"
@onready var front_right_wheel_mesh: Node3D = $"Model/Ambulance-Truck/FrontWheels/Ambulance-Truck_TireFR/Ambulance-Truck_TireFR"
@onready var back_left_wheel_mesh: Node3D = $"Model/Ambulance-Truck/BackWheels/Ambulance-Truck_TireBL/Ambulance-Truck_TireBL"
@onready var back_right_wheel_mesh: Node3D = $"Model/Ambulance-Truck/BackWheels/Ambulance-Truck_TireBR/Ambulance-Truck_TireBR"

var wheel_steer_angle := 0.0
var front_left_base_rotation := Vector3.ZERO
var front_right_base_rotation := Vector3.ZERO
var drive_speed := 0.0
var nearby_player: CharacterBody3D
var driver: CharacterBody3D
var driver_collision_layer := 0
var driver_collision_mask := 0
var remote_driver_peer_id := 0
var normal_truck_material: Material
var last_owner_visual_state := ""


func _ready() -> void:
	normal_truck_material = truck.material_override
	_update_owner_material()
	front_left_base_rotation = front_left_wheel.rotation
	front_right_base_rotation = front_right_wheel.rotation
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


func _process(_delta: float) -> void:
	_update_owner_material()

func _physics_process(delta: float) -> void:
	if driver != null and not _is_local_player(driver):
		_spin_wheels(delta)
		return
	if driver == null:
		drive_speed = move_toward(drive_speed, 0.0, coast_drag * delta)
		_update_wheel_steering(0.0, delta)
		_spin_wheels(delta)
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

	_update_wheel_steering(float(steering), delta)

	if abs(drive_speed) > 0.1 and steering != 0:
		var reverse_turn_multiplier := -1.0 if drive_speed < 0.0 else 1.0
		rotate_y(steering * steer_speed * reverse_turn_multiplier * delta)

	var forward := -global_basis.x
	velocity.x = forward.x * drive_speed
	velocity.z = forward.z * drive_speed
	_spin_wheels(delta)
	_apply_gravity(delta)
	move_and_slide()

	if driver != null:
		driver.global_position = global_position + Vector3.UP * 0.5
		_sync_vehicle_state.rpc(global_transform, drive_speed, wheel_steer_angle)


func _update_owner_material() -> void:
	var owner_state := ambulance_owner + ":" + str(multiplayer.get_unique_id() if multiplayer.multiplayer_peer != null else 1)
	if owner_state == last_owner_visual_state:
		return

	last_owner_visual_state = owner_state
	if _is_owned_by_local_player():
		truck.material_override = normal_truck_material
	else:
		truck.material_override = TRANSPARENT_AMBULANCE_MATERIAL


func _is_owned_by_local_player() -> bool:
	if ambulance_owner.is_empty():
		return true
	if multiplayer.multiplayer_peer == null:
		return ambulance_owner == "1" or ambulance_owner == "Player1"
	return ambulance_owner == str(multiplayer.get_unique_id())

func _spin_wheels(delta: float) -> void:
	if abs(drive_speed) <= 0.01:
		return

	var spin_amount := drive_speed * wheel_spin_speed * delta
	var spin_axis := wheel_spin_axis.normalized()
	front_left_wheel_mesh.rotate_object_local(spin_axis, spin_amount)
	front_right_wheel_mesh.rotate_object_local(spin_axis, spin_amount)
	%BackWheels.rotate_object_local(spin_axis, spin_amount)


func _update_wheel_steering(steering: float, delta: float) -> void:
	var target_angle := deg_to_rad(max_wheel_steer_degrees) * steering
	wheel_steer_angle = lerp(wheel_steer_angle, target_angle, min(wheel_steer_speed * delta, 1.0))
	front_left_wheel.rotation = front_left_base_rotation + Vector3(0.0, 0.0, -wheel_steer_angle)
	front_right_wheel.rotation = front_right_base_rotation + Vector3(0.0, 0.0, -wheel_steer_angle)


func enter_vehicle(player: CharacterBody3D) -> void:
	if not _is_owner_player(player):
		_print_not_owner_interaction(player, "enter_vehicle")
		return
	_sync_driver_entered.rpc(int(player.name))


@rpc("any_peer", "call_local", "reliable")
func _sync_driver_entered(peer_id: int) -> void:
	var player := get_tree().current_scene.get_node_or_null(str(peer_id)) as CharacterBody3D
	if player == null:
		return
	driver = player
	remote_driver_peer_id = peer_id
	if nearby_player == player:
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

	_sync_driver_exited.rpc(int(driver.name), global_position + global_basis * exit_offset)


@rpc("any_peer", "call_local", "reliable")
func _sync_driver_exited(peer_id: int, exit_position: Vector3) -> void:
	var player := get_tree().current_scene.get_node_or_null(str(peer_id)) as CharacterBody3D
	if player == null:
		return
	if driver == player:
		driver = null
	remote_driver_peer_id = 0
	drive_speed = 0.0
	velocity.x = 0.0
	velocity.z = 0.0
	player.visible = true
	player.collision_layer = driver_collision_layer
	player.collision_mask = driver_collision_mask
	player.global_position = exit_position
	player.set("is_driving_vehicle", false)

@rpc("any_peer", "unreliable")
func _sync_vehicle_state(remote_transform: Transform3D, remote_drive_speed: float, remote_wheel_steer_angle: float) -> void:
	if driver != null and _is_local_player(driver):
		return

	global_transform = remote_transform
	drive_speed = remote_drive_speed
	wheel_steer_angle = remote_wheel_steer_angle
	front_left_wheel.rotation = front_left_base_rotation + Vector3(0.0, 0.0, -wheel_steer_angle)
	front_right_wheel.rotation = front_right_base_rotation + Vector3(0.0, 0.0, -wheel_steer_angle)

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
	if not _is_owner_player(player):
		_print_not_owner_interaction(player, "driver_area_entered")
		return
	nearby_player = player


func _on_driver_area_body_exited(body: Node3D) -> void:
	if body == nearby_player:
		nearby_player = null

func _print_not_owner_interaction(player: CharacterBody3D, where: String) -> void:
	var local_peer := 1
	if multiplayer.multiplayer_peer != null:
		local_peer = multiplayer.get_unique_id()
	print("AMBULANCE NOT OWNED | where=", where, " | ambulance=", name, " | ambulance_owner=", ambulance_owner, " | player=", player.name, " | local_peer=", local_peer)
func _is_owner_player(player: CharacterBody3D) -> bool:
	return ambulance_owner.is_empty() or ambulance_owner == str(player.name)

func _is_local_player(player: CharacterBody3D) -> bool:
	if multiplayer.multiplayer_peer == null:
		return true
	return player.is_multiplayer_authority()
