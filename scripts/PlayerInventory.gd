extends Node
class_name PlayerInventory

signal selected_item_changed(item: PickableItem)

const HOTBAR_DRAG_SOURCE_SCRIPT := preload("res://scripts/hotbar_drag_source.gd")

@export var hotbar_path: NodePath = NodePath("../PlayerUI/Hotbar")
@export var max_hotbar_slots := 5

var held_item: PickableItem
var hotbar_slots: Array[Control] = []
var items: Array[PickableItem] = []
var selected_slot_index := 0
var player: CharacterBody3D


func _ready() -> void:
	player = get_parent() as CharacterBody3D
	_cache_hotbar_slots()
	_update_hotbar()


func _unhandled_input(event: InputEvent) -> void:
	if not _is_local_player():
		return

	if event is InputEventKey and event.echo:
		return

	var hotbar_slot := _get_pressed_hotbar_slot(event)
	if hotbar_slot == -1:
		return

	get_viewport().set_input_as_handled()
	select_hotbar_slot(hotbar_slot)


func has_free_slot() -> bool:
	return _get_first_free_slot_index() != -1


func increase_hotbar_slots(amount: int = 1) -> bool:
	if amount <= 0:
		return false

	_cache_hotbar_slots()

	var added := false
	for index in range(amount):
		if hotbar_slots.size() >= max_hotbar_slots:
			break

		var new_slot := _create_hotbar_slot(hotbar_slots.size())
		if new_slot == null:
			break

		hotbar_slots.append(new_slot)
		added = true

	if added:
		_ensure_inventory_size()
		_update_hotbar()

	return added


func add_item(item: PickableItem) -> bool:
	if item == null:
		return false

	_ensure_inventory_size()

	var existing_index := items.find(item)
	if existing_index != -1:
		selected_slot_index = existing_index
	else:
		var free_slot_index := _get_first_free_slot_index()
		if free_slot_index == -1:
			push_warning("Tried to add item with no free hotbar slot: " + str(item.name))
			return false

		items[free_slot_index] = item
		selected_slot_index = free_slot_index

	_sync_selected_item()
	return true


func add_item_to_slot(item: PickableItem, slot_index: int) -> bool:
	if item == null:
		return false

	_ensure_inventory_size()

	if slot_index < 0 or slot_index >= items.size():
		return false

	var existing_index := items.find(item)
	if existing_index != -1:
		items[existing_index] = null

	var slot_item := items[slot_index]
	if slot_item != null and is_instance_valid(slot_item):
		return false

	items[slot_index] = item
	selected_slot_index = slot_index
	_sync_selected_item()
	return true


func remove_item(item: PickableItem) -> void:
	var slot_index := items.find(item)
	if slot_index == -1:
		return

	items[slot_index] = null

	if held_item == item:
		held_item = null

	if selected_slot_index == slot_index:
		selected_slot_index = _get_next_filled_slot_index(slot_index)
	elif selected_slot_index >= items.size():
		selected_slot_index = max(items.size() - 1, 0)

	_sync_selected_item()


func get_selected_item() -> PickableItem:
	if held_item != null and is_instance_valid(held_item):
		return held_item

	_sync_selected_item()
	return held_item


func select_hotbar_slot(slot_index: int) -> void:
	_ensure_inventory_size()

	if slot_index < 0 or slot_index >= items.size():
		return

	var item := items[slot_index]
	if item == null or not is_instance_valid(item):
		return

	selected_slot_index = slot_index
	_sync_selected_item()


func _cache_hotbar_slots() -> void:
	hotbar_slots.clear()

	var hotbar := get_node_or_null(hotbar_path)
	if hotbar == null:
		return

	var slot_parent := hotbar.get_node_or_null("HBoxContainer")
	if slot_parent == null:
		slot_parent = hotbar

	for child in slot_parent.get_children():
		var slot := child as Control
		if slot != null:
			hotbar_slots.append(slot)
			_setup_slot_drag_source(slot, hotbar_slots.size() - 1)

	_ensure_inventory_size()


func _create_hotbar_slot(slot_index: int) -> Control:
	if hotbar_slots.is_empty():
		return null

	var slot_parent := hotbar_slots[0].get_parent()
	if slot_parent == null:
		return null

	var source_slot := hotbar_slots[hotbar_slots.size() - 1]
	var new_slot := source_slot.duplicate() as Control
	if new_slot == null:
		return null

	new_slot.name = "Slot%d" % (slot_index + 1)
	slot_parent.add_child(new_slot)

	var label := new_slot.get_node_or_null("SlotLabel") as Label
	if label != null:
		label.text = str(slot_index + 1)

	var icon := _get_slot_icon(new_slot)
	if icon != null:
		icon.texture = null
		icon.visible = false

	_setup_slot_drag_source(new_slot, slot_index)

	return new_slot


func _update_hotbar() -> void:
	_ensure_inventory_size()

	for index in range(hotbar_slots.size()):
		var slot := hotbar_slots[index]
		var icon := _get_slot_icon(slot)
		var item := items[index]

		slot.self_modulate = Color.WHITE if index == selected_slot_index else Color(0.7, 0.7, 0.7, 1.0)

		if icon != null:
			if item != null and is_instance_valid(item):
				icon.texture = item.hotbar_icon
				icon.visible = item.hotbar_icon != null
			else:
				icon.texture = null
				icon.visible = false


func _get_slot_icon(slot: Control) -> TextureRect:
	var direct_icon := slot.get_node_or_null("TextureRect") as TextureRect
	if direct_icon != null:
		return direct_icon

	for child in slot.get_children():
		var icon := child as TextureRect
		if icon != null:
			return icon

	return null


func _setup_slot_drag_source(slot: Control, slot_index: int) -> void:
	slot.set_script(HOTBAR_DRAG_SOURCE_SCRIPT)
	slot.set_meta("inventory", self)
	slot.set_meta("slot_index", slot_index)
	slot.mouse_filter = Control.MOUSE_FILTER_STOP


func get_hotbar_drag_data(slot_index: int) -> Dictionary:
	_ensure_inventory_size()

	if slot_index < 0 or slot_index >= items.size():
		return {}

	var item := items[slot_index]
	if item == null or not is_instance_valid(item):
		return {}

	var preview := TextureRect.new()
	preview.texture = item.hotbar_icon
	preview.custom_minimum_size = Vector2(48, 48)
	preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.modulate = Color(1, 1, 1, 0.8)

	var slot := hotbar_slots[slot_index] if slot_index < hotbar_slots.size() else null
	if slot != null:
		slot.set_drag_preview(preview)

	return {
		"type": "hotbar_item",
		"inventory": self,
		"item": item,
		"slot_index": slot_index,
	}


func can_drop_storage_item(data: Variant, slot_index: int) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false

	_ensure_inventory_size()
	if slot_index < 0 or slot_index >= items.size():
		return false

	var slot_item := items[slot_index]
	if slot_item != null and is_instance_valid(slot_item):
		return false

	var drag_data: Dictionary = data
	if drag_data.get("type", "") != "storage_item":
		return false

	var item := drag_data.get("item") as PickableItem
	if item == null or not is_instance_valid(item):
		return false

	var storage := drag_data.get("storage") as Node
	return storage != null and storage.has_method("retrieve_stored_item")


func drop_storage_item(data: Variant, slot_index: int) -> void:
	if not can_drop_storage_item(data, slot_index):
		return

	var drag_data: Dictionary = data
	var storage := drag_data.get("storage") as Node
	if storage != null:
		storage.retrieve_stored_item(data, self, slot_index)


func _ensure_inventory_size() -> void:
	while items.size() < hotbar_slots.size():
		items.append(null)

	while items.size() > hotbar_slots.size():
		items.pop_back()


func _get_first_free_slot_index() -> int:
	_ensure_inventory_size()

	for index in range(items.size()):
		var item := items[index]
		if item == null or not is_instance_valid(item):
			return index

	return -1


func _get_next_filled_slot_index(start_index: int) -> int:
	_ensure_inventory_size()

	for index in range(start_index, items.size()):
		var item := items[index]
		if item != null and is_instance_valid(item):
			return index

	for index in range(0, start_index):
		var item := items[index]
		if item != null and is_instance_valid(item):
			return index

	return clamp(start_index, 0, max(items.size() - 1, 0))


func _sync_selected_item() -> void:
	_ensure_inventory_size()

	held_item = null

	for index in range(items.size()):
		var item := items[index]
		if item == null or not is_instance_valid(item):
			items[index] = null
			continue

		var is_selected := index == selected_slot_index
		item.visible = is_selected

		if is_selected:
			held_item = item

	_update_hotbar()
	selected_item_changed.emit(held_item)


func _get_pressed_hotbar_slot(event: InputEvent) -> int:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed:
		return -1

	var hotbar_keys := [
		KEY_1,
		KEY_2,
		KEY_3,
		KEY_4,
		KEY_5,
		KEY_6,
		KEY_7,
		KEY_8,
		KEY_9,
		KEY_0,
	]

	var keycode := key_event.physical_keycode
	if keycode == KEY_NONE:
		keycode = key_event.keycode

	var key_index := hotbar_keys.find(keycode)
	if key_index == -1:
		return -1

	return 9 if key_index == 9 else key_index


func _is_local_player() -> bool:
	if player == null:
		return false

	if multiplayer.multiplayer_peer == null:
		return true

	return player.is_multiplayer_authority()
