extends Node3D

@export_file("*.tscn") var target_scene: String = "res://scenes/main_menu.tscn"
@export var teleport_area_path: NodePath = NodePath("Area3D")

@onready var teleport_area: Area3D = get_node_or_null(teleport_area_path) as Area3D


func _ready() -> void:
	if teleport_area != null and not teleport_area.body_entered.is_connected(_on_teleport_area_body_entered):
		teleport_area.body_entered.connect(_on_teleport_area_body_entered)


func _on_teleport_area_body_entered(body: Node3D) -> void:
	if not _is_player_body(body):
		return

	get_tree().change_scene_to_file(target_scene)


func _is_player_body(body: Node3D) -> bool:
	return body.is_in_group("players") or body.name == "PlayerShaun" or body is CharacterBody3D
