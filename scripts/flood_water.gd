extends MeshInstance3D

@export var start_delay := 20.0
@export var rise_speed := 0.12
@export var max_height := 2.5
@export var min_height := -3.0
@export var drain_duration := 0.8
@export var water_margin := 0.05
@export var current := Vector3.ZERO
@export var player_path: NodePath = ^"../Player"

var player: Node
var elapsed_time := 0.0
var drain_tween: Tween

func _ready() -> void:
	player = get_node_or_null(player_path)

func _physics_process(delta: float) -> void:
	elapsed_time += delta
	var flood_started := elapsed_time >= start_delay

	if flood_started and global_position.y < max_height:
		global_position.y = min(global_position.y + rise_speed * delta, max_height)

	if player and player.has_method("set_water_state"):
		var surface_y := _get_surface_y()
		var in_water: bool = player.global_position.y <= surface_y + water_margin
		player.set_water_state(in_water, surface_y, current)

func _get_surface_y() -> float:
	if mesh is BoxMesh:
		return global_position.y + (mesh as BoxMesh).size.y * global_basis.get_scale().y * 0.5
	return global_position.y

func reduce_water(amount: float) -> void:
	print("Water reduced by: ", amount)
	var target_y = max(global_position.y - amount, min_height)
	if drain_tween:
		drain_tween.kill()
	drain_tween = create_tween()
	drain_tween.tween_property(self, "global_position:y", target_y, drain_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	print("target global_position.y: ", target_y)
