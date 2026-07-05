@tool
extends MultiMeshInstance3D

@export var area_size: Vector2 = Vector2(80, 45)
@export var grass_count: int = 300
@export var grass_y: float = 0.05
@export var min_scale: float = 0.7
@export var max_scale: float = 1.4
@export var random_seed: int = 10
@export var regenerate: bool = false:
	set(value):
		regenerate = false
		scatter_grass()

func _ready() -> void:
	scatter_grass()

func scatter_grass() -> void:
	if multimesh == null:
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed

	multimesh.instance_count = grass_count

	for i in grass_count:
		var x := rng.randf_range(-area_size.x * 0.5, area_size.x * 0.5)
		var z := rng.randf_range(-area_size.y * 0.5, area_size.y * 0.5)

		var rot_y := rng.randf_range(0.0, TAU)
		var scale := rng.randf_range(min_scale, max_scale)

		var basis := Basis()
		basis = basis.rotated(Vector3.UP, rot_y)
		basis = basis.scaled(Vector3(scale, scale, scale))

		var transform := Transform3D(basis, Vector3(x, grass_y, z))
		multimesh.set_instance_transform(i, transform)
