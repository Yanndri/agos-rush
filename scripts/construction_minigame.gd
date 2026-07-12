extends Control
class_name ConstructionMinigame

signal completed

const ACTIVE_GROUP := "construction_minigame_active"

@export var interact_action := "interact"
@export var line_speed := 260.0
@export var green_gain := 20.0
@export var gold_gain := 33.0
@export var gray_gain := 15.0

@export var greenGoodSFX: AudioStream
@export var goldGoodSFX: AudioStream
@export var grayGoodSFX: AudioStream

@export var minigame_track_path: NodePath = NodePath("MinigamePanel/VBoxContainer/Minigame/Minigame")
@export var moving_line_path: NodePath = NodePath("MinigamePanel/VBoxContainer/Minigame/Minigame/MovingLine")
@export var green_zone_path: NodePath = NodePath("MinigamePanel/VBoxContainer/Minigame/Minigame/Green")
@export var gold_zone_path: NodePath = NodePath("MinigamePanel/VBoxContainer/Minigame/Minigame/Gold")
@export var gray_zone_path: NodePath = NodePath("MinigamePanel/VBoxContainer/Minigame/Minigame/Gray")
@export var progress_bar_path: NodePath = NodePath("MinigamePanel/VBoxContainer/Progress/ProgressBar")

var active := false
var line_direction := -1.0

@onready var minigame_track: Control = get_node_or_null(minigame_track_path) as Control
@onready var moving_line: Control = get_node_or_null(moving_line_path) as Control
@onready var green_zone: Control = get_node_or_null(green_zone_path) as Control
@onready var gold_zone: Control = get_node_or_null(gold_zone_path) as Control
@onready var gray_zone: Control = get_node_or_null(gray_zone_path) as Control
@onready var progress_bar: ProgressBar = get_node_or_null(progress_bar_path) as ProgressBar


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	hide_minigame()
	call_deferred("_setup_controls")


func _process(delta: float) -> void:
	if not active:
		return

	_update_line(delta)


func _input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventKey and event.echo:
		return
	if not _is_interact_pressed(event):
		return

	get_viewport().set_input_as_handled()
	_try_hit()


func start() -> bool:
	if minigame_track == null or moving_line == null or progress_bar == null:
		return false

	active = true
	if not is_in_group(ACTIVE_GROUP):
		add_to_group(ACTIVE_GROUP)

	visible = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	progress_bar.value = progress_bar.min_value
	_randomize_hit_zone(green_zone)
	_randomize_hit_zone(gold_zone)
	_randomize_hit_zone(gray_zone)
	_reset_moving_line()
	return true


func cancel() -> void:
	active = false
	if is_in_group(ACTIVE_GROUP):
		remove_from_group(ACTIVE_GROUP)
	hide_minigame()


func hide_minigame() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _setup_controls() -> void:
	_normalize_child(moving_line)
	_normalize_child(green_zone)
	_normalize_child(gold_zone)
	_normalize_child(gray_zone)
	_apply_minimum_size(moving_line)
	_apply_minimum_size(green_zone)
	_apply_minimum_size(gold_zone)
	_apply_minimum_size(gray_zone)
	_randomize_hit_zone(green_zone)
	_randomize_hit_zone(gold_zone)
	_randomize_hit_zone(gray_zone)
	_reset_moving_line()


func _normalize_child(control: Control) -> void:
	if control == null:
		return

	var current_global_position := control.global_position
	var current_size := _get_usable_size(control)
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.size = current_size
	control.global_position = current_global_position


func _apply_minimum_size(control: Control) -> void:
	if control == null:
		return

	control.size = _get_usable_size(control)


func _get_usable_size(control: Control) -> Vector2:
	var usable_size := control.size
	if usable_size.x <= 0.0:
		usable_size.x = control.custom_minimum_size.x
	if usable_size.y <= 0.0:
		usable_size.y = control.custom_minimum_size.y

	return usable_size


func _update_line(delta: float) -> void:
	var max_x := _get_max_x(moving_line)
	if max_x <= 0.0:
		return

	var next_x := moving_line.position.x + line_direction * line_speed * delta
	if next_x <= 0.0:
		next_x = 0.0
		line_direction = 1.0
	elif next_x >= max_x:
		next_x = max_x
		line_direction = -1.0

	moving_line.position.x = next_x


func _try_hit() -> void:
	var gain := 0.0
	if _line_overlaps_zone(gold_zone):
		gain = gold_gain
		_play_hit_sfx(goldGoodSFX)
	elif _line_overlaps_zone(green_zone):
		gain = green_gain
		_play_hit_sfx(greenGoodSFX)
	elif _line_overlaps_zone(gray_zone):
		gain = gray_gain
		_play_hit_sfx(grayGoodSFX)

	if gain > 0.0:
		progress_bar.value = min(progress_bar.value + gain, progress_bar.max_value)

	if progress_bar.value >= progress_bar.max_value:
		cancel()
		completed.emit()
		return

	_randomize_hit_zone(green_zone)
	_randomize_hit_zone(gold_zone)
	_randomize_hit_zone(gray_zone)


func _line_overlaps_zone(zone: Control) -> bool:
	if moving_line == null or zone == null:
		return false

	_apply_minimum_size(moving_line)
	_apply_minimum_size(zone)
	var line_rect := moving_line.get_global_rect()
	var zone_rect := zone.get_global_rect()
	return line_rect.position.x <= zone_rect.end.x and line_rect.end.x >= zone_rect.position.x


func _randomize_hit_zone(hit_zone :Panel) -> void:
	if hit_zone == null or minigame_track == null:
		return

	hit_zone.position.x = randf_range(0.0, _get_max_x(hit_zone))


func _reset_moving_line() -> void:
	if moving_line == null or minigame_track == null:
		return

	moving_line.position.x = _get_max_x(moving_line)
	line_direction = -1.0


func _get_max_x(control: Control) -> float:
	if control == null or minigame_track == null:
		return 0.0

	return max(minigame_track.size.x - control.size.x, 0.0)


func _play_hit_sfx(stream: AudioStream) -> void:
	if stream == null:
		return

	AudioUtility.play_sfx(self, stream)


func _is_interact_pressed(event: InputEvent) -> bool:
	return InputMap.has_action(interact_action) and event.is_action_pressed(interact_action)
