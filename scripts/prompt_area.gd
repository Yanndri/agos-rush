extends Area3D
class_name PromptArea

signal local_player_entered(player: CharacterBody3D)
signal local_player_exited(player: CharacterBody3D)

@export var prompt_label_path: NodePath = NodePath("PromptLabel")

@onready var prompt_label: Label3D = get_node_or_null(prompt_label_path) as Label3D

var current_local_player: CharacterBody3D


func _ready() -> void:
	_hide_prompt()

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)


func set_prompt_enabled(enabled: bool) -> void:
	monitoring = enabled
	monitorable = enabled

	if not enabled:
		current_local_player = null
		_hide_prompt()


func _on_body_entered(body: Node3D) -> void:
	var player := body as CharacterBody3D
	if player == null or not player.is_in_group("players"):
		return

	if not _is_local_player(player):
		return

	current_local_player = player
	_show_prompt()
	local_player_entered.emit(player)


func _on_body_exited(body: Node3D) -> void:
	var player := body as CharacterBody3D
	if player == null:
		return

	if player != current_local_player:
		return

	current_local_player = null
	_hide_prompt()
	local_player_exited.emit(player)


func _show_prompt() -> void:
	if prompt_label != null:
		prompt_label.visible = true


func _hide_prompt() -> void:
	if prompt_label != null:
		prompt_label.visible = false


func _is_local_player(player: CharacterBody3D) -> bool:
	if multiplayer.multiplayer_peer == null:
		return true

	return player.is_multiplayer_authority()
