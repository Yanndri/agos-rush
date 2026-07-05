@tool
extends Node3D

@export var generate_leaves: bool = false:
	set(value):
		generate_leaves = false
		create_leaf_ambience()

@export var clear_existing: bool = false:
	set(value):
		clear_existing = false
		clear_leaf_ambience()

@export var area_size: Vector3 = Vector3(80.0, 10.0, 45.0)
@export var particle_amount: int = 120
@export var lifetime: float = 8.0
@export var preprocess_time: float = 8.0

@export var leaf_size: Vector2 = Vector2(0.8, 0.35)
@export var leaf_color: Color = Color(1.0, 0.55, 0.1, 1.0)

@export var wind_direction: Vector3 = Vector3(1.0, -0.05, 0.25)
@export var velocity_min: float = 0.8
@export var velocity_max: float = 2.0

@export var scale_min: float = 1.0
@export var scale_max: float = 2.0

const LEAF_NODE_NAME := "LeafAmbience"


func clear_leaf_ambience() -> void:
	var existing := get_node_or_null(LEAF_NODE_NAME)
	if existing:
		existing.queue_free()
		print("Leaf ambience cleared.")


func create_leaf_ambience() -> void:
	clear_leaf_ambience()

	var particles := GPUParticles3D.new()
	particles.name = LEAF_NODE_NAME
	add_child(particles)

	if Engine.is_editor_hint():
		particles.owner = get_tree().edited_scene_root
	else:
		particles.owner = self

	particles.amount = particle_amount
	particles.lifetime = lifetime
	particles.preprocess = preprocess_time
	particles.one_shot = false
	particles.explosiveness = 0.0
	particles.randomness = 0.8
	particles.local_coords = false
	particles.emitting = true
	particles.visible = true

	particles.visibility_aabb = AABB(
		Vector3(-area_size.x * 0.5, -area_size.y * 0.5, -area_size.z * 0.5),
		area_size
	)

	var process_material := ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process_material.emission_box_extents = area_size * 0.5

	process_material.direction = wind_direction.normalized()
	process_material.spread = 60.0

	process_material.initial_velocity_min = velocity_min
	process_material.initial_velocity_max = velocity_max

	process_material.gravity = Vector3(0.15, -0.03, 0.05)
	process_material.damping_min = 0.05
	process_material.damping_max = 0.25

	process_material.scale_min = scale_min
	process_material.scale_max = scale_max

	process_material.angular_velocity_min = -240.0
	process_material.angular_velocity_max = 240.0

	particles.process_material = process_material

	var quad := QuadMesh.new()
	quad.size = leaf_size

	var material := StandardMaterial3D.new()
	material.albedo_color = leaf_color
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED

	quad.material = material
	particles.draw_pass_1 = quad

	print("Leaf ambience created. Amount: ", particle_amount)
