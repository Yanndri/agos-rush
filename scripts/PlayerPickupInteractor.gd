extends Node
class_name PlayerPickupInteractor

@export var interact_key := KEY_E
@export var use_key := KEY_F

@export var hand_path: NodePath

var nearby_pickable: PickableItem
var held_item: PickableItem
var player: CharacterBody3D


func _ready() -> void:
	player = get_parent() as CharacterBody3D


func _unhandled_input(event: InputEvent) -> void:
	if not is_local_player():
		return

	if not event is InputEventKey:
		return

	if not event.pressed or event.echo:
		return

	if event.keycode == interact_key:
		try_pick_up()

	if event.keycode == use_key:
		try_use_item()


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


func is_local_player() -> bool:
	if player == null:
		return false

	if multiplayer.multiplayer_peer == null:
		return true

	return player.is_multiplayer_authority()
