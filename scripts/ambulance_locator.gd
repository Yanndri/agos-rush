extends CanvasLayer
class_name AmbulanceLocator

@export var target_path: NodePath
@export var camera_path: NodePath = NodePath("../PlayerModel/CameraPivot/Camera3D")
@export var player_path: NodePath = NodePath("..")
@export var show_after_distance := 18.0
@export var screen_margin := 72.0
@export var indicator_text := "AMBULANCE"
@export var arrow_text := "?"
@export var text_color := Color(1.0, 0.15, 0.1, 1.0)
@export var outline_color := Color(1.0, 1.0, 1.0, 1.0)
@export var font_size := 20

@onready var indicator_label: Label = get_node_or_null("IndicatorLabel") as Label

var target: Node3D
var camera: Camera3D
var player: Node3D


func _ready() -> void:
	_create_label_if_needed()
	_resolve_nodes()
	_update_label_style()
	visible = false


func _process(_delta: float) -> void:
	if not _can_show_for_this_player():
		visible = false
		return

	if target == null or not is_instance_valid(target):
		target = _find_ambulance()

	if camera == null or not is_instance_valid(camera):
		camera = get_node_or_null(camera_path) as Camera3D

	if target == null or camera == null or player == null:
		visible = false
		return

	var distance := player.global_position.distance_to(target.global_position)
	if distance < show_after_distance:
		visible = false
		return

	var viewport_rect := camera.get_viewport().get_visible_rect()
	var center := viewport_rect.size * 0.5
	var screen_position := camera.unproject_position(target.global_position)

	if camera.is_position_behind(target.global_position):
		screen_position = center - (screen_position - center)

	var direction := screen_position - center
	if direction.length_squared() <= 0.01:
		direction = Vector2.UP

	direction = direction.normalized()
	var edge_position := center + direction * _edge_distance(center, direction)
	indicator_label.position = edge_position - indicator_label.size * 0.5
	indicator_label.rotation = direction.angle() + PI * 0.5
	indicator_label.text = "%s\n%s %dm" % [arrow_text, indicator_text, int(distance)]
	visible = true


func _create_label_if_needed() -> void:
	if indicator_label != null:
		return

	indicator_label = Label.new()
	indicator_label.name = "IndicatorLabel"
	add_child(indicator_label)


func _resolve_nodes() -> void:
	camera = get_node_or_null(camera_path) as Camera3D
	player = get_node_or_null(player_path) as Node3D

	if not target_path.is_empty():
		target = get_node_or_null(target_path) as Node3D

	if target == null:
		target = _find_ambulance()


func _find_ambulance() -> Node3D:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return null

	var ambulance := current_scene.get_node_or_null("Ambulance") as Node3D
	if ambulance != null:
		return ambulance

	return current_scene.find_child("Ambulance", true, false) as Node3D


func _can_show_for_this_player() -> bool:
	if player == null:
		player = get_node_or_null(player_path) as Node3D

	if player == null:
		return false

	if not player.has_method("is_multiplayer_authority"):
		return true

	return player.is_multiplayer_authority()


func _edge_distance(center: Vector2, direction: Vector2) -> float:
	var x_limit = max(center.x - screen_margin, 0.0) / max(abs(direction.x), 0.001)
	var y_limit = max(center.y - screen_margin, 0.0) / max(abs(direction.y), 0.001)
	return min(x_limit, y_limit)


func _update_label_style() -> void:
	indicator_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	indicator_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	indicator_label.add_theme_font_size_override("font_size", font_size)
	indicator_label.add_theme_color_override("font_color", text_color)
	indicator_label.add_theme_color_override("font_outline_color", outline_color)
	indicator_label.add_theme_constant_override("outline_size", 4)
