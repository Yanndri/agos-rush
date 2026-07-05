extends MarginContainer
class_name GameTimer

signal timer_finished

@export var timer_label_path: NodePath = NodePath("TimerLabel")
@export var start_time_seconds := 600.0
@export var auto_start := true

@onready var timer_label: Label = get_node_or_null(timer_label_path) as Label

var time_left := 0.0
var is_running := false
var has_finished := false


func _ready() -> void:
	reset_timer()
	if auto_start:
		start_timer()


func _process(delta: float) -> void:
	if not is_running:
		return

	time_left = max(time_left - delta, 0.0)
	_update_timer_label()

	if time_left <= 0.0:
		_finish_timer()


func start_timer() -> void:
	if has_finished:
		reset_timer()

	is_running = true


func stop_timer() -> void:
	is_running = false


func reset_timer() -> void:
	time_left = max(start_time_seconds, 0.0)
	is_running = false
	has_finished = false
	_update_timer_label()


func _finish_timer() -> void:
	if has_finished:
		return

	is_running = false
	has_finished = true
	timer_finished.emit()


func _update_timer_label() -> void:
	if timer_label == null:
		return

	var total_seconds := int(ceil(time_left))
	var minutes := total_seconds / 60
	var seconds := total_seconds % 60
	timer_label.text = "%02d:%02d" % [minutes, seconds]
