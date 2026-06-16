extends Node3D
class_name PickableItem

@export var held_position := Vector3.ZERO
@export var held_rotation_degrees := Vector3.ZERO
@export var held_scale := Vector3.ONE

@export var spin_when_available := true
@export var spin_speed_degrees := 90.0

# This is the node that will spin.
# If your item mesh is named "Visual", keep this as "Visual".
@export var spin_node_path: NodePath = NodePath("Visual")

@onready var prompt_area: Area3D = $PromptArea
@onready var prompt: Label3D = $PromptArea/PromptLabel
@onready var spin_node: Node3D = get_node_or_null(spin_node_path) as Node3D

var picked_up := false
var holder: Node3D


func _ready() -> void:
	prompt.visible = false

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


func pick_up(player: Node3D, hand: Node3D) -> void:
	if picked_up:
		return

	picked_up = true
	holder = player

	prompt.visible = false
	prompt_area.monitoring = false
	prompt_area.monitorable = false

	reparent(hand, false)

	position = held_position
	rotation_degrees = held_rotation_degrees
	scale = held_scale

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
