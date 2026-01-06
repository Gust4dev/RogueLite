extends Node

# Weapon Animation Modifier - Modifies weapon animations based on active upgrades
# Adds subtle visual changes to idle, reload, and firing animations

class_name WeaponAnimationModifier

# References
var weapon: Node3D = null
var animation_player: AnimationPlayer = null
var transformation_manager: WeaponTransformationManager = null

# Animation state
var base_idle_speed: float = 1.0
var current_idle_multiplier: float = 1.0

# Idle sway modifiers based on upgrades
var idle_sway_intensity: float = 1.0
var idle_pulse_rate: float = 0.0

# Reload animation modifiers
var reload_speed_multiplier: float = 1.0

# Tween references for smooth transitions
var active_tweens: Array[Tween] = []


func setup(parent_weapon: Node3D, trans_manager: WeaponTransformationManager) -> void:
	"""Initialize with weapon and transformation manager"""
	weapon = parent_weapon
	transformation_manager = trans_manager

	# Find animation player
	if weapon:
		animation_player = weapon.get_node_or_null("AnimationPlayer")
		if not animation_player:
			# Search in mesh children
			for child in weapon.get_children():
				if child is Node3D:
					animation_player = child.find_child("AnimationPlayer", true, false)
					if animation_player:
						break

	# Connect to transformation signals
	if transformation_manager:
		transformation_manager.transformation_applied.connect(_on_transformation_applied)
		transformation_manager.transformation_removed.connect(_on_transformation_removed)


func _on_transformation_applied(upgrade_id: String, level: int) -> void:
	"""React to new transformation being applied"""
	_update_animation_modifiers()
	_apply_upgrade_specific_animation(upgrade_id, level)


func _on_transformation_removed(upgrade_id: String) -> void:
	"""React to transformation being removed"""
	_update_animation_modifiers()


func _update_animation_modifiers() -> void:
	"""Update all animation modifiers based on active upgrades"""
	if not transformation_manager:
		return

	# Reset to defaults
	idle_sway_intensity = 1.0
	idle_pulse_rate = 0.0
	reload_speed_multiplier = 1.0

	# Calculate modifiers from all active transformations
	for upgrade_id in transformation_manager.active_transformations:
		var data = transformation_manager.active_transformations[upgrade_id]
		var level = data["level"]

		match upgrade_id:
			"chain_lightning":
				# Subtle electric jitter
				idle_sway_intensity += 0.1 * level
				idle_pulse_rate += 2.0 * level

			"explosive_rounds":
				# Slight warmth pulse
				idle_pulse_rate += 1.0 * level

			"freeze_bullets":
				# Slower, more deliberate movement
				idle_sway_intensity *= 0.9

			"fast_reload":
				# Speed up reload animation
				reload_speed_multiplier += 0.2 * level

			"lifesteal":
				# Organic pulsing
				idle_pulse_rate += 1.5 * level
				idle_sway_intensity += 0.05 * level

			"burst_fire":
				# Slightly faster idle
				idle_sway_intensity += 0.15 * level


func _apply_upgrade_specific_animation(upgrade_id: String, level: int) -> void:
	"""Apply special animation effect for specific upgrade"""
	match upgrade_id:
		"chain_lightning":
			_start_electric_jitter(level)
		"lifesteal":
			_start_organic_pulse(level)
		"fast_reload":
			_apply_reload_speed()


func _start_electric_jitter(level: int) -> void:
	"""Start subtle electric jitter animation"""
	if not weapon:
		return

	# Create a subtle position offset that jitters
	var jitter_tween = create_tween()
	jitter_tween.set_loops()

	var jitter_amount = 0.001 * level
	var jitter_speed = 0.05

	jitter_tween.tween_callback(_apply_jitter.bind(jitter_amount))
	jitter_tween.tween_interval(jitter_speed)

	active_tweens.append(jitter_tween)


func _apply_jitter(amount: float) -> void:
	"""Apply random jitter offset"""
	if not weapon:
		return

	# Get parts manager if available
	if transformation_manager and transformation_manager.parts_manager:
		var barrel = transformation_manager.parts_manager.barrel_node
		if barrel:
			var jitter = Vector3(
				randf_range(-amount, amount),
				randf_range(-amount, amount),
				randf_range(-amount, amount)
			)
			# Apply micro-jitter to barrel only
			barrel.position += jitter


func _start_organic_pulse(level: int) -> void:
	"""Start organic pulsing animation for lifesteal"""
	if not weapon or not transformation_manager:
		return

	var parts = transformation_manager.parts_manager
	if not parts:
		return

	# Pulse the grip slightly
	var pulse_tween = create_tween()
	pulse_tween.set_loops()

	var pulse_scale = 1.0 + 0.02 * level
	var pulse_duration = 0.8 / (1.0 + level * 0.2)  # Faster at higher levels

	pulse_tween.tween_callback(_pulse_grip.bind(Vector3(pulse_scale, pulse_scale, 1.0)))
	pulse_tween.tween_interval(pulse_duration)
	pulse_tween.tween_callback(_pulse_grip.bind(Vector3.ONE))
	pulse_tween.tween_interval(pulse_duration)

	active_tweens.append(pulse_tween)


func _pulse_grip(target_scale: Vector3) -> void:
	"""Pulse the grip scale"""
	if not transformation_manager or not transformation_manager.parts_manager:
		return

	var grip_mesh = transformation_manager.parts_manager.get_part_mesh("grip")
	if grip_mesh:
		var tween = create_tween()
		tween.tween_property(grip_mesh, "scale", target_scale, 0.3)


func _apply_reload_speed() -> void:
	"""Apply reload speed multiplier to animation"""
	# This is handled by the weapon's reload function
	pass


func get_reload_speed_multiplier() -> float:
	"""Get current reload speed multiplier"""
	return reload_speed_multiplier


func get_idle_sway_intensity() -> float:
	"""Get current idle sway intensity"""
	return idle_sway_intensity


func get_idle_pulse_rate() -> float:
	"""Get current idle pulse rate"""
	return idle_pulse_rate


func cleanup() -> void:
	"""Clean up all active tweens and animations"""
	for tween in active_tweens:
		if is_instance_valid(tween) and tween.is_running():
			tween.kill()

	active_tweens.clear()

	# Disconnect signals
	if transformation_manager:
		if transformation_manager.transformation_applied.is_connected(_on_transformation_applied):
			transformation_manager.transformation_applied.disconnect(_on_transformation_applied)
		if transformation_manager.transformation_removed.is_connected(_on_transformation_removed):
			transformation_manager.transformation_removed.disconnect(_on_transformation_removed)
