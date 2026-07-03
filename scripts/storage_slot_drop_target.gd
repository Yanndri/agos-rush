extends Control
class_name StorageSlotDropTarget


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		DragPreviewOverlay.hide_preview(self)


func _get_drag_data(_at_position: Vector2) -> Variant:
	var storage := get_meta("storage") as Node
	var slot_index := int(get_meta("slot_index", -1))
	if storage == null or not storage.has_method("get_storage_drag_data"):
		return null

	var drag_data: Dictionary = storage.get_storage_drag_data(slot_index)
	if drag_data.has("item"):
		var item := drag_data["item"] as PickableItem
		if item != null:
			DragPreviewOverlay.show_preview(self, item.hotbar_icon)

	return drag_data


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
