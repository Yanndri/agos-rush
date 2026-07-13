extends Node3D
class_name MapMarker

const MAP_MARKERS_GROUP := "map_markers"

@export var marker_height := 3.0
@export var marker_scale := Vector3(2.0, 2.0, 2.0)
@export var marker_color := Color.WHITE
@export var hide_when_not_in_map := true
@export var marker_enabled := true


func _ready() -> void:
	add_to_group(MAP_MARKERS_GROUP)
	position.y = marker_height
	scale = marker_scale
	_apply_marker_visual_settings()
	set_map_marker_visible(false)


func set_map_marker_visible(value: bool) -> void:
	if not marker_enabled:
		visible = false
		return

	if hide_when_not_in_map:
		visible = value
	else:
		visible = true


func set_marker_enabled(value: bool) -> void:
	marker_enabled = value
	if not marker_enabled:
		visible = false


func _apply_marker_visual_settings() -> void:
	if _has_property("modulate"):
		set("modulate", marker_color)
	if _has_property("fixed_size"):
		set("fixed_size", true)
	if _has_property("no_depth_test"):
		set("no_depth_test", true)


func _has_property(property_name: StringName) -> bool:
	for property in get_property_list():
		if property.get("name", &"") == property_name:
			return true

	return false
