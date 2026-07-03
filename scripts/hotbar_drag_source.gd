extends Control
class_name HotbarDragSource


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		DragPreviewOverlay.hide_preview(self)


func _get_drag_data(_at_position: Vector2) -> Variant:
	var inventory := get_meta("inventory") as PlayerInventory
	var slot_index := int(get_meta("slot_index", -1))
	if inventory == null or not inventory.has_method("get_hotbar_drag_data"):
		return null

	var drag_data := inventory.get_hotbar_drag_data(slot_index)
	if drag_data.has("item"):
		var item := drag_data["item"] as PickableItem
		if item != null:
			DragPreviewOverlay.show_preview(self, item.hotbar_icon)

	return drag_data


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	var inventory := get_meta("inventory") as PlayerInventory
	var slot_index := int(get_meta("slot_index", -1))
	if inventory == null or not inventory.has_method("can_drop_storage_item"):
		return false

	return inventory.can_drop_storage_item(data, slot_index)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var inventory := get_meta("inventory") as PlayerInventory
	var slot_index := int(get_meta("slot_index", -1))
	if inventory == null or not inventory.has_method("drop_storage_item"):
		return

	inventory.drop_storage_item(data, slot_index)
