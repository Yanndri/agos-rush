extends MeshInstance3D

@export var reduce_amount := 0.75
@export var interact_key := KEY_E
@export var hold_duration := 1.5

@onready var prompt: Label3D = $PromptLabel
var water: Node
var nearby_player: Node3D
var hold_time := 0.0
var is_holding := false

func _ready() -> void:
	water = %Water
	prompt.visible = false
	_update_prompt()

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
	if event is InputEventKey and event.keycode == interact_key:
		if event.pressed and not event.echo:
			_start_hold_interact()
		elif not event.pressed:
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

func _on_prompt_area_body_entered(body: Node3D) -> void:
	if not _is_local_player(body):
		return
	nearby_player = body
	prompt.visible = true
	_update_prompt()

func _on_prompt_area_body_exited(body: Node3D) -> void:
	if body != nearby_player:
		return
	nearby_player = null
	prompt.visible = false
	_cancel_hold_interact()

func _update_prompt() -> void:
	if nearby_player == null:
		prompt.text = "Hold E to drain water"
		return
	if is_holding:
		var percent := int(clamp(hold_time / hold_duration, 0.0, 1.0) * 100.0)
		prompt.text = "Draining... %d%%" % percent
	else:
		prompt.text = "Hold E to drain water"

func _is_local_player(body: Node) -> bool:
	if not body is CharacterBody3D:
		return false
	if multiplayer.multiplayer_peer == null:
		return true
	return body.is_multiplayer_authority()
