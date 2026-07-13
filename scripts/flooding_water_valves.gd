extends Node3D

@export var flood_start := 10 #when game starts, it countdowns
@export var floodingInterval := 60 #when the next flood in seconds
@export var auto_start := true


func _ready() -> void:
	if auto_start:
		get_tree().call_group("game_ui", "add_objective", "- Gather Supplies before the flood", "ID01")
		await get_tree().create_timer(3).timeout
		_start_flood_loop()
		await get_tree().create_timer(flood_start).timeout
		get_tree().call_group("game_ui", "remove_objective", "ID01")


func _start_flood_loop() -> void:
	if flood_start > 0:
		get_tree().call_group("game_ui", "announce", "Flood incoming in %d seconds!" % flood_start)
		await get_tree().create_timer(flood_start).timeout

	_choose_random_flood()

	while floodingInterval > 0:
		await get_tree().create_timer(floodingInterval).timeout
		_choose_random_flood()


func _choose_random_flood() -> void:
	var available_valves := _get_available_water_valves()
	if available_valves.is_empty():
		return

	var valve = available_valves.pick_random()
	if valve == null:
		return

	if valve.has_method("flood"):
		valve.flood()

	var area_name := _get_valve_area_name(valve)
	get_tree().call_group("game_ui", "announce", "Area flooded in " + area_name + " need help")


func _get_available_water_valves() -> Array[Node]:
	var valves: Array[Node] = []
	for child in get_children():
		if not child.has_method("flood"):
			continue
		if bool(child.get("is_flooded")):
			continue
		valves.append(child)

	return valves


func _get_valve_area_name(valve: Node) -> String:
	var raw_area_name := String(valve.get("area_name")).strip_edges()
	if raw_area_name.is_empty():
		return String(valve.name)

	return raw_area_name
