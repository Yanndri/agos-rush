extends Node3D

@export var player: Node3D
@export var camera: Camera3D
@export var transparent_alpha := 0.25
@export var max_hits := 8
@export var debug_hits := false
@export var vehicle_zoom_multiplier := 2.5
@export var vehicle_zoom_speed := 5.0

var faded_meshes: Array[MeshInstance3D] = []
var original_materials := {}
var normal_camera_position := Vector3.ZERO


func _ready() -> void:
	if camera != null:
		normal_camera_position = camera.position


func _process(delta: float) -> void:
	if player == null or camera == null:
		return

	_update_vehicle_zoom(delta)
	_restore_faded_meshes()
	_fade_blocking_objects()


func _update_vehicle_zoom(delta: float) -> void:
	var target_position := normal_camera_position

	if player.get("is_driving_vehicle") == true:
		target_position = normal_camera_position * vehicle_zoom_multiplier

	camera.position = camera.position.lerp(target_position, min(vehicle_zoom_speed * delta, 1.0))


func _fade_blocking_objects() -> void:
	var space_state := get_world_3d().direct_space_state

	var from := camera.global_position
	var to := player.global_position + Vector3.UP * 1.0

	var excluded: Array[RID] = []

	if player is CollisionObject3D:
		excluded.append((player as CollisionObject3D).get_rid())

	for i in range(max_hits):
		var query := PhysicsRayQueryParameters3D.create(from, to)
		query.exclude = excluded
		query.collide_with_bodies = true
		query.collide_with_areas = false

		var result := space_state.intersect_ray(query)

		if result.is_empty():
			break

		var collider := result["collider"] as CollisionObject3D

		if collider == null:
			break

		excluded.append(collider.get_rid())

		if debug_hits:
			var parent_name := "No Parent"
			if collider.get_parent() != null:
				parent_name = collider.get_parent().name

			print("Hit collider: ", collider.name, " | Parent: ", parent_name)

		var mesh := _find_parent_mesh(collider)

		if mesh != null:
			_make_mesh_transparent(mesh)


func _find_parent_mesh(node: Node) -> MeshInstance3D:
	var current := node

	while current != null:
		if current is MeshInstance3D:
			return current as MeshInstance3D

		current = current.get_parent()

	return null


func _make_mesh_transparent(mesh: MeshInstance3D) -> void:
	if mesh in faded_meshes:
		return

	if mesh.mesh == null:
		return

	faded_meshes.append(mesh)

	var surface_count := mesh.mesh.get_surface_count()
	var saved_materials: Array[Material] = []

	for i in range(surface_count):
		saved_materials.append(mesh.get_surface_override_material(i))

		var material := mesh.get_active_material(i)

		if material == null:
			continue

		var new_material := material.duplicate()

		if new_material is StandardMaterial3D:
			new_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			new_material.albedo_color.a = transparent_alpha

		mesh.set_surface_override_material(i, new_material)

	original_materials[mesh] = saved_materials


func _restore_faded_meshes() -> void:
	for mesh in faded_meshes:
		if not is_instance_valid(mesh):
			continue

		if not original_materials.has(mesh):
			continue

		var saved_materials: Array = original_materials[mesh]

		for i in range(saved_materials.size()):
			mesh.set_surface_override_material(i, saved_materials[i])

	faded_meshes.clear()
	original_materials.clear()
