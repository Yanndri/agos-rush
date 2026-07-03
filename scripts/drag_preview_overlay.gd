extends CanvasLayer
class_name DragPreviewOverlay

const OVERLAY_NAME := "DragPreviewOverlay"

var icon: TextureRect


static func show_preview(source: Node, texture: Texture2D) -> void:
	if source == null or texture == null:
		return

	hide_preview(source)

	var overlay := DragPreviewOverlay.new()
	overlay.name = OVERLAY_NAME
	overlay.layer = 4096
	source.get_tree().root.add_child(overlay)
	overlay._setup(texture)


static func hide_preview(source: Node) -> void:
	if source == null:
		return

	var overlay := source.get_tree().root.get_node_or_null(OVERLAY_NAME)
	if overlay != null:
		overlay.queue_free()


func _setup(texture: Texture2D) -> void:
	icon = TextureRect.new()
	icon.texture = texture
	icon.modulate.a = 0.5
	icon.custom_minimum_size = Vector2(56, 56)
	icon.size = Vector2(56, 56)
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icon)
	_process(0.0)


func _process(_delta: float) -> void:
	if icon == null:
		return

	icon.position = get_viewport().get_mouse_position() - icon.size * 0.5
