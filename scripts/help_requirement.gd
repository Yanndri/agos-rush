extends Area3D
class_name HelpRequirement

signal fulfilled(item: PickableItem)

@export var required_item_name := "FirstAidKit"
@export var consume_item_when_fulfilled := true
@export var requirements_visual_path: NodePath = NodePath("Requirements")

var _requirement_fulfilled := false

@export var requirement_fulfilled := false:
	set(value):
		_set_fulfilled(value)
	get:
		return _requirement_fulfilled

# Kept so old scene data using the misspelled export still works.
@export var requirement_fullilled := false:
	set(value):
		_set_fulfilled(value)
	get:
		return _requirement_fulfilled

@onready var requirements_visual: Node3D = get_node_or_null(requirements_visual_path) as Node3D


func _ready() -> void:
	monitoring = true
	monitorable = true
	_update_visuals()

	if not body_entered.is_connected(_on_node_entered):
		body_entered.connect(_on_node_entered)

	if not area_entered.is_connected(_on_node_entered):
		area_entered.connect(_on_node_entered)

	_check_overlapping_nodes()


func _process(_delta: float) -> void:
	if requirement_fulfilled:
		return

	_check_overlapping_nodes()


func _on_node_entered(node: Node) -> void:
	_try_fulfill_from_node(node)


func _check_overlapping_nodes() -> void:
	for body in get_overlapping_bodies():
		if _try_fulfill_from_node(body):
			return

	for area in get_overlapping_areas():
		if _try_fulfill_from_node(area):
			return


func _try_fulfill_from_node(node: Node) -> bool:
	if requirement_fulfilled:
		return false

	var item := _find_pickable_item(node)
	if item == null:
		return false

	if item.picked_up:
		return false

	if not _is_required_item(item):
		return false

	_fulfill(item)
	return true


func _find_pickable_item(node: Node) -> PickableItem:
	var current := node
	while current != null:
		var item := current as PickableItem
		if item != null:
			return item
		current = current.get_parent()

	return null


func _is_required_item(item: PickableItem) -> bool:
	if required_item_name.is_empty():
		return true

	return item.name == required_item_name


func _fulfill(item: PickableItem) -> void:
	_set_fulfilled(true)
	print("HELP REQUIREMENT FULFILLED | requirement=", name, " | item=", item.name)

	if consume_item_when_fulfilled:
		_consume_item(item)

	fulfilled.emit(item)


func _set_fulfilled(value: bool) -> void:
	_requirement_fulfilled = value
	_update_visuals()


func _consume_item(item: PickableItem) -> void:
	item.picked_up = true
	item.visible = false
	item.process_mode = Node.PROCESS_MODE_DISABLED

	if item.prompt_area != null:
		item.prompt_area.set_prompt_enabled(false)


func _update_visuals() -> void:
	if requirements_visual != null:
		requirements_visual.visible = not _requirement_fulfilled
