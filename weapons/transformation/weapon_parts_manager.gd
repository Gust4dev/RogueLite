extends Node3D

# Weapon Parts Manager - Sistema modular de partes da arma
# Gerencia barrel, magazine, grip, sight e suas transformacoes visuais

class_name WeaponPartsManager

# Signals
signal parts_updated()
signal part_changed(part_type: String, part_index: int)

# Part Types
enum PartType {
	BARREL,
	MAGAZINE,
	GRIP,
	SIGHT
}

# Part references (Node3D containers)
var barrel_node: Node3D = null
var magazine_node: Node3D = null
var grip_node: Node3D = null
var sight_node: Node3D = null
var particles_node: Node3D = null

# Current part indices (for swapping variants)
var current_parts: Dictionary = {
	"barrel": 0,
	"magazine": 0,
	"grip": 0,
	"sight": 0
}

# Part meshes (MeshInstance3D references)
var part_meshes: Dictionary = {
	"barrel": null,
	"magazine": null,
	"grip": null,
	"sight": null
}

# Part materials (for color/emission changes)
var part_materials: Dictionary = {
	"barrel": null,
	"magazine": null,
	"grip": null,
	"sight": null
}

# Original materials backup
var original_materials: Dictionary = {}

# Particle systems attached to parts
var part_particles: Dictionary = {
	"barrel": [],
	"magazine": [],
	"grip": [],
	"sight": [],
	"ambient": []
}

# Active upgrade visuals
var active_visuals: Dictionary = {}

# Reference to parent weapon
var weapon: Node3D = null


func _ready() -> void:
	# Find or create part containers
	_setup_part_containers()


func setup(parent_weapon: Node3D) -> void:
	"""Initialize with weapon reference"""
	weapon = parent_weapon

	# Try to find existing mesh parts in the weapon
	_detect_weapon_parts()

	# NOTE: Placeholder parts desabilitados - causavam geometria extra na tela
	# Se precisar de placeholder parts no futuro, criar uma variável de config
	# if not _has_any_parts():
	#     _create_placeholder_parts()


func _setup_part_containers() -> void:
	"""Create containers for each weapon part"""
	barrel_node = _get_or_create_container("Barrel")
	magazine_node = _get_or_create_container("Magazine")
	grip_node = _get_or_create_container("Grip")
	sight_node = _get_or_create_container("Sight")
	particles_node = _get_or_create_container("Particles")


func _get_or_create_container(container_name: String) -> Node3D:
	"""Gets or creates a part container"""
	var container = get_node_or_null(container_name)
	if not container:
		container = Node3D.new()
		container.name = container_name
		add_child(container)
	return container


func _detect_weapon_parts() -> void:
	"""Try to detect existing mesh parts in weapon model"""
	if not weapon:
		return

	# Search for common mesh naming patterns
	var mesh_names = {
		"barrel": ["barrel", "Barrel", "BARREL", "gun_barrel", "muzzle"],
		"magazine": ["magazine", "Magazine", "MAGAZINE", "mag", "clip"],
		"grip": ["grip", "Grip", "GRIP", "handle", "Handle"],
		"sight": ["sight", "Sight", "SIGHT", "scope", "Scope", "iron_sight"]
	}

	# Find weapon mesh container
	var mesh_container: Node3D = null
	for child in weapon.get_children():
		if child is Node3D and not (child is RayCast3D or "Muzzle" in child.name or "Recoil" in child.name or "Sway" in child.name or child == self):
			mesh_container = child
			break

	if not mesh_container:
		return

	# Search recursively for part meshes
	for part_type in mesh_names:
		for name_pattern in mesh_names[part_type]:
			var found = _find_mesh_by_name(mesh_container, name_pattern)
			if found:
				part_meshes[part_type] = found
				_backup_original_material(part_type, found)
				break


func _find_mesh_by_name(root: Node, name_pattern: String) -> MeshInstance3D:
	"""Recursively find mesh by name pattern"""
	for child in root.get_children():
		if child is MeshInstance3D:
			if name_pattern.to_lower() in child.name.to_lower():
				return child

		# Recurse into children
		var found = _find_mesh_by_name(child, name_pattern)
		if found:
			return found

	return null


func _backup_original_material(part_type: String, mesh: MeshInstance3D) -> void:
	"""Backup original material for restoration"""
	if mesh.get_surface_override_material(0):
		original_materials[part_type] = mesh.get_surface_override_material(0).duplicate()
	elif mesh.mesh and mesh.mesh.surface_get_material(0):
		original_materials[part_type] = mesh.mesh.surface_get_material(0).duplicate()


func _has_any_parts() -> bool:
	"""Check if any parts were detected"""
	for part_type in part_meshes:
		if part_meshes[part_type] != null:
			return true
	return false


func _create_placeholder_parts() -> void:
	"""Create geometric placeholder parts (Programmer Art MVP)"""
	# Barrel - Cylinder
	var barrel_mesh = _create_cylinder_mesh(0.02, 0.3, Color(0.3, 0.3, 0.35))
	barrel_mesh.position = Vector3(0, 0, -0.15)
	barrel_node.add_child(barrel_mesh)
	part_meshes["barrel"] = barrel_mesh
	_backup_original_material("barrel", barrel_mesh)

	# Magazine - Box
	var mag_mesh = _create_box_mesh(Vector3(0.025, 0.08, 0.04), Color(0.25, 0.25, 0.3))
	mag_mesh.position = Vector3(0, -0.06, 0.02)
	magazine_node.add_child(mag_mesh)
	part_meshes["magazine"] = mag_mesh
	_backup_original_material("magazine", mag_mesh)

	# Grip - Box
	var grip_mesh = _create_box_mesh(Vector3(0.025, 0.07, 0.035), Color(0.2, 0.15, 0.1))
	grip_mesh.position = Vector3(0, -0.05, 0.05)
	grip_mesh.rotation_degrees.x = -15
	grip_node.add_child(grip_mesh)
	part_meshes["grip"] = grip_mesh
	_backup_original_material("grip", grip_mesh)

	# Sight - Small box
	var sight_mesh = _create_box_mesh(Vector3(0.015, 0.02, 0.025), Color(0.15, 0.15, 0.15))
	sight_mesh.position = Vector3(0, 0.025, 0)
	sight_node.add_child(sight_mesh)
	part_meshes["sight"] = sight_mesh
	_backup_original_material("sight", sight_mesh)


func _create_cylinder_mesh(radius: float, height: float, color: Color) -> MeshInstance3D:
	"""Create a cylinder mesh with material"""
	var mesh_instance = MeshInstance3D.new()
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = height
	mesh_instance.mesh = cylinder

	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.7
	material.roughness = 0.3
	mesh_instance.set_surface_override_material(0, material)

	# Rotate to point forward (Z axis)
	mesh_instance.rotation_degrees.x = 90

	return mesh_instance


func _create_box_mesh(size: Vector3, color: Color) -> MeshInstance3D:
	"""Create a box mesh with material"""
	var mesh_instance = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box

	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.5
	material.roughness = 0.4
	mesh_instance.set_surface_override_material(0, material)

	return mesh_instance


# === PART VISUAL MODIFICATION ===

func set_part_color(part_type: String, color: Color, emission_strength: float = 0.0) -> void:
	"""Set color for a specific part"""
	var mesh = part_meshes.get(part_type)
	if not mesh:
		return

	var material = _get_or_create_material(mesh)
	if material:
		material.albedo_color = color
		material.emission_enabled = emission_strength > 0
		if emission_strength > 0:
			material.emission = color
			material.emission_energy_multiplier = emission_strength


func set_part_emission(part_type: String, color: Color, strength: float) -> void:
	"""Set emission/glow for a specific part"""
	var mesh = part_meshes.get(part_type)
	if not mesh:
		return

	var material = _get_or_create_material(mesh)
	if material:
		material.emission_enabled = strength > 0
		material.emission = color
		material.emission_energy_multiplier = strength


func apply_shader_to_part(part_type: String, shader: Shader, params: Dictionary = {}) -> void:
	"""Apply a custom shader to a part"""
	var mesh = part_meshes.get(part_type)
	if not mesh:
		return

	var shader_material = ShaderMaterial.new()
	shader_material.shader = shader

	for param_name in params:
		shader_material.set_shader_parameter(param_name, params[param_name])

	mesh.set_surface_override_material(0, shader_material)
	part_materials[part_type] = shader_material


func _get_or_create_material(mesh: MeshInstance3D) -> StandardMaterial3D:
	"""Get existing material or create new one"""
	var material = mesh.get_surface_override_material(0)

	if material and material is StandardMaterial3D:
		return material

	# Create new material
	var new_material = StandardMaterial3D.new()
	new_material.metallic = 0.5
	new_material.roughness = 0.4
	mesh.set_surface_override_material(0, new_material)

	return new_material


# === PARTICLE SYSTEMS ===

func add_particles_to_part(part_type: String, particles: GPUParticles3D) -> void:
	"""Add a particle system to a part"""
	var container = _get_part_container(part_type)
	if container:
		container.add_child(particles)
		part_particles[part_type].append(particles)


func remove_particles_from_part(part_type: String) -> void:
	"""Remove all particles from a part"""
	for particle in part_particles.get(part_type, []):
		if is_instance_valid(particle):
			particle.queue_free()
	part_particles[part_type] = []


func add_ambient_particles(particles: GPUParticles3D) -> void:
	"""Add ambient particles (not attached to specific part)"""
	particles_node.add_child(particles)
	part_particles["ambient"].append(particles)


func clear_all_particles() -> void:
	"""Remove all particle systems"""
	for part_type in part_particles:
		for particle in part_particles[part_type]:
			if is_instance_valid(particle):
				particle.queue_free()
		part_particles[part_type] = []


func _get_part_container(part_type: String) -> Node3D:
	"""Get container node for part type"""
	match part_type:
		"barrel": return barrel_node
		"magazine": return magazine_node
		"grip": return grip_node
		"sight": return sight_node
		_: return particles_node


# === PART TRANSFORMATIONS ===

func scale_part(part_type: String, scale_factor: Vector3) -> void:
	"""Scale a specific part"""
	var mesh = part_meshes.get(part_type)
	if mesh:
		mesh.scale = scale_factor


func offset_part(part_type: String, offset: Vector3) -> void:
	"""Offset a part position"""
	var mesh = part_meshes.get(part_type)
	if mesh:
		mesh.position += offset


func rotate_part(part_type: String, rotation: Vector3) -> void:
	"""Rotate a part"""
	var mesh = part_meshes.get(part_type)
	if mesh:
		mesh.rotation_degrees += rotation


# === RESET FUNCTIONALITY ===

func reset_part(part_type: String) -> void:
	"""Reset a part to original state"""
	var mesh = part_meshes.get(part_type)
	if not mesh:
		return

	# Restore original material
	if part_type in original_materials:
		mesh.set_surface_override_material(0, original_materials[part_type].duplicate())

	# Remove particles
	remove_particles_from_part(part_type)


func reset_all_parts() -> void:
	"""Reset all parts to original state"""
	for part_type in part_meshes:
		reset_part(part_type)

	clear_all_particles()
	active_visuals.clear()


# === UPGRADE VISUAL TRACKING ===

func register_visual(upgrade_id: String, visual_data: Dictionary) -> void:
	"""Register an upgrade's visual modifications"""
	active_visuals[upgrade_id] = visual_data


func unregister_visual(upgrade_id: String) -> void:
	"""Unregister an upgrade's visual modifications"""
	if upgrade_id in active_visuals:
		active_visuals.erase(upgrade_id)


func get_active_visuals() -> Dictionary:
	"""Get all active visual modifications"""
	return active_visuals


# === UTILITY ===

func get_barrel_tip_position() -> Vector3:
	"""Get world position of barrel tip (for muzzle effects)"""
	var mesh = part_meshes.get("barrel")
	if mesh:
		return mesh.global_position + mesh.global_transform.basis.z * -0.15
	return global_position


func get_part_mesh(part_type: String) -> MeshInstance3D:
	"""Get mesh reference for a part"""
	return part_meshes.get(part_type)
