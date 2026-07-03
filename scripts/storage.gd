extends Node3D

const STORAGE_SLOT_DROP_TARGET_SCRIPT := preload("res://scripts/storage_slot_drop_target.gd")

@export var interact_action := "interact"
@export var store_radius := 1.5
@export var stored_items_parent_path: NodePath = NodePath("StoredItems")
@export var prompt_area_path: NodePath = NodePath("PromptArea")
@export var ui_layer_path: NodePath = NodePath("CanvasLayer")
@export var storage_ui_path: NodePath = NodePath("CanvasLayer/StorageUI")

@onready var prompt_area: PromptArea = get_node_or_null(prompt_area_path) as PromptArea
@onready var stored_items_parent: Node3D = _get_or_create_stored_items_parent()
@onready var ui_layer: CanvasLayer = get_node_or_null(ui_layer_path) as CanvasLayer
@onready var storage_ui: Control = get_node_or_null(storage_ui_path) as Control

var nearby_player: CharacterBody3D
var stored_items: Array[PickableItem] = []
var item_slots: Array[TextureRect] = []
var slot_controls: Array[Control] = []


func _ready() -> void:
	if prompt_area != null:
		prompt_area.local_player_entered.connect(_on_local_player_entered)
		prompt_area.local_player_exited.connect(_on_local_player_exited)

	_setup_storage_ui()
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


func _store_item(item: PickableItem, preferred_slot_index := -1) -> bool:
	if item == null or item in stored_items:
		return false

	var storage_slot_index := _get_storage_slot_index(preferred_slot_index)
	if storage_slot_index == -1:
		return false

	var item_path := item.get_path()
	var player_name := StringName(nearby_player.name) if nearby_player != null else StringName("")
	if multiplayer.multiplayer_peer != null:
		_sync_store_item.rpc(item_path, storage_slot_index, player_name)
		return true

	_apply_store_item(item, storage_slot_index, player_name)
	return true


@rpc("any_peer", "call_local", "reliable")
func _sync_store_item(item_path: NodePath, storage_slot_index: int, player_name: StringName) -> void:
	var item := get_node_or_null(item_path) as PickableItem
	if item == null:
		return

	_apply_store_item(item, storage_slot_index, player_name)


func _apply_store_item(item: PickableItem, storage_slot_index: int, player_name: StringName) -> void:
	if item == null:
		return

	var inventory := _get_player_inventory()
	if inventory != null:
		inventory.remove_item(item)

	_ensure_storage_size()
	if storage_slot_index < 0 or storage_slot_index >= stored_items.size():
		return

	stored_items[storage_slot_index] = item
	item.store_in_ambulance(stored_items_parent)
	_update_storage_ui()

	var player := get_tree().current_scene.get_node_or_null(String(player_name)) as CharacterBody3D
	if player != null:
		var interactor := player.get_node_or_null("PlayerPickupInteractor") as PlayerPickupInteractor
		if interactor != null:
			interactor.clear_held_item(item)

	print("STORAGE | stored item=", item.name, " | storage=", name)


func _toggle_storage_ui() -> void:
	if storage_ui == null:
		return

	storage_ui.visible = not storage_ui.visible
	if storage_ui.visible:
		_update_storage_ui()


func _hide_storage_ui() -> void:
	if storage_ui != null:
		storage_ui.visible = false


func _setup_storage_ui() -> void:
	if ui_layer != null:
		ui_layer.visible = true

	if storage_ui == null:
		push_warning("Storage is missing CanvasLayer/StorageUI.")
		return

	storage_ui.visible = false
	storage_ui.mouse_filter = Control.MOUSE_FILTER_STOP
	item_slots.clear()
	slot_controls.clear()
	_collect_item_slots(storage_ui)


func _collect_item_slots(root: Node) -> void:
	for child in root.get_children():
		var texture_rect := child as TextureRect
		if texture_rect != null:
			var slot_index := item_slots.size()
			item_slots.append(texture_rect)

			var slot_control := texture_rect.get_parent() as Control
			slot_controls.append(slot_control)
			if slot_control != null:
				slot_control.set_script(STORAGE_SLOT_DROP_TARGET_SCRIPT)
				slot_control.set_meta("storage", self)
				slot_control.set_meta("slot_index", slot_index)
				slot_control.mouse_filter = Control.MOUSE_FILTER_STOP

		_collect_item_slots(child)

	_ensure_storage_size()


func _update_storage_ui() -> void:
	for slot_index in item_slots.size():
		var slot := item_slots[slot_index]
		var item := _get_stored_item_at(slot_index)
		if item == null or not is_instance_valid(item):
			slot.texture = null
			slot.visible = false
			continue

		slot.texture = item.hotbar_icon
		slot.visible = true


func can_drop_hotbar_item(data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false

	var drag_data: Dictionary = data
	if drag_data.get("type", "") != "hotbar_item":
		return false

	var inventory := drag_data.get("inventory") as PlayerInventory
	if inventory == null or inventory != _get_player_inventory():
		return false

	var item := drag_data.get("item") as PickableItem
	if item == null or not is_instance_valid(item):
		return false

	return _get_storage_slot_index(-1) != -1


func drop_hotbar_item(data: Variant, slot_index: int) -> void:
	if not can_drop_hotbar_item(data):
		return

	var drag_data: Dictionary = data
	var item := drag_data.get("item") as PickableItem
	_store_item(item, slot_index)


func get_storage_drag_data(slot_index: int) -> Dictionary:
	var item := _get_stored_item_at(slot_index)
	if item == null:
		return {}

	return {
		"type": "storage_item",
		"storage": self,
		"item": item,
		"slot_index": slot_index,
	}


func retrieve_stored_item(data: Variant, inventory: PlayerInventory, hotbar_slot_index: int) -> bool:
	if typeof(data) != TYPE_DICTIONARY or inventory == null:
		return false

	var drag_data: Dictionary = data
	if drag_data.get("type", "") != "storage_item" or drag_data.get("storage") != self:
		return false

	var item := drag_data.get("item") as PickableItem
	var storage_slot_index := int(drag_data.get("slot_index", -1))
	if item == null or not is_instance_valid(item):
		return false
	if _get_stored_item_at(storage_slot_index) != item:
		return false
	if not inventory.can_drop_storage_item(data, hotbar_slot_index):
		return false

	var item_path := item.get_path()
	var player_name := StringName(nearby_player.name) if nearby_player != null else StringName("")
	if multiplayer.multiplayer_peer != null:
		_sync_retrieve_item.rpc(item_path, storage_slot_index, player_name, hotbar_slot_index)
		return true

	return _apply_retrieve_item(item, storage_slot_index, player_name, hotbar_slot_index)


@rpc("any_peer", "call_local", "reliable")
func _sync_retrieve_item(item_path: NodePath, storage_slot_index: int, player_name: StringName, hotbar_slot_index: int) -> void:
	var item := get_node_or_null(item_path) as PickableItem
	if item == null:
		return

	_apply_retrieve_item(item, storage_slot_index, player_name, hotbar_slot_index)


func _apply_retrieve_item(item: PickableItem, storage_slot_index: int, player_name: StringName, hotbar_slot_index: int) -> bool:
	if item == null or not is_instance_valid(item):
		return false
	if _get_stored_item_at(storage_slot_index) != item:
		return false

	var player := get_tree().current_scene.get_node_or_null(String(player_name)) as CharacterBody3D
	if player == null:
		return false
	if not item.take_from_storage(player):
		return false

	var interactor := player.get_node_or_null("PlayerPickupInteractor") as PlayerPickupInteractor
	if interactor != null and interactor.is_local_player():
		var inventory := player.get_node_or_null("PlayerInventory") as PlayerInventory
		if inventory == null or not inventory.add_item_to_slot(item, hotbar_slot_index):
			item.store_in_ambulance(stored_items_parent)
			return false

	stored_items[storage_slot_index] = null
	_update_storage_ui()
	return true


func _get_player_inventory() -> PlayerInventory:
	if nearby_player == null:
		return null

	return nearby_player.get_node_or_null("PlayerInventory") as PlayerInventory


func _get_inventory_item_at(inventory: PlayerInventory, slot_index: int) -> PickableItem:
	if inventory == null or slot_index < 0 or slot_index >= inventory.items.size():
		return null

	var item := inventory.items[slot_index]
	if item == null or not is_instance_valid(item):
		return null

	return item


func _get_stored_item_at(slot_index: int) -> PickableItem:
	if slot_index < 0 or slot_index >= stored_items.size():
		return null

	var item := stored_items[slot_index]
	if item == null or not is_instance_valid(item):
		return null

	return item


func _get_storage_slot_index(preferred_slot_index: int) -> int:
	_ensure_storage_size()

	if preferred_slot_index >= 0 and preferred_slot_index < stored_items.size():
		var preferred_item := stored_items[preferred_slot_index]
		if preferred_item == null or not is_instance_valid(preferred_item):
			return preferred_slot_index

	for slot_index in stored_items.size():
		var item := stored_items[slot_index]
		if item == null or not is_instance_valid(item):
			return slot_index

	return -1


func _ensure_storage_size() -> void:
	while stored_items.size() < item_slots.size():
		stored_items.append(null)


func _get_or_create_stored_items_parent() -> Node3D:
	var parent := get_node_or_null(stored_items_parent_path) as Node3D
	if parent != null:
		return parent

	parent = Node3D.new()
	parent.name = String(stored_items_parent_path)
	add_child(parent)
	return parent
