extends Node3D

# Projectile Trail - Visual trail effect for projectiles based on active upgrades
# Creates appropriate trail particles based on upgrade type

class_name ProjectileTrail

# Trail configuration
var trail_type: String = "none"
var trail_color: Color = Color.WHITE
var trail_intensity: float = 1.0
var trail_lifetime: float = 0.5

# Particle reference
var trail_particles: GPUParticles3D = null

# Movement tracking for trail
var last_positions: Array[Vector3] = []
var max_trail_points: int = 20
var trail_mesh: ImmediateMesh = null
var trail_mesh_instance: MeshInstance3D = null


func _ready() -> void:
	# Create trail based on type
	_create_trail()


func setup(type: String, color: Color, intensity: float = 1.0) -> void:
	"""Configure the trail"""
	trail_type = type
	trail_color = color
	trail_intensity = intensity

	_create_trail()


func _create_trail() -> void:
	"""Create appropriate trail effect"""
	match trail_type:
		"lightning":
			_create_lightning_trail()
		"fire":
			_create_fire_trail()
		"frost":
			_create_frost_trail()
		"spark":
			_create_spark_trail()
		"beam":
			_create_beam_trail()
		"souls":
			_create_souls_trail()
		"multi":
			_create_multi_trail()
		_:
			# No trail
			pass


func _create_lightning_trail() -> void:
	"""Electric arc trail effect"""
	trail_particles = GPUParticles3D.new()
	trail_particles.name = "LightningTrail"

	trail_particles.amount = int(10 * trail_intensity)
	trail_particles.lifetime = 0.15
	trail_particles.explosiveness = 0.7
	trail_particles.local_coords = false

	var material = ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	material.direction = Vector3(0, 0, 1)
	material.spread = 30.0
	material.initial_velocity_min = 0.2
	material.initial_velocity_max = 0.8
	material.gravity = Vector3.ZERO
	material.damping_min = 5.0
	material.damping_max = 10.0
	material.scale_min = 0.01
	material.scale_max = 0.025
	material.color = trail_color

	trail_particles.process_material = material

	var mesh = QuadMesh.new()
	mesh.size = Vector2(0.02, 0.08)

	var draw_mat = StandardMaterial3D.new()
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.albedo_color = trail_color
	draw_mat.emission_enabled = true
	draw_mat.emission = trail_color
	draw_mat.emission_energy_multiplier = 3.0 * trail_intensity
	draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mesh.material = draw_mat

	trail_particles.draw_pass_1 = mesh
	add_child(trail_particles)


func _create_fire_trail() -> void:
	"""Fire and smoke trail"""
	trail_particles = GPUParticles3D.new()
	trail_particles.name = "FireTrail"

	trail_particles.amount = int(12 * trail_intensity)
	trail_particles.lifetime = 0.4
	trail_particles.explosiveness = 0.0
	trail_particles.local_coords = false

	var material = ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	material.direction = Vector3(0, 0.5, 1)
	material.spread = 20.0
	material.initial_velocity_min = 0.1
	material.initial_velocity_max = 0.3
	material.gravity = Vector3(0, 1.0, 0)
	material.damping_min = 1.0
	material.damping_max = 3.0
	material.scale_min = 0.01
	material.scale_max = 0.03

	var gradient = Gradient.new()
	gradient.set_color(0, trail_color)
	gradient.add_point(0.5, Color(trail_color.r * 0.7, trail_color.g * 0.3, 0.0))
	gradient.set_color(1, Color(0.3, 0.1, 0.0, 0.0))

	var gradient_tex = GradientTexture1D.new()
	gradient_tex.gradient = gradient
	material.color_ramp = gradient_tex

	trail_particles.process_material = material

	var mesh = SphereMesh.new()
	mesh.radius = 0.015
	mesh.height = 0.03

	var draw_mat = StandardMaterial3D.new()
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.albedo_color = trail_color
	draw_mat.emission_enabled = true
	draw_mat.emission = trail_color
	draw_mat.emission_energy_multiplier = 2.5 * trail_intensity
	mesh.material = draw_mat

	trail_particles.draw_pass_1 = mesh
	add_child(trail_particles)


func _create_frost_trail() -> void:
	"""Ice crystal trail"""
	trail_particles = GPUParticles3D.new()
	trail_particles.name = "FrostTrail"

	trail_particles.amount = int(15 * trail_intensity)
	trail_particles.lifetime = 0.6
	trail_particles.explosiveness = 0.0
	trail_particles.local_coords = false

	var material = ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	material.direction = Vector3(0, 0, 1)
	material.spread = 40.0
	material.initial_velocity_min = 0.05
	material.initial_velocity_max = 0.2
	material.gravity = Vector3(0, -0.2, 0)
	material.damping_min = 0.5
	material.damping_max = 2.0
	material.scale_min = 0.008
	material.scale_max = 0.02
	material.angular_velocity_min = -90.0
	material.angular_velocity_max = 90.0
	material.color = trail_color

	trail_particles.process_material = material

	var mesh = QuadMesh.new()
	mesh.size = Vector2(0.015, 0.015)

	var draw_mat = StandardMaterial3D.new()
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.albedo_color = trail_color
	draw_mat.emission_enabled = true
	draw_mat.emission = trail_color
	draw_mat.emission_energy_multiplier = 1.5 * trail_intensity
	draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mesh.material = draw_mat

	trail_particles.draw_pass_1 = mesh
	add_child(trail_particles)


func _create_spark_trail() -> void:
	"""Metallic spark trail for ricochet"""
	trail_particles = GPUParticles3D.new()
	trail_particles.name = "SparkTrail"

	trail_particles.amount = int(8 * trail_intensity)
	trail_particles.lifetime = 0.2
	trail_particles.explosiveness = 0.5
	trail_particles.local_coords = false

	var material = ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	material.direction = Vector3(0, 0, 1)
	material.spread = 60.0
	material.initial_velocity_min = 0.5
	material.initial_velocity_max = 1.5
	material.gravity = Vector3(0, -3.0, 0)
	material.damping_min = 2.0
	material.damping_max = 5.0
	material.scale_min = 0.003
	material.scale_max = 0.01
	material.color = trail_color

	trail_particles.process_material = material

	var mesh = QuadMesh.new()
	mesh.size = Vector2(0.005, 0.04)
	mesh.orientation = PlaneMesh.FACE_Z

	var draw_mat = StandardMaterial3D.new()
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.albedo_color = trail_color
	draw_mat.emission_enabled = true
	draw_mat.emission = trail_color
	draw_mat.emission_energy_multiplier = 4.0 * trail_intensity
	draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mesh.material = draw_mat

	trail_particles.draw_pass_1 = mesh
	add_child(trail_particles)


func _create_beam_trail() -> void:
	"""Laser beam trail for piercing"""
	# Create line-based trail using ImmediateMesh
	trail_mesh = ImmediateMesh.new()
	trail_mesh_instance = MeshInstance3D.new()
	trail_mesh_instance.mesh = trail_mesh

	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = trail_color
	material.emission_enabled = true
	material.emission = trail_color
	material.emission_energy_multiplier = 3.0 * trail_intensity
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	trail_mesh_instance.set_surface_override_material(0, material)
	add_child(trail_mesh_instance)

	# Also add glow particles
	trail_particles = GPUParticles3D.new()
	trail_particles.name = "BeamGlow"
	trail_particles.amount = int(5 * trail_intensity)
	trail_particles.lifetime = 0.3
	trail_particles.explosiveness = 0.0
	trail_particles.local_coords = true

	var particle_mat = ParticleProcessMaterial.new()
	particle_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	particle_mat.gravity = Vector3.ZERO
	particle_mat.scale_min = 0.02
	particle_mat.scale_max = 0.04
	particle_mat.color = trail_color

	trail_particles.process_material = particle_mat

	var mesh = SphereMesh.new()
	mesh.radius = 0.01
	mesh.height = 0.02

	var draw_mat = StandardMaterial3D.new()
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.albedo_color = Color(trail_color.r, trail_color.g, trail_color.b, 0.5)
	draw_mat.emission_enabled = true
	draw_mat.emission = trail_color
	draw_mat.emission_energy_multiplier = 2.0 * trail_intensity
	mesh.material = draw_mat

	trail_particles.draw_pass_1 = mesh
	add_child(trail_particles)


func _create_souls_trail() -> void:
	"""Soul wisp trail for lifesteal"""
	trail_particles = GPUParticles3D.new()
	trail_particles.name = "SoulsTrail"

	trail_particles.amount = int(8 * trail_intensity)
	trail_particles.lifetime = 0.8
	trail_particles.explosiveness = 0.0
	trail_particles.local_coords = false

	var material = ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	material.direction = Vector3(0, 0.3, 1)
	material.spread = 25.0
	material.initial_velocity_min = 0.05
	material.initial_velocity_max = 0.2
	material.gravity = Vector3(0, 0.3, 0)
	material.damping_min = 1.0
	material.damping_max = 2.0
	material.scale_min = 0.015
	material.scale_max = 0.03

	var gradient = Gradient.new()
	gradient.set_color(0, Color(trail_color.r, trail_color.g, trail_color.b, 0.0))
	gradient.add_point(0.2, trail_color)
	gradient.add_point(0.7, trail_color)
	gradient.set_color(1, Color(trail_color.r, trail_color.g * 0.5, trail_color.b * 1.5, 0.0))

	var gradient_tex = GradientTexture1D.new()
	gradient_tex.gradient = gradient
	material.color_ramp = gradient_tex

	trail_particles.process_material = material

	var mesh = SphereMesh.new()
	mesh.radius = 0.01
	mesh.height = 0.02

	var draw_mat = StandardMaterial3D.new()
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.albedo_color = Color(trail_color.r, trail_color.g, trail_color.b, 0.6)
	draw_mat.emission_enabled = true
	draw_mat.emission = trail_color
	draw_mat.emission_energy_multiplier = 2.0 * trail_intensity
	mesh.material = draw_mat

	trail_particles.draw_pass_1 = mesh
	add_child(trail_particles)


func _create_multi_trail() -> void:
	"""Multiple trail effect for burst fire"""
	# Create 3 smaller fire trails
	for i in range(3):
		var sub_trail = GPUParticles3D.new()
		sub_trail.name = "MultiTrail_" + str(i)

		sub_trail.amount = int(5 * trail_intensity)
		sub_trail.lifetime = 0.15
		sub_trail.explosiveness = 0.8
		sub_trail.local_coords = false

		var material = ParticleProcessMaterial.new()
		material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
		material.direction = Vector3(0, 0, 1)
		material.spread = 15.0
		material.initial_velocity_min = 0.3
		material.initial_velocity_max = 0.8
		material.gravity = Vector3.ZERO
		material.damping_min = 8.0
		material.damping_max = 12.0
		material.scale_min = 0.01
		material.scale_max = 0.02
		material.color = trail_color

		sub_trail.process_material = material

		var mesh = QuadMesh.new()
		mesh.size = Vector2(0.02, 0.02)

		var draw_mat = StandardMaterial3D.new()
		draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		draw_mat.albedo_color = trail_color
		draw_mat.emission_enabled = true
		draw_mat.emission = trail_color
		draw_mat.emission_energy_multiplier = 4.0 * trail_intensity
		draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mesh.material = draw_mat

		sub_trail.draw_pass_1 = mesh

		# Offset each sub-trail slightly
		sub_trail.position = Vector3((i - 1) * 0.01, 0, 0)
		add_child(sub_trail)


func _process(delta: float) -> void:
	# Update beam trail if using ImmediateMesh
	if trail_type == "beam" and trail_mesh:
		_update_beam_trail()


func _update_beam_trail() -> void:
	"""Update beam trail mesh with position history"""
	last_positions.push_front(global_position)
	if last_positions.size() > max_trail_points:
		last_positions.resize(max_trail_points)

	if last_positions.size() < 2:
		return

	trail_mesh.clear_surfaces()
	trail_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)

	for i in range(last_positions.size()):
		var alpha = 1.0 - float(i) / float(last_positions.size())
		trail_mesh.surface_set_color(Color(trail_color.r, trail_color.g, trail_color.b, alpha))
		trail_mesh.surface_add_vertex(trail_mesh_instance.to_local(last_positions[i]))

	trail_mesh.surface_end()


func set_emitting(emit: bool) -> void:
	"""Enable/disable particle emission"""
	if trail_particles:
		trail_particles.emitting = emit

	# Handle multi-trail
	for child in get_children():
		if child is GPUParticles3D:
			child.emitting = emit
