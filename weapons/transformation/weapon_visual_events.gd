extends Node

# Weapon Visual Events - Handles weapon firing events and visual feedback
# Connects to weapon signals and triggers appropriate visual effects

class_name WeaponVisualEvents

# References
var weapon: Node3D = null
var transformation_manager: WeaponTransformationManager = null
var parts_manager: WeaponPartsManager = null

# Particle caches for quick access during firing
var muzzle_flash_particles: Array[GPUParticles3D] = []
var trail_particles: Dictionary = {}  # upgrade_id -> GPUParticles3D

# Firing state
var is_firing: bool = false
var last_fire_time: float = 0.0


func _ready() -> void:
	set_process(false)


func setup(parent_weapon: Node3D, trans_manager: WeaponTransformationManager) -> void:
	"""Initialize with weapon and transformation manager"""
	weapon = parent_weapon
	transformation_manager = trans_manager

	if transformation_manager:
		parts_manager = transformation_manager.parts_manager

	# Connect to weapon signals
	_connect_weapon_signals()

	set_process(true)


func _connect_weapon_signals() -> void:
	"""Connect to weapon firing signals"""
	if not weapon:
		return

	# Connect to weapon_fired signal
	if weapon.has_signal("weapon_fired"):
		if not weapon.weapon_fired.is_connected(_on_weapon_fired):
			weapon.weapon_fired.connect(_on_weapon_fired)

	# Connect to hit_enemy signal for absorption effects
	if weapon.has_signal("hit_enemy"):
		if not weapon.hit_enemy.is_connected(_on_hit_enemy):
			weapon.hit_enemy.connect(_on_hit_enemy)

	# Connect to reload signals
	if weapon.has_signal("reload_started"):
		if not weapon.reload_started.is_connected(_on_reload_started):
			weapon.reload_started.connect(_on_reload_started)

	if weapon.has_signal("reload_finished"):
		if not weapon.reload_finished.is_connected(_on_reload_finished):
			weapon.reload_finished.connect(_on_reload_finished)


func _process(delta: float) -> void:
	# Update firing state
	if is_firing:
		var time_since_fire = Time.get_ticks_msec() / 1000.0 - last_fire_time
		if time_since_fire > 0.2:  # Consider not firing after 200ms
			is_firing = false
			_on_stop_firing()


func _on_weapon_fired() -> void:
	"""Called when weapon fires"""
	is_firing = true
	last_fire_time = Time.get_ticks_msec() / 1000.0

	# Trigger upgrade-specific fire effects
	if transformation_manager:
		for upgrade_id in transformation_manager.active_transformations:
			_trigger_fire_effect(upgrade_id)


func _trigger_fire_effect(upgrade_id: String) -> void:
	"""Trigger visual effect for specific upgrade on fire"""
	match upgrade_id:
		"chain_lightning":
			_trigger_electric_flash()
		"explosive_rounds":
			_trigger_explosive_flash()
		"freeze_bullets":
			_trigger_frost_flash()
		"ricochet":
			_trigger_ricochet_flash()
		"piercing_bullets":
			_trigger_piercing_flash()
		"burst_fire":
			_trigger_burst_flash()
		"lifesteal":
			_trigger_lifesteal_fire()


func _trigger_electric_flash() -> void:
	"""Electric arc flash on fire"""
	if parts_manager:
		# Pulse the barrel emission briefly
		_pulse_part_emission("barrel", Color(0.3, 0.9, 1.0), 5.0, 0.1)


func _trigger_explosive_flash() -> void:
	"""Orange explosive flash"""
	if parts_manager:
		_pulse_part_emission("barrel", Color(1.0, 0.5, 0.1), 4.0, 0.15)


func _trigger_frost_flash() -> void:
	"""Frost mist on fire"""
	if parts_manager:
		_pulse_part_emission("barrel", Color(0.6, 0.9, 1.0), 3.0, 0.1)


func _trigger_ricochet_flash() -> void:
	"""Metallic sparkle flash"""
	if parts_manager:
		_pulse_part_emission("barrel", Color(1.0, 1.0, 0.8), 3.0, 0.08)


func _trigger_piercing_flash() -> void:
	"""Golden beam flash"""
	if parts_manager:
		_pulse_part_emission("barrel", Color(1.0, 0.8, 0.2), 4.0, 0.12)


func _trigger_burst_flash() -> void:
	"""Multi-flash for burst fire"""
	if parts_manager:
		# Trigger burst particles
		for particle in _get_muzzle_particles("burst_fire"):
			if is_instance_valid(particle):
				particle.emitting = true
				particle.restart()


func _trigger_lifesteal_fire() -> void:
	"""Organic pulse on fire"""
	if parts_manager:
		_pulse_part_emission("grip", Color(0.6, 0.2, 0.8), 2.5, 0.15)


func _pulse_part_emission(part_type: String, color: Color, strength: float, duration: float) -> void:
	"""Create a brief emission pulse on a part"""
	var mesh = parts_manager.get_part_mesh(part_type)
	if not mesh:
		return

	var material = mesh.get_surface_override_material(0)
	if not material:
		return

	# Store original emission if shader material
	if material is ShaderMaterial:
		var orig_strength = material.get_shader_parameter("emission_strength")
		if orig_strength != null:
			material.set_shader_parameter("emission_strength", strength)

			# Reset after duration
			var timer = get_tree().create_timer(duration)
			timer.timeout.connect(func():
				if is_instance_valid(material):
					material.set_shader_parameter("emission_strength", orig_strength)
			)

	elif material is StandardMaterial3D:
		var orig_energy = material.emission_energy_multiplier
		material.emission_energy_multiplier = strength

		var timer = get_tree().create_timer(duration)
		timer.timeout.connect(func():
			if is_instance_valid(material):
				material.emission_energy_multiplier = orig_energy
		)


func _get_muzzle_particles(upgrade_id: String) -> Array:
	"""Get muzzle particles for an upgrade"""
	if not transformation_manager:
		return []

	var trans_data = transformation_manager.active_transformations.get(upgrade_id, {})
	return trans_data.get("particles", [])


func _on_stop_firing() -> void:
	"""Called when continuous firing stops"""
	pass


func _on_hit_enemy(enemy: Node3D, damage: float, is_kill: bool) -> void:
	"""Called when weapon hits an enemy"""
	if not transformation_manager:
		return

	# Trigger lifesteal absorption effect on hit
	if transformation_manager.has_transformation("lifesteal"):
		_trigger_lifesteal_absorption(enemy.global_position, is_kill)

	# Trigger chain lightning visual (handled by upgrade script, but we can add extra here)
	if transformation_manager.has_transformation("chain_lightning"):
		_trigger_chain_visual_hint(enemy.global_position)


func _trigger_lifesteal_absorption(hit_position: Vector3, is_kill: bool) -> void:
	"""Visual feedback for lifesteal healing"""
	# Create temporary absorption particles at hit location
	var factory = UpgradeParticleFactory.new()
	var intensity = 1.5 if is_kill else 0.8

	var particles = factory.create_soul_absorption(
		Color(0.3, 0.8, 0.3),
		intensity
	)

	if particles and weapon:
		get_tree().current_scene.add_child(particles)
		particles.global_position = hit_position
		particles.one_shot = true
		particles.emitting = true

		# Clean up after lifetime
		var timer = get_tree().create_timer(particles.lifetime + 0.5)
		timer.timeout.connect(func():
			if is_instance_valid(particles):
				particles.queue_free()
		)


func _trigger_chain_visual_hint(hit_position: Vector3) -> void:
	"""Add visual hint for chain lightning (main visual handled by upgrade)"""
	# The chain lightning upgrade handles the main visuals
	# This is for additional subtle effects
	pass


func _on_reload_started() -> void:
	"""Called when reload starts"""
	if not transformation_manager:
		return

	# Fast reload visual feedback
	if transformation_manager.has_transformation("fast_reload"):
		_trigger_fast_reload_animation()


func _trigger_fast_reload_animation() -> void:
	"""Visual animation for fast reload"""
	if not parts_manager:
		return

	# Pulse the magazine holographic effect
	var mesh = parts_manager.get_part_mesh("magazine")
	if not mesh:
		return

	var material = mesh.get_surface_override_material(0)
	if material and material is ShaderMaterial:
		# Speed up scanlines during reload
		var orig_speed = material.get_shader_parameter("scanline_speed")
		if orig_speed != null:
			material.set_shader_parameter("scanline_speed", orig_speed * 3.0)

			# Also add glitch effect
			material.set_shader_parameter("glitch_intensity", 0.3)


func _on_reload_finished() -> void:
	"""Called when reload finishes"""
	if not transformation_manager:
		return

	# Reset fast reload visual
	if transformation_manager.has_transformation("fast_reload"):
		_reset_fast_reload_animation()


func _reset_fast_reload_animation() -> void:
	"""Reset fast reload animation"""
	if not parts_manager:
		return

	var mesh = parts_manager.get_part_mesh("magazine")
	if not mesh:
		return

	var material = mesh.get_surface_override_material(0)
	if material and material is ShaderMaterial:
		var config = UpgradeVisualConfig.get_visual_config("fast_reload")
		material.set_shader_parameter("scanline_speed", 2.0)
		material.set_shader_parameter("glitch_intensity", 0.1)


# === CLEANUP ===

func cleanup() -> void:
	"""Disconnect signals and cleanup"""
	if weapon:
		if weapon.has_signal("weapon_fired") and weapon.weapon_fired.is_connected(_on_weapon_fired):
			weapon.weapon_fired.disconnect(_on_weapon_fired)
		if weapon.has_signal("hit_enemy") and weapon.hit_enemy.is_connected(_on_hit_enemy):
			weapon.hit_enemy.disconnect(_on_hit_enemy)
		if weapon.has_signal("reload_started") and weapon.reload_started.is_connected(_on_reload_started):
			weapon.reload_started.disconnect(_on_reload_started)
		if weapon.has_signal("reload_finished") and weapon.reload_finished.is_connected(_on_reload_finished):
			weapon.reload_finished.disconnect(_on_reload_finished)

	weapon = null
	transformation_manager = null
	parts_manager = null
