extends Node3D

@export var interact_action := "interact"
@export var store_radius := 1.5
@export var stored_items_parent_path: NodePath = NodePath("StoredItems")
@export var prompt_area_path: NodePath = NodePath("PromptArea")

@onready var prompt_area: PromptArea = get_node_or_null(prompt_area_path) as PromptArea
@onready var stored_items_parent: Node3D = _get_or_create_stored_items_parent()

var nearby_player: CharacterBody3D
var stored_items: Array[PickableItem] = []
var ui_layer: CanvasLayer
var item_list_label: Label


func _ready() -> void:
	if prompt_area != null:
		prompt_area.local_player_entered.connect(_on_local_player_entered)
		prompt_area.local_player_exited.connect(_on_local_player_exited)

	_create_storage_ui()
	_update_storage_ui()


func _process(_delta: float) -> void:
	_store_nearby_dropped_items()


func _unhandled_input(event: InputEvent) -> void:
	if nearby_player == null:
		return
	if event is InputEventKey and event.echo:
		return
	if not event.is_action_pressed(interact_action):
		return

	get_viewport().set_input_as_handled()
	_toggle_storage_ui()


func _on_local_player_entered(player: CharacterBody3D) -> void:
	nearby_player = player


func _on_local_player_exited(player: CharacterBody3D) -> void:
	if nearby_player == player:
		nearby_player = null
		_hide_storage_ui()


func _store_nearby_dropped_items() -> void:
	for node in get_tree().get_nodes_in_group("pickable_items"):
		var item := node as PickableItem
		if item == null:
			continue
		if item.picked_up:
			continue
		if item in stored_items:
			continue
		if global_position.distance_to(item.global_position) > store_radius:
			continue

		_store_item(item)


func _store_item(item: PickableItem) -> void:
	stored_items.append(item)
	item.store_in_ambulance(stored_items_parent)
	_update_storage_ui()
	print("STORAGE | stored item=", item.name, " | storage=", name)


func _toggle_storage_ui() -> void:
	if ui_layer == null:
		return
	ui_layer.visible = not ui_layer.visible
	if ui_layer.visible:
		_update_storage_ui()


func _hide_storage_ui() -> void:
	if ui_layer != null:
		ui_layer.visible = false


func _create_storage_ui() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.name = "StorageUI"
	ui_layer.visible = false
	add_child(ui_layer)

	var panel := Panel.new()
	panel.name = "Panel"
	panel.position = Vector2(32, 96)
	panel.size = Vector2(280, 220)
	ui_layer.add_child(panel)

	var title := Label.new()
	title.name = "Title"
	title.text = "Storage"
	title.position = Vector2(12, 10)
	title.size = Vector2(256, 28)
	panel.add_child(title)

	item_list_label = Label.new()
	item_list_label.name = "ItemList"
	item_list_label.position = Vector2(12, 44)
	item_list_label.size = Vector2(256, 164)
	item_list_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(item_list_label)


func _update_storage_ui() -> void:
	if item_list_label == null:
		return
	if stored_items.is_empty():
		item_list_label.text = "Empty"
		return

	var lines: Array[String] = []
	for item in stored_items:
		if is_instance_valid(item):
			lines.append("- " + item.name)
	item_list_label.text = "\n".join(lines)


func _get_or_create_stored_items_parent() -> Node3D:
	var parent := get_node_or_null(stored_items_parent_path) as Node3D
	if parent != null:
		return parent

	parent = Node3D.new()
	parent.name = String(stored_items_parent_path)
	add_child(parent)
	return parent
