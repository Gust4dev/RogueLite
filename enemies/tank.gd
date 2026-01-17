extends BaseEnemy

# Tank - Inimigo lento mas muito resistente
# Alto HP, armadura que reduz dano, knockback resistance

class_name Tank

# Configuração do Tank
@export_group("Tank Config")
@export var armor_reduction: float = 0.5  # 50% de redução de dano
@export var knockback_resistance: float = 0.8  # 80% resistência a knockback
@export var slam_attack_enabled: bool = true
@export var slam_radius: float = 3.0
@export var slam_cooldown: float = 5.0

# Customização Visual
@export_group("Visual")
@export var mesh_scale: float = 1.5  # Maior que outros inimigos
@export var mesh_y_offset: float = 0.0
@export var mesh_rotation_y: float = 180.0

# Estado interno
var slam_cooldown_timer: float = 0.0
var is_slamming: bool = false

func _ready() -> void:
	# Stats específicas do Tank
	max_health = 200.0  # Muito HP
	speed = 1.5  # Muito lento
	damage = 25.0  # Alto dano
	attack_range = 2.5
	attack_cooldown = 2.0
	xp_reward = 50  # Mais XP por ser difícil

	# Chama o _ready() do pai
	super._ready()

	# Aplica customização visual
	_apply_visual_customization()


func _apply_visual_customization() -> void:
	"""Aplica escala, offset Y e rotação ao mesh"""
	if mesh:
		mesh.scale = Vector3(mesh_scale, mesh_scale, mesh_scale) * 0.01  # Escala do modelo GLB
		mesh.position.y = mesh_y_offset
		mesh.rotation_degrees.y = mesh_rotation_y

		# Aplica cor mais escura para indicar armadura
		_apply_armored_visual()


func _apply_armored_visual() -> void:
	"""Aplica visual de armadura ao Tank"""
	var mesh_instance = _find_mesh_instance()
	if mesh_instance:
		var material = StandardMaterial3D.new()
		material.albedo_color = Color(0.3, 0.3, 0.35)  # Cinza escuro metálico
		material.metallic = 0.8
		material.roughness = 0.3
		mesh_instance.set_surface_override_material(0, material)


func _physics_process(delta: float) -> void:
	if not _is_alive:
		return

	# Aplica gravidade
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	# Atualiza timers
	if attack_timer > 0:
		attack_timer -= delta
		if attack_timer <= 0:
			can_attack = true

	if slam_cooldown_timer > 0:
		slam_cooldown_timer -= delta

	# Atualiza cache de inimigos próximos
	nearby_update_timer -= delta
	if nearby_update_timer <= 0:
		_update_nearby_enemies()
		nearby_update_timer = NEARBY_UPDATE_INTERVAL

	if is_slamming:
		move_and_slide()
		return

	if not target:
		move_and_slide()
		return

	var distance_to_target = global_position.distance_to(target.global_position)

	# Ataque normal ou slam
	if distance_to_target <= attack_range:
		velocity.x = 0
		velocity.z = 0

		var look_target = Vector3(target.global_position.x, global_position.y, target.global_position.z)
		if global_position.distance_to(look_target) > 0.1:
			look_at(look_target)

		if can_attack:
			# Decide entre ataque normal ou slam
			if slam_attack_enabled and slam_cooldown_timer <= 0:
				_slam_attack()
			else:
				attack()
	else:
		# Persegue lentamente
		_navigate_to_target()

	# Tank tem separação menor (é grande demais para se importar)
	_apply_separation_force()
	move_and_slide()


func take_damage(amount: float) -> void:
	"""Override para aplicar redução de armadura"""
	if not _is_alive:
		return

	# Aplica redução de armadura
	var reduced_damage = amount * (1.0 - armor_reduction)

	# Efeito visual de armadura bloqueando
	_armor_block_effect()

	# Chama take_damage do pai com dano reduzido
	super.take_damage(reduced_damage)


func _armor_block_effect() -> void:
	"""Efeito visual quando armadura bloqueia dano"""
	if mesh:
		var mesh_instance = _find_mesh_instance()
		if mesh_instance:
			var mat = mesh_instance.get_surface_override_material(0)
			if mat is StandardMaterial3D:
				var original_color = mat.albedo_color
				mat.albedo_color = Color(0.6, 0.6, 0.7)  # Flash mais claro

				await get_tree().create_timer(0.05).timeout
				if is_instance_valid(mat):
					mat.albedo_color = original_color


func _slam_attack() -> void:
	"""Ataque de slam em área"""
	is_slamming = true
	can_attack = false
	attack_timer = attack_cooldown
	slam_cooldown_timer = slam_cooldown

	# Animação de preparação
	if mesh:
		var tween = create_tween()
		tween.tween_property(mesh, "position:y", mesh.position.y + 0.5, 0.3)
		await tween.finished

	# Slam!
	if mesh:
		var tween = create_tween()
		tween.tween_property(mesh, "position:y", mesh_y_offset, 0.1)
		await tween.finished

	# Aplica dano em área
	_apply_slam_damage()

	# Efeito visual de onda de choque
	_slam_shockwave_effect()

	is_slamming = false
	attack_performed.emit()


func _apply_slam_damage() -> void:
	"""Aplica dano a todos os alvos na área do slam"""
	var slam_damage = damage * 1.5  # Slam causa 50% mais dano
	if GameManager:
		slam_damage *= GameManager.get_damage_multiplier()

	# Verifica player
	if target:
		var distance = global_position.distance_to(target.global_position)
		if distance <= slam_radius:
			if target.has_method("take_damage"):
				target.take_damage(slam_damage)


func _slam_shockwave_effect() -> void:
	"""Efeito visual de onda de choque do slam"""
	# Cria círculo de impacto temporário
	var impact = MeshInstance3D.new()
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = slam_radius
	cylinder.bottom_radius = slam_radius
	cylinder.height = 0.1
	impact.mesh = cylinder

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.5, 0.0, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	impact.set_surface_override_material(0, mat)

	get_tree().current_scene.add_child(impact)
	impact.global_position = global_position

	# Fade out
	var tween = create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.3)
	await tween.finished
	impact.queue_free()
