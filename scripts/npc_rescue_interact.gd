extends CharacterBody3D

@export var interact_action := "interact"
@export var carry_offset := Vector3(0.0, 2.25, 0.0)
@export var need_item_text := ""
@export var need_label_height := 2.4

@onready var prompt_area: PromptArea = $PromptArea

var nearby_player: Node3D
var carried := false
var need_label: Label3D

func _ready() -> void:
	_create_need_label()
	prompt_area._hide_prompt()

	prompt_area.body_entered.connect(_on_prompt_area_body_entered)
	prompt_area.body_exited.connect(_on_prompt_area_body_exited)

func _unhandled_input(event: InputEvent) -> void:
	if carried or nearby_player == null:
		return
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed(interact_action):
		_interact()

func _interact() -> void:
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
	prompt_area._show_prompt()
	_show_need_gui()

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

func _create_need_label() -> void:
	if need_item_text.is_empty():
		return

	need_label = Label3D.new()
	need_label.name = "NeedItemLabel"
	need_label.text = "I need this: " + need_item_text
	need_label.position = Vector3(0.0, need_label_height, 0.0)
	need_label.font_size = 48
	need_label.modulate = Color(1.0, 0.95, 0.35, 1.0)
	need_label.outline_size = 8
	need_label.outline_modulate = Color(0.0, 0.0, 0.0, 1.0)
	need_label.no_depth_test = true
	need_label.visible = false
	add_child(need_label)


func _show_need_gui() -> void:
	if need_label != null:
		need_label.visible = true


func _hide_need_gui() -> void:
	if need_label != null:
		need_label.visible = false
