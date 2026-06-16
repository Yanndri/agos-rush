extends Node3D
class_name PickableItem

@export var held_position := Vector3.ZERO
@export var held_rotation_degrees := Vector3.ZERO
@export var held_scale := Vector3.ONE

@export var spin_when_available := true
@export var spin_speed_degrees := 90.0

@export var spin_node_path: NodePath = NodePath("Visual")

@onready var prompt_area: Area3D = $PromptArea
@onready var prompt: Label3D = $PromptArea/PromptLabel
@onready var spin_node: Node3D = get_node_or_null(spin_node_path) as Node3D

var picked_up := false
var holder: Node3D

var spin_node_start_transform: Transform3D


func _ready() -> void:
	prompt.visible = false

	if spin_node != null:
		spin_node_start_transform = spin_node.transform

	if not prompt_area.body_entered.is_connected(_on_prompt_area_body_entered):
		prompt_area.body_entered.connect(_on_prompt_area_body_entered)

	if not prompt_area.body_exited.is_connected(_on_prompt_area_body_exited):
		prompt_area.body_exited.connect(_on_prompt_area_body_exited)


func _process(delta: float) -> void:
	if picked_up:
		return

	if not spin_when_available:
		return

	if spin_node == null:
		return

	spin_node.rotate_y(deg_to_rad(spin_speed_degrees) * delta)


func request_pick_up(player: CharacterBody3D) -> void:
	if picked_up or player == null:
		return

	if multiplayer.multiplayer_peer == null:
		_apply_pick_up(player.name)
	elif multiplayer.is_server():
		_apply_pick_up.rpc(player.name)
	else:
		_request_pick_up.rpc_id(1, player.name)


@rpc("any_peer", "reliable")
func _request_pick_up(player_name: StringName) -> void:
	if not multiplayer.is_server():
		return

	_apply_pick_up.rpc(player_name)


@rpc("authority", "call_local", "reliable")
func _apply_pick_up(player_name: StringName) -> void:
	if picked_up:
		return

	var player := get_tree().current_scene.get_node_or_null(String(player_name)) as CharacterBody3D

	if player == null or not player.is_in_group("players"):
		return

	var hand := _get_hand_for_player(player)

	if hand == null:
		push_warning("No pickup hand found for player: " + str(player.name))
		return

	pick_up(player, hand)


func _get_hand_for_player(player: CharacterBody3D) -> Node3D:
	var interactor := player.get_node_or_null("PlayerPickupInteractor") as PlayerPickupInteractor

	if interactor != null and not interactor.hand_path.is_empty():
		var hand := interactor.get_node_or_null(interactor.hand_path) as Node3D

		if hand != null:
			return hand

	return player.get_node_or_null("PlayerModel/CharacterArmature/Skeleton3D/Middle1_L") as Node3D


func pick_up(player: Node3D, hand: Node3D) -> void:
	if picked_up:
		return

	picked_up = true
	holder = player

	prompt.visible = false
	prompt_area.monitoring = false
	prompt_area.monitorable = false

	# Reset the spinning visual before attaching to hand.
	if spin_node != null:
		spin_node.transform = spin_node_start_transform

	reparent(hand, false)

	position = held_position
	rotation_degrees = held_rotation_degrees
	scale = held_scale

	var interactor := player.get_node_or_null("PlayerPickupInteractor") as PlayerPickupInteractor

	if interactor != null and interactor.is_local_player():
		interactor.held_item = self

		if interactor.nearby_pickable == self:
			interactor.nearby_pickable = null

	on_picked_up(player)


func use_item(player: Node3D) -> void:
	on_used(player)


func on_picked_up(_player: Node3D) -> void:
	pass


func on_used(_player: Node3D) -> void:
	pass


func _on_prompt_area_body_entered(body: Node3D) -> void:
	if picked_up:
		return

	var interactor := body.get_node_or_null("PlayerPickupInteractor") as PlayerPickupInteractor

	if interactor == null:
		return

	if not interactor.is_local_player():
		return

	interactor.nearby_pickable = self
	prompt.visible = true


func _on_prompt_area_body_exited(body: Node3D) -> void:
	var interactor := body.get_node_or_null("PlayerPickupInteractor") as PlayerPickupInteractor

	if interactor == null:
		return

	if interactor.nearby_pickable == self:
		interactor.nearby_pickable = null

	prompt.visible = false
