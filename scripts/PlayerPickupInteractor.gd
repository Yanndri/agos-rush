extends Node
class_name PlayerPickupInteractor

@export var interact_action := "interact"
@export var use_action := ""
@export var drop_action := "drop"
@export var drop_hold_duration := 0.0

@export var hand_path: NodePath

var nearby_pickable: PickableItem
var held_item: PickableItem
var player: CharacterBody3D
var drop_hold_left := 0.0
var is_holding_drop := false


func _ready() -> void:
	player = get_parent() as CharacterBody3D


func _process(delta: float) -> void:
	if not is_local_player():
		return
	if not is_holding_drop:
		return
	if held_item == null:
		_cancel_drop_hold()
		return
	drop_hold_left -= delta
	if drop_hold_left <= 0.0:
		_cancel_drop_hold()
		try_drop_item()


func _unhandled_input(event: InputEvent) -> void:
	if not is_local_player():
		return

	if event is InputEventKey and event.echo:
		return

	if event.is_action_pressed(drop_action):
		_start_drop_hold()
		return

	if event.is_action_released(drop_action):
		_cancel_drop_hold()
		return

	if event.is_action_pressed(interact_action) and nearby_pickable != null:
		get_viewport().set_input_as_handled()
		try_pick_up()
		return

	if not use_action.is_empty() and event.is_action_pressed(use_action) and held_item != null:
		get_viewport().set_input_as_handled()
		try_use_item()
		return


func _start_drop_hold() -> void:
	if held_item == null:
		return
	is_holding_drop = true
	drop_hold_left = drop_hold_duration


func _cancel_drop_hold() -> void:
	is_holding_drop = false
	drop_hold_left = 0.0


func try_pick_up() -> void:
	if nearby_pickable == null:
		return

	if held_item != null:
		print("Already holding an item.")
		return

	var hand := get_node_or_null(hand_path) as Node3D

	if hand == null:
		push_warning("Hand path is wrong: " + str(hand_path))
		return

	nearby_pickable.request_pick_up(player)


func try_use_item() -> void:
	if held_item == null:
		return

	held_item.use_item(player)


func try_drop_item() -> void:
	if held_item == null:
		return
	held_item.request_drop(player)


func clear_held_item(item: PickableItem) -> void:
	if held_item == item:
		held_item = null


func is_local_player() -> bool:
	if player == null:
		return false

	if multiplayer.multiplayer_peer == null:
		return true

	return player.is_multiplayer_authority()
