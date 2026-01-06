extends RefCounted

# Upgrade Particle Factory - Creates particle systems for each upgrade type
# Generates GPU particle systems with appropriate visual effects

class_name UpgradeParticleFactory


# === CHAIN LIGHTNING - Electric Arcs ===

func create_electric_arcs(color: Color, intensity: float) -> GPUParticles3D:
	"""Create electric arc particles for Chain Lightning"""
	var particles = GPUParticles3D.new()
	particles.name = "ElectricArcs"

	# Particle settings
	particles.amount = int(8 * intensity)
	particles.lifetime = 0.15
	particles.explosiveness = 0.8
	particles.randomness = 0.5
	particles.fixed_fps = 60
	particles.local_coords = true

	# Process material
	var material = ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = Vector3(0.03, 0.03, 0.15)

	material.direction = Vector3(0, 0, -1)
	material.spread = 30.0
	material.initial_velocity_min = 0.5
	material.initial_velocity_max = 2.0

	material.gravity = Vector3.ZERO
	material.damping_min = 5.0
	material.damping_max = 10.0

	material.scale_min = 0.01
	material.scale_max = 0.03

	material.color = color

	particles.process_material = material

	# Draw pass - simple quad for lightning look
	var mesh = QuadMesh.new()
	mesh.size = Vector2(0.02, 0.1)

	var draw_mat = StandardMaterial3D.new()
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.albedo_color = color
	draw_mat.emission_enabled = true
	draw_mat.emission = color
	draw_mat.emission_energy_multiplier = 3.0 * intensity
	draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mesh.material = draw_mat

	particles.draw_pass_1 = mesh

	return particles


# === EXPLOSIVE ROUNDS - Embers ===

func create_embers(color: Color, intensity: float) -> GPUParticles3D:
	"""Create ember particles for Explosive Rounds"""
	var particles = GPUParticles3D.new()
	particles.name = "Embers"

	particles.amount = int(15 * intensity)
	particles.lifetime = 1.5
	particles.explosiveness = 0.0
	particles.randomness = 0.8
	particles.fixed_fps = 30
	particles.local_coords = true

	var material = ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 0.05

	material.direction = Vector3(0, 1, -0.5)
	material.spread = 45.0
	material.initial_velocity_min = 0.1
	material.initial_velocity_max = 0.3

	material.gravity = Vector3(0, 0.5, 0)  # Float upward
	material.damping_min = 1.0
	material.damping_max = 2.0

	material.scale_min = 0.005
	material.scale_max = 0.015

	# Color gradient (orange to red to transparent)
	var gradient = Gradient.new()
	gradient.set_color(0, color)
	gradient.add_point(0.5, Color(color.r * 0.8, color.g * 0.3, color.b * 0.1))
	gradient.set_color(1, Color(0.5, 0.1, 0.0, 0.0))

	var gradient_tex = GradientTexture1D.new()
	gradient_tex.gradient = gradient
	material.color_ramp = gradient_tex

	particles.process_material = material

	# Sphere mesh for embers
	var mesh = SphereMesh.new()
	mesh.radius = 0.01
	mesh.height = 0.02

	var draw_mat = StandardMaterial3D.new()
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.albedo_color = color
	draw_mat.emission_enabled = true
	draw_mat.emission = color
	draw_mat.emission_energy_multiplier = 4.0 * intensity
	mesh.material = draw_mat

	particles.draw_pass_1 = mesh

	return particles


# === FREEZE BULLETS - Snowflakes ===

func create_snowflakes(color: Color, intensity: float) -> GPUParticles3D:
	"""Create snowflake particles for Freeze Bullets"""
	var particles = GPUParticles3D.new()
	particles.name = "Snowflakes"

	particles.amount = int(20 * intensity)
	particles.lifetime = 2.0
	particles.explosiveness = 0.0
	particles.randomness = 0.9
	particles.fixed_fps = 30
	particles.local_coords = true

	var material = ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = Vector3(0.08, 0.08, 0.2)

	material.direction = Vector3(0, -0.5, -0.3)
	material.spread = 60.0
	material.initial_velocity_min = 0.05
	material.initial_velocity_max = 0.15

	material.gravity = Vector3(0, -0.1, 0)
	material.damping_min = 0.5
	material.damping_max = 1.5

	material.scale_min = 0.008
	material.scale_max = 0.02

	# Angular velocity for spinning
	material.angular_velocity_min = -180.0
	material.angular_velocity_max = 180.0

	# Fade out
	var gradient = Gradient.new()
	gradient.set_color(0, Color(color.r, color.g, color.b, 0.0))
	gradient.add_point(0.1, color)
	gradient.add_point(0.8, color)
	gradient.set_color(1, Color(color.r, color.g, color.b, 0.0))

	var gradient_tex = GradientTexture1D.new()
	gradient_tex.gradient = gradient
	material.color_ramp = gradient_tex

	particles.process_material = material

	# Quad mesh for snowflakes
	var mesh = QuadMesh.new()
	mesh.size = Vector2(0.015, 0.015)

	var draw_mat = StandardMaterial3D.new()
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.albedo_color = color
	draw_mat.emission_enabled = true
	draw_mat.emission = color
	draw_mat.emission_energy_multiplier = 1.5 * intensity
	draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mesh.material = draw_mat

	particles.draw_pass_1 = mesh

	return particles


# === RICOCHET - Sparks ===

func create_sparks(color: Color, intensity: float) -> GPUParticles3D:
	"""Create spark particles for Ricochet"""
	var particles = GPUParticles3D.new()
	particles.name = "Sparks"

	particles.amount = int(12 * intensity)
	particles.lifetime = 0.3
	particles.explosiveness = 0.6
	particles.randomness = 0.7
	particles.fixed_fps = 60
	particles.local_coords = false

	var material = ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT

	material.direction = Vector3(0, 0, -1)
	material.spread = 90.0
	material.initial_velocity_min = 1.0
	material.initial_velocity_max = 3.0

	material.gravity = Vector3(0, -5.0, 0)
	material.damping_min = 2.0
	material.damping_max = 4.0

	material.scale_min = 0.003
	material.scale_max = 0.008

	material.color = color

	# Quick fade
	var gradient = Gradient.new()
	gradient.set_color(0, color)
	gradient.set_color(1, Color(color.r, color.g, color.b, 0.0))

	var gradient_tex = GradientTexture1D.new()
	gradient_tex.gradient = gradient
	material.color_ramp = gradient_tex

	particles.process_material = material

	# Stretched quad for spark trails
	var mesh = QuadMesh.new()
	mesh.size = Vector2(0.005, 0.05)
	mesh.orientation = PlaneMesh.FACE_Z

	var draw_mat = StandardMaterial3D.new()
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.albedo_color = color
	draw_mat.emission_enabled = true
	draw_mat.emission = color
	draw_mat.emission_energy_multiplier = 5.0 * intensity
	draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mesh.material = draw_mat

	particles.draw_pass_1 = mesh

	return particles


# === PIERCING - Laser Glow ===

func create_laser_glow(color: Color, intensity: float) -> GPUParticles3D:
	"""Create laser sight glow for Piercing Bullets"""
	var particles = GPUParticles3D.new()
	particles.name = "LaserGlow"

	particles.amount = int(5 * intensity)
	particles.lifetime = 0.5
	particles.explosiveness = 0.0
	particles.randomness = 0.2
	particles.fixed_fps = 30
	particles.local_coords = true

	var material = ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT

	material.direction = Vector3(0, 0, -1)
	material.spread = 5.0
	material.initial_velocity_min = 0.0
	material.initial_velocity_max = 0.1

	material.gravity = Vector3.ZERO
	material.damping_min = 5.0
	material.damping_max = 10.0

	material.scale_min = 0.01
	material.scale_max = 0.02

	material.color = color

	particles.process_material = material

	# Sphere for glow
	var mesh = SphereMesh.new()
	mesh.radius = 0.01
	mesh.height = 0.02

	var draw_mat = StandardMaterial3D.new()
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.albedo_color = Color(color.r, color.g, color.b, 0.5)
	draw_mat.emission_enabled = true
	draw_mat.emission = color
	draw_mat.emission_energy_multiplier = 3.0 * intensity
	mesh.material = draw_mat

	particles.draw_pass_1 = mesh

	return particles


# === FAST RELOAD - Tech Bits ===

func create_tech_bits(color: Color, intensity: float) -> GPUParticles3D:
	"""Create tech data bits for Fast Reload"""
	var particles = GPUParticles3D.new()
	particles.name = "TechBits"

	particles.amount = int(10 * intensity)
	particles.lifetime = 0.8
	particles.explosiveness = 0.3
	particles.randomness = 0.6
	particles.fixed_fps = 30
	particles.local_coords = true

	var material = ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = Vector3(0.02, 0.05, 0.02)

	material.direction = Vector3(0, 1, 0)
	material.spread = 20.0
	material.initial_velocity_min = 0.1
	material.initial_velocity_max = 0.3

	material.gravity = Vector3(0, 0.2, 0)
	material.damping_min = 2.0
	material.damping_max = 4.0

	material.scale_min = 0.003
	material.scale_max = 0.008

	# Flickering effect through alpha
	var gradient = Gradient.new()
	gradient.set_color(0, Color(color.r, color.g, color.b, 0.0))
	gradient.add_point(0.1, color)
	gradient.add_point(0.3, Color(color.r, color.g, color.b, 0.3))
	gradient.add_point(0.5, color)
	gradient.add_point(0.7, Color(color.r, color.g, color.b, 0.3))
	gradient.set_color(1, Color(color.r, color.g, color.b, 0.0))

	var gradient_tex = GradientTexture1D.new()
	gradient_tex.gradient = gradient
	material.color_ramp = gradient_tex

	particles.process_material = material

	# Small box for digital look
	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.005, 0.005, 0.001)

	var draw_mat = StandardMaterial3D.new()
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.albedo_color = color
	draw_mat.emission_enabled = true
	draw_mat.emission = color
	draw_mat.emission_energy_multiplier = 2.0 * intensity
	mesh.material = draw_mat

	particles.draw_pass_1 = mesh

	return particles


# === BURST FIRE - Muzzle Burst ===

func create_muzzle_burst(color: Color, intensity: float) -> GPUParticles3D:
	"""Create enhanced muzzle flash for Burst Fire"""
	var particles = GPUParticles3D.new()
	particles.name = "MuzzleBurst"

	particles.amount = int(15 * intensity)
	particles.lifetime = 0.1
	particles.explosiveness = 1.0
	particles.one_shot = false
	particles.fixed_fps = 60
	particles.local_coords = true

	var material = ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT

	material.direction = Vector3(0, 0, -1)
	material.spread = 25.0
	material.initial_velocity_min = 2.0
	material.initial_velocity_max = 5.0

	material.gravity = Vector3.ZERO
	material.damping_min = 10.0
	material.damping_max = 20.0

	material.scale_min = 0.01
	material.scale_max = 0.04

	material.color = color

	particles.process_material = material

	# Quad for flash
	var mesh = QuadMesh.new()
	mesh.size = Vector2(0.03, 0.03)

	var draw_mat = StandardMaterial3D.new()
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.albedo_color = color
	draw_mat.emission_enabled = true
	draw_mat.emission = color
	draw_mat.emission_energy_multiplier = 6.0 * intensity
	draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mesh.material = draw_mat

	particles.draw_pass_1 = mesh

	# Don't emit constantly - will be triggered by firing
	particles.emitting = false

	return particles


# === LIFESTEAL - Soul Absorption ===

func create_soul_absorption(color: Color, intensity: float) -> GPUParticles3D:
	"""Create soul/energy absorption particles for Lifesteal"""
	var particles = GPUParticles3D.new()
	particles.name = "SoulAbsorption"

	particles.amount = int(12 * intensity)
	particles.lifetime = 1.0
	particles.explosiveness = 0.0
	particles.randomness = 0.7
	particles.fixed_fps = 30
	particles.local_coords = true

	var material = ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 0.15

	# Move toward center (inward attraction)
	material.direction = Vector3(0, 0, 0)
	material.spread = 180.0
	material.initial_velocity_min = -0.3  # Negative = inward
	material.initial_velocity_max = -0.1

	material.gravity = Vector3.ZERO

	# Radial acceleration toward center
	material.radial_accel_min = -2.0
	material.radial_accel_max = -1.0

	material.scale_min = 0.01
	material.scale_max = 0.03

	# Fade in then out, shrink at end
	var gradient = Gradient.new()
	gradient.set_color(0, Color(color.r, color.g, color.b, 0.0))
	gradient.add_point(0.2, color)
	gradient.add_point(0.7, color)
	gradient.set_color(1, Color(color.r * 1.5, color.g * 0.5, color.b, 0.0))

	var gradient_tex = GradientTexture1D.new()
	gradient_tex.gradient = gradient
	material.color_ramp = gradient_tex

	# Scale curve - shrink as approaching center
	var scale_curve = Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.5))
	scale_curve.add_point(Vector2(0.5, 1.0))
	scale_curve.add_point(Vector2(1.0, 0.0))

	var scale_tex = CurveTexture.new()
	scale_tex.curve = scale_curve
	material.scale_curve = scale_tex

	particles.process_material = material

	# Wispy sphere for soul look
	var mesh = SphereMesh.new()
	mesh.radius = 0.015
	mesh.height = 0.03

	var draw_mat = StandardMaterial3D.new()
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.albedo_color = Color(color.r, color.g, color.b, 0.7)
	draw_mat.emission_enabled = true
	draw_mat.emission = color
	draw_mat.emission_energy_multiplier = 2.5 * intensity
	mesh.material = draw_mat

	particles.draw_pass_1 = mesh

	return particles


# === TRAIL PARTICLES (for projectile trails) ===

func create_trail_particles(trail_type: String, color: Color, intensity: float) -> GPUParticles3D:
	"""Create trail particles based on type"""
	match trail_type:
		"lightning":
			return _create_lightning_trail(color, intensity)
		"fire":
			return _create_fire_trail(color, intensity)
		"frost":
			return _create_frost_trail(color, intensity)
		"spark":
			return _create_spark_trail(color, intensity)
		"beam":
			return _create_beam_trail(color, intensity)
		"souls":
			return _create_souls_trail(color, intensity)
		_:
			return null


func _create_lightning_trail(color: Color, intensity: float) -> GPUParticles3D:
	"""Lightning bolt trail"""
	var particles = create_electric_arcs(color, intensity * 0.5)
	particles.name = "LightningTrail"
	particles.amount = int(particles.amount * 0.5)
	return particles


func _create_fire_trail(color: Color, intensity: float) -> GPUParticles3D:
	"""Fire/smoke trail"""
	var particles = create_embers(color, intensity * 0.7)
	particles.name = "FireTrail"
	return particles


func _create_frost_trail(color: Color, intensity: float) -> GPUParticles3D:
	"""Ice crystal trail"""
	var particles = create_snowflakes(color, intensity * 0.6)
	particles.name = "FrostTrail"
	particles.lifetime = 0.5
	return particles


func _create_spark_trail(color: Color, intensity: float) -> GPUParticles3D:
	"""Metallic spark trail"""
	var particles = create_sparks(color, intensity)
	particles.name = "SparkTrail"
	return particles


func _create_beam_trail(color: Color, intensity: float) -> GPUParticles3D:
	"""Laser beam trail"""
	var particles = create_laser_glow(color, intensity * 1.5)
	particles.name = "BeamTrail"
	return particles


func _create_souls_trail(color: Color, intensity: float) -> GPUParticles3D:
	"""Soul wisp trail"""
	var particles = GPUParticles3D.new()
	particles.name = "SoulsTrail"

	particles.amount = int(6 * intensity)
	particles.lifetime = 0.6
	particles.explosiveness = 0.0
	particles.local_coords = false

	var material = ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT

	material.direction = Vector3(0, 0.5, 1)
	material.spread = 30.0
	material.initial_velocity_min = 0.1
	material.initial_velocity_max = 0.3

	material.gravity = Vector3(0, 0.5, 0)
	material.damping_min = 2.0
	material.damping_max = 3.0

	material.scale_min = 0.01
	material.scale_max = 0.025

	material.color = color

	particles.process_material = material

	var mesh = SphereMesh.new()
	mesh.radius = 0.01
	mesh.height = 0.02

	var draw_mat = StandardMaterial3D.new()
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.albedo_color = Color(color.r, color.g, color.b, 0.6)
	draw_mat.emission_enabled = true
	draw_mat.emission = color
	draw_mat.emission_energy_multiplier = 2.0 * intensity
	mesh.material = draw_mat

	particles.draw_pass_1 = mesh

	return particles
