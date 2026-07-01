extends Node3D

@export var reduce_amount := 0.75
@export var interact_action := "interact"
@export var hold_duration := 1.5

@onready var prompt_area : PromptArea = $PromptArea

var water: Node
var nearby_player: Node3D
var hold_time := 0.0
var is_holding := false

func _ready() -> void:
	water = %Water
	prompt_area._hide_prompt()
	_update_prompt()
	
	if not prompt_area.local_player_entered.is_connected(_on_prompt_area_local_player_entered):
		prompt_area.local_player_entered.connect(_on_prompt_area_local_player_entered)

	if not prompt_area.local_player_exited.is_connected(_on_prompt_area_local_player_exited):
		prompt_area.local_player_exited.connect(_on_prompt_area_local_player_exited)

func _process(delta: float) -> void:
	if nearby_player == null or not is_holding:
		return
	hold_time += delta
	_update_prompt()
	if hold_time >= hold_duration:
		_finish_hold_interact()

func _unhandled_input(event: InputEvent) -> void:
	if nearby_player == null:
		return
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed(interact_action):
		get_viewport().set_input_as_handled()
		_start_hold_interact()
	elif event.is_action_released(interact_action):
		get_viewport().set_input_as_handled()
		_cancel_hold_interact()

func _start_hold_interact() -> void:
	is_holding = true
	hold_time = 0.0
	_update_prompt()

func _cancel_hold_interact() -> void:
	is_holding = false
	hold_time = 0.0
	_update_prompt()

func _finish_hold_interact() -> void:
	is_holding = false
	hold_time = 0.0
	_update_prompt()
	_interact()

func _interact() -> void:
	print("Interacting")
	if multiplayer.multiplayer_peer == null or multiplayer.is_server():
		_reduce_water.rpc()
	else:
		_request_reduce_water.rpc_id(1)

@rpc("any_peer", "reliable")
func _request_reduce_water() -> void:
	if multiplayer.is_server():
		_reduce_water.rpc()

@rpc("authority", "call_local", "reliable")
func _reduce_water() -> void:
	if water and water.has_method("reduce_water"):
		water.reduce_water(reduce_amount)

func _on_prompt_area_local_player_entered(body: Node3D) -> void:
	if not _is_local_player(body):
		return
	nearby_player = body
	prompt_area._show_prompt()
	_update_prompt()

func _on_prompt_area_local_player_exited(body: Node3D) -> void:
	if body != nearby_player:
		return
	nearby_player = null
	prompt_area._hide_prompt()
	_cancel_hold_interact()

func _update_prompt() -> void:
	if nearby_player == null:
		prompt_area._set_prompt("Hold [F] to drain water")
		return
	if is_holding:
		var percent := int(clamp(hold_time / hold_duration, 0.0, 1.0) * 100.0)
		prompt_area._set_prompt("Draining... %d%%" % percent)
	else:
		prompt_area._set_prompt("Hold [F] to drain water")

func _is_local_player(body: Node) -> bool:
	if not body is CharacterBody3D:
		return false
	if multiplayer.multiplayer_peer == null:
		return true
	return body.is_multiplayer_authority()
