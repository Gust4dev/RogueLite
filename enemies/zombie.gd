extends BaseEnemy

# Zombie - Inimigo melee básico
# Segue o player e ataca em corpo a corpo

class_name Zombie

## Customização Visual (ajuste no Inspector)
@export var mesh_scale: float = 1.0
@export var mesh_y_offset: float = 0.0
@export var mesh_rotation_y: float = 180.0  ## Rotação em graus (180 = virar de frente)

## Ragdoll Death Config
@export_group("Death Effects")
@export var ragdoll_enabled: bool = true
@export var ragdoll_force: float = 5.0
@export var ragdoll_torque: float = 10.0
@export var death_particles_enabled: bool = true

# Referência ao player para calcular direção do knockback
var last_damage_direction: Vector3 = Vector3.ZERO

func _ready() -> void:
	# Stats específicas do zombie
	max_health = 50.0
	speed = 3.0
	damage = 10.0
	attack_range = 2.0
	attack_cooldown = 1.5

	# Chama o _ready() do pai
	super._ready()

	# Aplica customização visual ao mesh
	_apply_visual_customization()


func _apply_visual_customization() -> void:
	"""Aplica escala, offset Y e rotação ao mesh"""
	if mesh:
		mesh.scale = Vector3(mesh_scale, mesh_scale, mesh_scale)
		mesh.position.y = mesh_y_offset
		mesh.rotation_degrees.y = mesh_rotation_y


func take_damage(amount: float) -> void:
	"""Override para guardar direção do dano"""
	# Calcula direção do dano (do player para este inimigo)
	if target:
		last_damage_direction = (global_position - target.global_position).normalized()
	else:
		last_damage_direction = Vector3(randf_range(-1, 1), 0.5, randf_range(-1, 1)).normalized()

	super.take_damage(amount)


func die() -> void:
	"""Override com efeito de ragdoll"""
	if not _is_alive:
		return

	_is_alive = false
	current_health = 0.0

	# Dropa XP orbs
	_drop_xp()

	died.emit()

	# Desabilita física e colisão
	set_physics_process(false)
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)

	# Efeito de morte
	if ragdoll_enabled:
		await _ragdoll_death()
	else:
		await _standard_death()

	# Partículas de morte
	if death_particles_enabled:
		_spawn_death_particles()

	queue_free()


func _ragdoll_death() -> void:
	"""Efeito de ragdoll na morte"""
	if not mesh:
		return

	# Calcula força do ragdoll baseada na direção do dano
	var knockback_dir = last_damage_direction
	if knockback_dir.length() < 0.1:
		knockback_dir = Vector3(randf_range(-1, 1), 0.5, randf_range(-1, 1)).normalized()

	# Adiciona componente vertical
	knockback_dir.y = 0.5

	var tween = create_tween()
	tween.set_parallel(true)

	# Movimento de knockback
	var target_pos = global_position + knockback_dir * ragdoll_force
	tween.tween_property(self, "global_position", target_pos, 0.3).set_ease(Tween.EASE_OUT)

	# Rotação aleatória (simula ragdoll)
	var random_rotation = Vector3(
		randf_range(-PI, PI) * ragdoll_torque,
		randf_range(-PI, PI) * ragdoll_torque,
		randf_range(-PI, PI) * ragdoll_torque
	)
	tween.tween_property(mesh, "rotation", mesh.rotation + random_rotation, 0.4)

	# Queda
	tween.tween_property(self, "global_position:y", 0, 0.5).set_delay(0.2).set_ease(Tween.EASE_IN)

	# Fade out
	if mesh:
		_set_all_materials_transparent(mesh)
		tween.tween_callback(_start_fade.bind(0.3)).set_delay(0.3)

	await tween.finished
	await get_tree().create_timer(0.2).timeout


func _start_fade(duration: float) -> void:
	"""Inicia o fade out dos materiais"""
	if mesh:
		var fade_tween = create_tween()
		_fade_all_materials(mesh, fade_tween, duration)


func _standard_death() -> void:
	"""Morte padrão sem ragdoll"""
	var tween = create_tween()
	tween.set_parallel(true)

	# Afunda no chão
	tween.tween_property(self, "position:y", position.y - 2.0, 0.5).set_ease(Tween.EASE_IN)

	# Fade
	if mesh:
		_set_all_materials_transparent(mesh)
		_fade_all_materials(mesh, tween, 0.5)

	await tween.finished


func _spawn_death_particles() -> void:
	"""Spawna partículas de morte"""
	# Cria efeito de partículas simples
	var particles = GPUParticles3D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 10
	particles.lifetime = 0.5
	particles.explosiveness = 1.0

	var material = ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 0.5
	material.direction = Vector3(0, 1, 0)
	material.spread = 180.0
	material.initial_velocity_min = 2.0
	material.initial_velocity_max = 5.0
	material.gravity = Vector3(0, -10, 0)
	material.scale_min = 0.1
	material.scale_max = 0.3
	material.color = Color(0.8, 0.2, 0.2, 1.0)  # Vermelho para sangue
	particles.process_material = material

	# Mesh das partículas
	var quad = QuadMesh.new()
	quad.size = Vector2(0.2, 0.2)
	particles.draw_pass_1 = quad

	get_tree().current_scene.add_child(particles)
	particles.global_position = global_position + Vector3(0, 1, 0)

	# Auto-destruir após terminar
	get_tree().create_timer(1.0).timeout.connect(particles.queue_free)
