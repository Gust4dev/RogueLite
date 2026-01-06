extends Node

# Weapon Transformation Manager - Central manager for weapon visual transformations
# Handles upgrade visuals, shader application, particles, and combination rules

class_name WeaponTransformationManager

# Signals
signal transformation_applied(upgrade_id: String, level: int)
signal transformation_removed(upgrade_id: String)
signal all_transformations_updated()

# References
var weapon: Node3D = null
var parts_manager: WeaponPartsManager = null

# Cached shaders
var shader_cache: Dictionary = {}

# Active transformations
var active_transformations: Dictionary = {}  # upgrade_id -> {level, visual_nodes}

# Particle factory
var particle_factory: UpgradeParticleFactory = null

# Animation tweens
var active_tweens: Dictionary = {}


func _ready() -> void:
	# Preload common shaders
	_preload_shaders()

	# Create particle factory
	particle_factory = UpgradeParticleFactory.new()


func _preload_shaders() -> void:
	"""Preload all upgrade shaders"""
	var shader_names = [
		"emissive_glow",
		"fresnel_edge",
		"ice_frost",
		"holographic",
		"organic_lifesteal",
		"metallic_reflection"
	]

	for shader_name in shader_names:
		var path = UpgradeVisualConfig.get_shader_path(shader_name)
		if ResourceLoader.exists(path):
			shader_cache[shader_name] = load(path)


func setup(target_weapon: Node3D) -> void:
	"""Initialize with target weapon"""
	weapon = target_weapon

	# Find or create parts manager
	parts_manager = weapon.get_node_or_null("WeaponPartsManager")
	if not parts_manager:
		parts_manager = WeaponPartsManager.new()
		parts_manager.name = "WeaponPartsManager"
		weapon.add_child(parts_manager)
		parts_manager.setup(weapon)


func apply_upgrade_visual(upgrade_id: String, level: int) -> void:
	"""Apply visual transformation for an upgrade"""
	if not weapon or not parts_manager:
		push_error("WeaponTransformationManager: No weapon or parts manager set")
		return

	var config = UpgradeVisualConfig.get_visual_config(upgrade_id)
	if config.is_empty():
		push_warning("No visual config found for upgrade: " + upgrade_id)
		return

	# Store transformation data
	active_transformations[upgrade_id] = {
		"level": level,
		"config": config,
		"particles": [],
		"materials": []
	}

	# Apply based on upgrade type
	match upgrade_id:
		"chain_lightning":
			_apply_chain_lightning_visual(level)
		"explosive_rounds":
			_apply_explosive_visual(level)
		"freeze_bullets":
			_apply_freeze_visual(level)
		"ricochet":
			_apply_ricochet_visual(level)
		"piercing_bullets":
			_apply_piercing_visual(level)
		"fast_reload":
			_apply_fast_reload_visual(level)
		"burst_fire":
			_apply_burst_fire_visual(level)
		"lifesteal":
			_apply_lifesteal_visual(level)

	# Update combination visuals
	_update_combined_visuals()

	transformation_applied.emit(upgrade_id, level)


func remove_upgrade_visual(upgrade_id: String) -> void:
	"""Remove visual transformation for an upgrade"""
	if not upgrade_id in active_transformations:
		return

	var data = active_transformations[upgrade_id]

	# Remove particles
	for particle in data.get("particles", []):
		if is_instance_valid(particle):
			particle.queue_free()

	# Clean up materials/shaders
	for node in data.get("material_nodes", []):
		if is_instance_valid(node):
			_reset_node_material(node)

	# Remove from active
	active_transformations.erase(upgrade_id)

	# Update remaining visuals
	_update_combined_visuals()

	transformation_removed.emit(upgrade_id)


func update_upgrade_level(upgrade_id: String, new_level: int) -> void:
	"""Update visual intensity for level change"""
	if upgrade_id in active_transformations:
		# Remove and reapply with new level
		remove_upgrade_visual(upgrade_id)
	apply_upgrade_visual(upgrade_id, new_level)


func clear_all_transformations() -> void:
	"""Remove all visual transformations"""
	var upgrade_ids = active_transformations.keys()
	for upgrade_id in upgrade_ids:
		remove_upgrade_visual(upgrade_id)

	if parts_manager:
		parts_manager.reset_all_parts()


# === SPECIFIC UPGRADE VISUALS ===

func _apply_chain_lightning_visual(level: int) -> void:
	"""Chain Lightning: Blue electric arcs, cyan glow on barrel"""
	var config = UpgradeVisualConfig.get_visual_config("chain_lightning")

	# Apply emissive glow to barrel
	var emission_strength = UpgradeVisualConfig.get_scaled_emission("chain_lightning", level)
	_apply_shader_to_part("barrel", "emissive_glow", {
		"emission_color": config["emission_color"],
		"emission_strength": emission_strength,
		"pulse_speed": config["pulse_speed"],
		"enable_pulse": true
	})

	# Add electric arc particles
	var particles = particle_factory.create_electric_arcs(
		config["particles"]["color"],
		UpgradeVisualConfig.get_scaled_particle_intensity("chain_lightning", level)
	)
	if particles:
		parts_manager.add_particles_to_part("barrel", particles)
		active_transformations["chain_lightning"]["particles"].append(particles)


func _apply_explosive_visual(level: int) -> void:
	"""Explosive Rounds: Orange/red glow, embers from barrel"""
	var config = UpgradeVisualConfig.get_visual_config("explosive_rounds")

	# Glowing orange magazine
	parts_manager.set_part_color(
		"magazine",
		config["primary_color"],
		UpgradeVisualConfig.get_scaled_emission("explosive_rounds", level) * 0.5
	)

	# Barrel tip ring glow
	_apply_shader_to_part("barrel", "emissive_glow", {
		"emission_color": config["emission_color"],
		"emission_strength": UpgradeVisualConfig.get_scaled_emission("explosive_rounds", level),
		"pulse_speed": config["pulse_speed"],
		"pulse_min": 0.5,
		"pulse_max": 1.0
	})

	# Add ember particles
	var particles = particle_factory.create_embers(
		config["particles"]["color"],
		UpgradeVisualConfig.get_scaled_particle_intensity("explosive_rounds", level)
	)
	if particles:
		parts_manager.add_particles_to_part("barrel", particles)
		active_transformations["explosive_rounds"]["particles"].append(particles)


func _apply_freeze_visual(level: int) -> void:
	"""Freeze Bullets: Ice shader on barrel, snowflake particles"""
	var config = UpgradeVisualConfig.get_visual_config("freeze_bullets")

	# Ice frost shader on barrel
	var frost_coverage = 0.5 + level * 0.15  # More ice at higher levels
	_apply_shader_to_part("barrel", "ice_frost", {
		"ice_color": config["primary_color"],
		"deep_ice_color": config["secondary_color"],
		"frost_coverage": frost_coverage,
		"emission_strength": UpgradeVisualConfig.get_scaled_emission("freeze_bullets", level),
		"animate_frost": true
	})

	# Snowflake particles
	var particles = particle_factory.create_snowflakes(
		config["particles"]["color"],
		UpgradeVisualConfig.get_scaled_particle_intensity("freeze_bullets", level)
	)
	if particles:
		parts_manager.add_particles_to_part("barrel", particles)
		active_transformations["freeze_bullets"]["particles"].append(particles)


func _apply_ricochet_visual(level: int) -> void:
	"""Ricochet: Chrome/mirror shader, angular facets"""
	var config = UpgradeVisualConfig.get_visual_config("ricochet")

	# Metallic reflection shader
	_apply_shader_to_part("barrel", "metallic_reflection", {
		"metal_color": config["primary_color"],
		"tint_color": config["secondary_color"],
		"metallic": 1.0,
		"roughness": 0.05,
		"show_facets": true,
		"facet_intensity": 0.1 + level * 0.1
	})

	# Scale barrel to be more angular
	parts_manager.scale_part("barrel", Vector3(0.9, 0.9, 1.0))

	# Spark particles on ambient
	var particles = particle_factory.create_sparks(
		config["particles"]["color"],
		UpgradeVisualConfig.get_scaled_particle_intensity("ricochet", level) * 0.5
	)
	if particles:
		parts_manager.add_ambient_particles(particles)
		active_transformations["ricochet"]["particles"].append(particles)


func _apply_piercing_visual(level: int) -> void:
	"""Piercing: Gold glow, longer barrel, laser sight"""
	var config = UpgradeVisualConfig.get_visual_config("piercing_bullets")

	# Fresnel gold glow
	_apply_shader_to_part("barrel", "fresnel_edge", {
		"fresnel_color": config["emission_color"],
		"fresnel_power": 3.0,
		"fresnel_strength": UpgradeVisualConfig.get_scaled_emission("piercing_bullets", level),
		"inner_color": config["secondary_color"],
		"inner_strength": 0.3 + level * 0.2
	})

	# Longer, thinner barrel
	parts_manager.scale_part("barrel", Vector3(0.8, 0.8, 1.2 + level * 0.1))

	# Add laser sight glow (simple particles)
	var particles = particle_factory.create_laser_glow(
		Color(1.0, 0.2, 0.2),  # Red laser
		0.3 + level * 0.2
	)
	if particles:
		parts_manager.add_particles_to_part("sight", particles)
		active_transformations["piercing_bullets"]["particles"].append(particles)


func _apply_fast_reload_visual(level: int) -> void:
	"""Fast Reload: Holographic magazine, tech aesthetic"""
	var config = UpgradeVisualConfig.get_visual_config("fast_reload")

	# Holographic shader on magazine
	var transparency = 0.5 - level * 0.1  # More solid at higher levels
	_apply_shader_to_part("magazine", "holographic", {
		"primary_color": config["primary_color"],
		"secondary_color": config["secondary_color"],
		"transparency": transparency,
		"scanline_speed": 2.0 + level * 0.5,
		"show_leds": level >= 2,
		"led_intensity": level * 0.3
	})

	# Tech bit particles
	var particles = particle_factory.create_tech_bits(
		config["particles"]["color"],
		UpgradeVisualConfig.get_scaled_particle_intensity("fast_reload", level)
	)
	if particles:
		parts_manager.add_particles_to_part("magazine", particles)
		active_transformations["fast_reload"]["particles"].append(particles)


func _apply_burst_fire_visual(level: int) -> void:
	"""Burst Fire: Dark red glow, rapid pulse, multi-port barrel"""
	var config = UpgradeVisualConfig.get_visual_config("burst_fire")

	# Fast pulsing emissive on barrel
	_apply_shader_to_part("barrel", "emissive_glow", {
		"albedo_color": config["secondary_color"],
		"emission_color": config["emission_color"],
		"emission_strength": UpgradeVisualConfig.get_scaled_emission("burst_fire", level),
		"pulse_speed": config["pulse_speed"] + level * 2.0,  # Faster at higher levels
		"pulse_min": 0.4,
		"pulse_max": 1.0
	})

	# Muzzle burst particles (more intense)
	var particles = particle_factory.create_muzzle_burst(
		config["particles"]["color"],
		UpgradeVisualConfig.get_scaled_particle_intensity("burst_fire", level)
	)
	if particles:
		parts_manager.add_particles_to_part("barrel", particles)
		active_transformations["burst_fire"]["particles"].append(particles)


func _apply_lifesteal_visual(level: int) -> void:
	"""Lifesteal: Organic shader, green/purple veins, soul absorption"""
	var config = UpgradeVisualConfig.get_visual_config("lifesteal")

	# Organic shader on grip and magazine
	var vein_intensity = 0.7 + level * 0.3
	_apply_shader_to_part("grip", "organic_lifesteal", {
		"base_color": config["primary_color"],
		"vein_color": config["secondary_color"],
		"glow_color": config["emission_color"],
		"vein_intensity": vein_intensity,
		"heartbeat_intensity": 0.3 + level * 0.1
	})

	_apply_shader_to_part("magazine", "organic_lifesteal", {
		"base_color": config["primary_color"],
		"vein_color": config["secondary_color"],
		"glow_color": config["emission_color"],
		"vein_intensity": vein_intensity * 0.7,
		"heartbeat_intensity": 0.2 + level * 0.1
	})

	# Soul absorption particles
	var particles = particle_factory.create_soul_absorption(
		config["particles"]["color"],
		UpgradeVisualConfig.get_scaled_particle_intensity("lifesteal", level)
	)
	if particles:
		parts_manager.add_ambient_particles(particles)
		active_transformations["lifesteal"]["particles"].append(particles)


# === SHADER APPLICATION ===

func _apply_shader_to_part(part_type: String, shader_name: String, params: Dictionary) -> void:
	"""Apply a shader with parameters to a weapon part"""
	if not shader_name in shader_cache:
		push_warning("Shader not found in cache: " + shader_name)
		return

	var shader = shader_cache[shader_name]
	parts_manager.apply_shader_to_part(part_type, shader, params)


func _reset_node_material(node: Node3D) -> void:
	"""Reset a node to its original material"""
	if node is MeshInstance3D:
		var mesh_node = node as MeshInstance3D
		mesh_node.set_surface_override_material(0, null)


# === COMBINATION SYSTEM ===

func _update_combined_visuals() -> void:
	"""Update visuals when multiple upgrades are active"""
	if active_transformations.size() <= 1:
		return

	var active_ids = active_transformations.keys()

	# Determine dominant upgrade for each part
	for part_type in ["barrel", "magazine", "grip", "sight"]:
		var dominant = UpgradeVisualConfig.get_dominant_upgrade_for_part(part_type, active_ids)
		if dominant.is_empty():
			continue

		# The dominant upgrade's visual takes priority
		# Other upgrades add to emission/particle count

	# Blend emission colors for additive glow effect
	_apply_additive_glow()

	all_transformations_updated.emit()


func _apply_additive_glow() -> void:
	"""Apply additive glow from all active upgrades"""
	if active_transformations.size() < 2:
		return

	# Calculate blended emission
	var total_emission: Color = Color.BLACK
	var total_strength: float = 0.0

	for upgrade_id in active_transformations:
		var config = UpgradeVisualConfig.get_visual_config(upgrade_id)
		var level = active_transformations[upgrade_id]["level"]
		var strength = UpgradeVisualConfig.get_scaled_emission(upgrade_id, level)

		total_emission += config.get("emission_color", Color.WHITE) * strength * 0.3
		total_strength += strength * 0.2

	# Clamp total emission
	total_emission.r = clampf(total_emission.r, 0.0, 1.0)
	total_emission.g = clampf(total_emission.g, 0.0, 1.0)
	total_emission.b = clampf(total_emission.b, 0.0, 1.0)


# === UTILITY ===

func get_active_transformation_count() -> int:
	"""Get number of active transformations"""
	return active_transformations.size()


func has_transformation(upgrade_id: String) -> bool:
	"""Check if a transformation is active"""
	return upgrade_id in active_transformations


func get_dominant_visual_color() -> Color:
	"""Get the dominant visual color for UI/effects"""
	if active_transformations.is_empty():
		return Color.WHITE

	# Find highest level upgrade
	var highest_level = 0
	var dominant_id = ""

	for upgrade_id in active_transformations:
		var level = active_transformations[upgrade_id]["level"]
		if level > highest_level:
			highest_level = level
			dominant_id = upgrade_id

	if dominant_id.is_empty():
		return Color.WHITE

	var config = UpgradeVisualConfig.get_visual_config(dominant_id)
	return config.get("primary_color", Color.WHITE)
