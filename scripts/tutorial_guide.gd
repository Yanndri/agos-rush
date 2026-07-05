extends Node

enum TutorialStep {
	FIX_VIEW,
	PICK_MEDKIT,
	TEND_RESIDENT,
	CARRY_RESIDENT,
	PICK_BATTERY,
	USE_BATTERY,
	COMPLETE,
}

@export var player_path: NodePath = NodePath("../Player")
@export var resident_path: NodePath = NodePath("../NPC1")
@export var hospital_requirement_path: NodePath = NodePath("../Camp/HelpRequirement")
@export var valve_requirement_path: NodePath = NodePath("../WaterValve/HelpRequirement")
@export var tutorial_2_barrier_path: NodePath = NodePath("../Tutorial2Barrier")
@export var tutorial_3_barrier_path: NodePath = NodePath("../Tutorial3Barrier")
@export var tutorial_finished_panel_path: NodePath = NodePath("../TutorialFinishedPanel")

@export var rotate_left_action := "pan_left"
@export var rotate_right_action := "pan_right"

@export var fix_view_dialogue := "Press Q or E to fix your view"
@export var pick_medkit_dialogue := "Press F on the Medkit to pick it up"
@export var tend_resident_dialogue := "Use the Medkit to tend to the Resident"
@export var carry_resident_dialogue := "Carry the Resident to the Hospital"
@export var pick_battery_dialogue := "Pick up the Battery"
@export var use_battery_dialogue := "Use the Battery to power the draining valve"

var current_step := TutorialStep.FIX_VIEW
var player: CharacterBody3D
var inventory: PlayerInventory
var resident: Node
var resident_requirement: HelpRequirement
var hospital_requirement: HelpRequirement
var valve_requirement: HelpRequirement
var tutorial_2_barrier: Node3D
var tutorial_3_barrier: Node3D
var tutorial_finished_panel: CanvasItem


func _ready() -> void:
	player = get_node_or_null(player_path) as CharacterBody3D
	resident = get_node_or_null(resident_path)
	hospital_requirement = get_node_or_null(hospital_requirement_path) as HelpRequirement
	valve_requirement = get_node_or_null(valve_requirement_path) as HelpRequirement
	tutorial_2_barrier = get_node_or_null(tutorial_2_barrier_path) as Node3D
	tutorial_3_barrier = get_node_or_null(tutorial_3_barrier_path) as Node3D
	tutorial_finished_panel = get_node_or_null(tutorial_finished_panel_path) as CanvasItem

	if player != null:
		inventory = player.get_node_or_null("PlayerInventory") as PlayerInventory
		if inventory != null and not inventory.selected_item_changed.is_connected(_on_selected_item_changed):
			inventory.selected_item_changed.connect(_on_selected_item_changed)

	if resident != null:
		resident_requirement = resident.get_node_or_null("HelpRequirement") as HelpRequirement
		if resident_requirement != null and not resident_requirement.fulfilled.is_connected(_on_resident_requirement_fulfilled):
			resident_requirement.fulfilled.connect(_on_resident_requirement_fulfilled)

	if hospital_requirement != null and not hospital_requirement.fulfilled.is_connected(_on_hospital_requirement_fulfilled):
		hospital_requirement.fulfilled.connect(_on_hospital_requirement_fulfilled)

	if valve_requirement != null and not valve_requirement.fulfilled.is_connected(_on_valve_requirement_fulfilled):
		valve_requirement.fulfilled.connect(_on_valve_requirement_fulfilled)

	_set_barrier_open(tutorial_2_barrier, false)
	_set_barrier_open(tutorial_3_barrier, false)
	_set_tutorial_finished_panel_visible(false)
	call_deferred("_start_tutorial")


func _unhandled_input(event: InputEvent) -> void:
	if current_step != TutorialStep.FIX_VIEW:
		return
	if event is InputEventKey and event.echo:
		return
	if _is_action_pressed(event, rotate_left_action) or _is_action_pressed(event, rotate_right_action):
		_go_to_step(TutorialStep.PICK_MEDKIT)


func _process(_delta: float) -> void:
	match current_step:
		TutorialStep.PICK_MEDKIT:
			if _inventory_has_item("FirstAidKit"):
				_go_to_step(TutorialStep.TEND_RESIDENT)
		TutorialStep.TEND_RESIDENT:
			if resident_requirement != null and resident_requirement.requirement_fulfilled:
				_go_to_step(TutorialStep.CARRY_RESIDENT)
		TutorialStep.CARRY_RESIDENT:
			if hospital_requirement != null and hospital_requirement.requirement_fulfilled:
				_on_resident_delivered()
		TutorialStep.PICK_BATTERY:
			if _inventory_has_item("Battery"):
				_go_to_step(TutorialStep.USE_BATTERY)
		TutorialStep.USE_BATTERY:
			if valve_requirement != null and valve_requirement.requirement_fulfilled:
				_go_to_step(TutorialStep.COMPLETE)


func _start_tutorial() -> void:
	_show_dialogue(fix_view_dialogue)


func _go_to_step(step: TutorialStep) -> void:
	if current_step == step:
		return

	current_step = step

	match current_step:
		TutorialStep.PICK_MEDKIT:
			_show_dialogue(pick_medkit_dialogue)
		TutorialStep.TEND_RESIDENT:
			_show_dialogue(tend_resident_dialogue)
		TutorialStep.CARRY_RESIDENT:
			_show_dialogue(carry_resident_dialogue)
		TutorialStep.PICK_BATTERY:
			_show_dialogue(pick_battery_dialogue)
		TutorialStep.USE_BATTERY:
			_set_barrier_open(tutorial_2_barrier, true)
			_show_dialogue(use_battery_dialogue)
		TutorialStep.COMPLETE:
			_set_barrier_open(tutorial_3_barrier, true)
			_set_tutorial_finished_panel_visible(true)


func _on_selected_item_changed(_item: PickableItem) -> void:
	if current_step == TutorialStep.PICK_MEDKIT and _inventory_has_item("FirstAidKit"):
		_go_to_step(TutorialStep.TEND_RESIDENT)
	elif current_step == TutorialStep.PICK_BATTERY and _inventory_has_item("Battery"):
		_go_to_step(TutorialStep.USE_BATTERY)


func _on_resident_requirement_fulfilled(_requirement_node: Node) -> void:
	if current_step == TutorialStep.TEND_RESIDENT:
		_go_to_step(TutorialStep.CARRY_RESIDENT)


func _on_hospital_requirement_fulfilled(_requirement_node: Node) -> void:
	if current_step == TutorialStep.CARRY_RESIDENT:
		_on_resident_delivered()


func _on_valve_requirement_fulfilled(_requirement_node: Node) -> void:
	if current_step == TutorialStep.USE_BATTERY:
		_go_to_step(TutorialStep.COMPLETE)


func _on_resident_delivered() -> void:
	_go_to_step(TutorialStep.PICK_BATTERY)


func _show_dialogue(message: String) -> void:
	if player == null or not player.has_method("show_dialogue_message"):
		return

	player.show_dialogue_message(message)


func _inventory_has_item(item_name: String) -> bool:
	if inventory == null:
		return false

	for item in inventory.items:
		if item == null or not is_instance_valid(item):
			continue

		var current_item_name := String(item.name)
		if current_item_name == item_name or current_item_name.begins_with(item_name):
			return true

	return false


func _set_barrier_open(barrier: Node3D, is_open: bool) -> void:
	if barrier == null:
		return

	barrier.visible = not is_open
	_set_collision_shapes_disabled(barrier, is_open)


func _set_tutorial_finished_panel_visible(value: bool) -> void:
	if tutorial_finished_panel != null:
		tutorial_finished_panel.visible = value


func _set_collision_shapes_disabled(node: Node, disabled: bool) -> void:
	var shape := node as CollisionShape3D
	if shape != null:
		shape.disabled = disabled

	for child in node.get_children():
		_set_collision_shapes_disabled(child, disabled)


func _is_action_pressed(event: InputEvent, action_name: String) -> bool:
	if action_name.is_empty() or not InputMap.has_action(action_name):
		return false

	return event.is_action_pressed(action_name)
