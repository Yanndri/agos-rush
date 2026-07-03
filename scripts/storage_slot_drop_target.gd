extends Control
class_name StorageSlotDropTarget


func _get_drag_data(_at_position: Vector2) -> Variant:
	var storage := get_meta("storage") as Node
	var slot_index := int(get_meta("slot_index", -1))
	if storage == null or not storage.has_method("get_storage_drag_data"):
		return null

	return storage.get_storage_drag_data(slot_index)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	var storage := get_meta("storage") as Node
	if storage == null or not storage.has_method("can_drop_hotbar_item"):
		return false

	return storage.can_drop_hotbar_item(data)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var storage := get_meta("storage") as Node
	var slot_index := int(get_meta("slot_index", -1))
	if storage == null or not storage.has_method("drop_hotbar_item"):
		return

	storage.drop_hotbar_item(data, slot_index)
