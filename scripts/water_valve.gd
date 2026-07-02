extends Node3D

@onready var help_requirement : HelpRequirement = $HelpRequirement
@export var flooded_water : MeshInstance3D
@export var drain_amount := 999.0

var _water_drained := false


func _ready() -> void:
	if help_requirement == null:
		push_warning("WaterValve is missing its HelpRequirement node.")
		return

	if not help_requirement.fulfilled.is_connected(_on_help_requirement_fulfilled):
		help_requirement.fulfilled.connect(_on_help_requirement_fulfilled)

	if help_requirement.requirement_fulfilled:
		_drain_flooded_water()


func _on_help_requirement_fulfilled(_requirement_node: Node) -> void:
	_drain_flooded_water()


func _drain_flooded_water() -> void:
	if _water_drained:
		return

	if flooded_water == null:
		push_warning("WaterValve has no flooded_water assigned.")
		return

	_water_drained = true

	if flooded_water.has_method("reduce_water"):
		flooded_water.reduce_water(drain_amount)
	else:
		flooded_water.visible = false
