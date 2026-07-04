extends Sprite3D
class_name MapMarker

const MAP_MARKERS_GROUP := "map_markers"

@export var marker_height := 3.0
@export var marker_scale := Vector3(2.0, 2.0, 2.0)
@export var marker_color := Color.WHITE
@export var hide_when_not_in_map := true


func _ready() -> void:
	add_to_group(MAP_MARKERS_GROUP)
	position.y = marker_height
	scale = marker_scale
	modulate = marker_color
	fixed_size = true
	no_depth_test = true
	set_map_marker_visible(false)


func set_map_marker_visible(value: bool) -> void:
	if hide_when_not_in_map:
		visible = value
	else:
		visible = true
