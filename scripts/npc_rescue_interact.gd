extends Node3D

@export var interact_action := "interact"
@export var carry_offset := Vector3(0.0, 2.25, 0.0)
@export var need_label_height := 2.4
@export var help_requirement_path: NodePath
@export var carry_prompt_text := "[F] to Carry Resident"
@export var completed_requirement_type := "Hospital"

@onready var prompt_area: PromptArea = $HelpRequirement/PromptArea
@onready var help_requirement: HelpRequirement = _get_help_requirement()

var nearby_player: Node3D
var carried := false
var need_label: Label3D

func _ready() -> void:
	prompt_area._hide_prompt()
	_show_need_gui()

	prompt_area.body_entered.connect(_on_prompt_area_body_entered)
	prompt_area.body_exited.connect(_on_prompt_area_body_exited)

	if help_requirement != null and not help_requirement.fulfilled.is_connected(_on_help_requirement_fulfilled):
		help_requirement.fulfilled.connect(_on_help_requirement_fulfilled)
	if help_requirement != null and help_requirement.requirement_fulfilled:
		_set_completed_requirement_display()

func _unhandled_input(event: InputEvent) -> void:
	if carried or nearby_player == null:
		return
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed(interact_action):
		get_viewport().set_input_as_handled()
		_interact()
		return

func _interact() -> void:
	if not _can_be_carried():
		if _nearby_player_has_required_item():
			return

		_show_requirement_blocked_prompt()
		return

	if not _is_local_player(nearby_player):
		nearby_player = null
		prompt_area._hide_prompt()
		_hide_need_gui()
		return
	if multiplayer.multiplayer_peer == null:
		_carry_for_player(nearby_player.name)
	elif multiplayer.is_server():
		_carry_for_player.rpc(nearby_player.name)
	else:
		_request_carry.rpc_id(1, nearby_player.name)

@rpc("any_peer", "reliable")
func _request_carry(player_name: StringName) -> void:
	if multiplayer.is_server():
		_carry_for_player.rpc(player_name)

@rpc("authority", "call_local", "reliable")
func _carry_for_player(player_name: StringName) -> void:
	if carried:
		return
	var player := get_tree().current_scene.get_node_or_null(String(player_name)) as Node3D
	if player == null or player == self or not player.is_in_group("players"):
		return
	carried = true
	nearby_player = null
	prompt_area._hide_prompt()
	_hide_need_gui()
	_disable_collision_shapes(self)
	reparent(player, false)
	position = carry_offset
	rotation = Vector3.ZERO

func _on_prompt_area_body_entered(body: Node3D) -> void:
	if carried or not _is_local_player(body):
		return
	nearby_player = body
	_update_prompt()
	prompt_area._show_prompt()

func _on_prompt_area_body_exited(body: Node3D) -> void:
	if body != nearby_player:
		return
	nearby_player = null
	prompt_area._hide_prompt()
	_hide_need_gui()

func _is_local_player(body: Node) -> bool:
	if body == null or body == self:
		return false
	if not body is CharacterBody3D:
		return false
	if not body.is_in_group("players"):
		return false
	if multiplayer.multiplayer_peer == null:
		return true
	return body.is_multiplayer_authority()

func _disable_collision_shapes(node: Node) -> void:
	if node is CollisionShape3D:
		node.disabled = true
	for child in node.get_children():
		_disable_collision_shapes(child)

func _show_need_gui() -> void:
	if need_label != null:
		need_label.visible = true


func _hide_need_gui() -> void:
	if need_label != null:
		need_label.visible = false

func _can_be_carried() -> bool:
	return help_requirement == null or help_requirement.requirement_fulfilled


func _update_prompt() -> void:
	if prompt_area == null:
		return

	if _can_be_carried():
		prompt_area._set_prompt(carry_prompt_text)


func _on_help_requirement_fulfilled(_requirement_node: Node) -> void:
	_set_completed_requirement_display()
	_update_prompt()
	if nearby_player != null and prompt_area != null:
		prompt_area._show_prompt()


func _set_completed_requirement_display() -> void:
	if help_requirement == null or completed_requirement_type.is_empty():
		return

	help_requirement.show_fulfilled_requirement(completed_requirement_type)


func _nearby_player_has_required_item() -> bool:
	if help_requirement == null:
		return false

	var player := nearby_player as CharacterBody3D
	if player == null:
		return false

	return help_requirement.player_has_required_item(player)


func _get_help_requirement() -> HelpRequirement:
	if not help_requirement_path.is_empty():
		return get_node_or_null(help_requirement_path) as HelpRequirement

	for child in get_children():
		var requirement := child as HelpRequirement
		if requirement != null:
			return requirement

	return null

func _show_requirement_blocked_prompt() -> void:
	if help_requirement != null:
		help_requirement.show_requirement_dialogue(nearby_player)
	if prompt_area != null:
		prompt_area._show_prompt()


func is_carried_resident() -> bool:
	return carried


func complete_rescue() -> void:
	carried = false
	nearby_player = null
	_hide_need_gui()
	if prompt_area != null:
		prompt_area._hide_prompt()
	_disable_collision_shapes(self)
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	call_deferred("queue_free")
