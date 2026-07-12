extends Node3D

@onready var help_requirement : HelpRequirement = $HelpRequirement
@export var flooded_water : MeshInstance3D
@export var area_name : String #if the valves are for a certain area 

@export var drain_amount := 999.0
@export var flood_rise_duration := 1.0
@export var start_drained := true #water will be drained once the game starts putting the water below the original position

var _water_drained := false
var is_flooded := false #when the water has raised to original height
var _flooded_water_original_global_position := Vector3.ZERO
var _water_tween: Tween

func _ready() -> void:
	_cache_flooded_water_start_state()

	if help_requirement == null:
		push_warning("WaterValve is missing its HelpRequirement node.")
		return

	if not help_requirement.fulfilled.is_connected(_on_help_requirement_fulfilled):
		help_requirement.fulfilled.connect(_on_help_requirement_fulfilled)

	if help_requirement.requirement_fulfilled:
		_drain_flooded_water()
	elif start_drained:
		_set_water_drained_immediately()
	else:
		is_flooded = true
		_set_help_requirement_enabled(true)


func _on_help_requirement_fulfilled(_requirement_node: Node) -> void:
	_drain_flooded_water()


func set_flooded(value: bool) -> void:
	if value:
		_raise_flooded_water()
	else:
		_drain_flooded_water()


func flood() -> void:
	set_flooded(true)


func drain() -> void:
	set_flooded(false)


func _cache_flooded_water_start_state() -> void:
	if flooded_water == null:
		return

	_flooded_water_original_global_position = flooded_water.global_position


func _set_water_drained_immediately() -> void:
	if flooded_water == null:
		push_warning("WaterValve has no flooded_water assigned.")
		return

	_kill_water_tween()
	var target_y := _get_drained_water_y()
	flooded_water.global_position.y = target_y
	_water_drained = true
	is_flooded = false
	_set_water_runtime_state(false)
	_set_help_requirement_enabled(false)


func _raise_flooded_water() -> void:
	if flooded_water == null:
		push_warning("WaterValve has no flooded_water assigned.")
		return

	_kill_water_tween()
	_water_drained = false
	is_flooded = true
	_set_water_runtime_state(true)
	if help_requirement != null:
		help_requirement.requirement_fulfilled = false
	_set_help_requirement_enabled(true)
	_add_flood_objective()

	_water_tween = create_tween()
	_water_tween.tween_property(flooded_water, "global_position:y", _flooded_water_original_global_position.y, flood_rise_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_water_tween.finished.connect(func() -> void:
		_water_tween = null
	)


func _drain_flooded_water() -> void:
	if _water_drained:
		return

	if flooded_water == null:
		push_warning("WaterValve has no flooded_water assigned.")
		return

	_water_drained = true
	is_flooded = false
	_kill_water_tween()
	_set_help_requirement_enabled(false)
	_remove_flood_objective()

	if flooded_water.has_method("reduce_water"):
		flooded_water.reduce_water(drain_amount)
	else:
		flooded_water.visible = false


func _get_drained_water_y() -> float:
	var drained_y := _flooded_water_original_global_position.y - drain_amount
	if flooded_water != null and "min_height" in flooded_water:
		drained_y = max(drained_y, float(flooded_water.get("min_height")))
	return drained_y


func _set_water_runtime_state(enabled: bool) -> void:
	if flooded_water == null:
		return

	flooded_water.visible = enabled

	if "permanently_drained" in flooded_water:
		flooded_water.set("permanently_drained", false)
	if "is_draining" in flooded_water:
		flooded_water.set("is_draining", false)

	var water_area := flooded_water.get_node_or_null("WaterArea") as Area3D
	if water_area != null:
		water_area.set_deferred("monitoring", enabled)
		water_area.set_deferred("monitorable", enabled)


func _set_help_requirement_enabled(enabled: bool) -> void:
	if help_requirement == null:
		return

	help_requirement.visible = enabled
	help_requirement.process_mode = Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED

	var prompt_area := help_requirement.get_node_or_null("PromptArea") as PromptArea
	if prompt_area != null:
		prompt_area.set_prompt_enabled(enabled)


func get_flood_objective_id() -> String:
	return "flood_%s" % str(get_instance_id())


func get_flood_objective_text() -> String:
	var label_area_name := area_name.strip_edges()
	if label_area_name.is_empty():
		label_area_name = String(name)

	return "- Drain flooded area in " + label_area_name


func _add_flood_objective() -> void:
	get_tree().call_group("game_ui", "add_objective", get_flood_objective_text(), get_flood_objective_id())


func _remove_flood_objective() -> void:
	get_tree().call_group("game_ui", "remove_objective", get_flood_objective_id())


func _kill_water_tween() -> void:
	if _water_tween != null:
		_water_tween.kill()
		_water_tween = null
