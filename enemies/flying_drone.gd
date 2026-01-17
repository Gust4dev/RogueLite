extends BaseEnemy

# Flying Drone - Inimigo aéreo que atira de cima
# Voa acima do chão, ranged attack, hitbox pequeno

class_name FlyingDrone

# Configuração do Drone
@export_group("Drone Config")
@export var fly_height: float = 4.0
@export var hover_amplitude: float = 0.5  # Amplitude do movimento de hover
@export var hover_speed: float = 2.0
@export var projectile_speed: float = 12.0
@export var shoot_cooldown: float = 2.5
@export var shoot_range: float = 18.0
@export var strafe_speed: float = 3.0  # Velocidade de movimento lateral

# Customização Visual
@export_group("Visual")
@export var mesh_scale: float = 0.5  # Menor que outros inimigos
@export var mesh_y_offset: float = 0.0
@export var mesh_rotation_y: float = 180.0

# Estado interno
var hover_timer: float = 0.0
var base_height: float = 0.0
var is_shooting: bool = false
var projectile_scene: PackedScene = null
var strafe_direction: float = 1.0  # 1 ou -1 para strafe lateral
var strafe_timer: float = 0.0

func _ready() -> void:
	# Stats específicas do Drone
	max_health = 40.0
	speed = 4.0
	damage = 8.0  # Dano por tiro
	attack_range = shoot_range
	attack_cooldown = shoot_cooldown
	xp_reward = 30

	# Chama o _ready() do pai
	super._ready()

	# Salva altura base
	base_height = global_position.y + fly_height

	# Aplica customização visual
	_apply_visual_customization()

	# Carrega projétil
	if ResourceLoader.exists("res://enemies/projectiles/enemy_projectile.tscn"):
		projectile_scene = load("res://enemies/projectiles/enemy_projectile.tscn")


func _apply_visual_customization() -> void:
	"""Aplica escala, offset Y e rotação ao mesh"""
	if mesh:
		mesh.scale = Vector3(mesh_scale, mesh_scale, mesh_scale) * 0.01
		mesh.position.y = mesh_y_offset
		mesh.rotation_degrees.y = mesh_rotation_y

	# Aplica visual de drone
	_setup_drone_visual()


func _setup_drone_visual() -> void:
	"""Configura visual específico do drone"""
	var mesh_instance = _find_mesh_instance()
	if mesh_instance:
		var material = StandardMaterial3D.new()
		material.albedo_color = Color(0.2, 0.4, 0.6)  # Azul metálico
		material.metallic = 0.9
		material.roughness = 0.2
		material.emission_enabled = true
		material.emission = Color(0.0, 0.5, 1.0)
		material.emission_energy_multiplier = 0.5
		mesh_instance.set_surface_override_material(0, material)


func _physics_process(delta: float) -> void:
	if not _is_alive:
		return

	# Atualiza hover
	_update_hover(delta)

	# Atualiza strafe timer
	strafe_timer += delta
	if strafe_timer > 3.0:
		strafe_direction *= -1
		strafe_timer = 0.0

	# Atualiza timer de ataque
	if attack_timer > 0:
		attack_timer -= delta
		if attack_timer <= 0:
			can_attack = true

	if not target:
		# Sem alvo, apenas hover
		_apply_hover_movement()
		return

	var distance_to_target = global_position.distance_to(target.global_position)

	# Sempre olha para o player
	var look_target = Vector3(target.global_position.x, global_position.y, target.global_position.z)
	if global_position.distance_to(look_target) > 0.1:
		look_at(look_target)

	# Se está em range, atira e faz strafe
	if distance_to_target <= shoot_range:
		if can_attack and not is_shooting:
			_start_shooting()

		# Movimento de strafe lateral
		_strafe_movement()
	else:
		# Aproxima mantendo altura
		_fly_towards_target()

	_apply_hover_movement()


func _update_hover(delta: float) -> void:
	"""Atualiza timer do movimento de hover"""
	hover_timer += delta * hover_speed


func _apply_hover_movement() -> void:
	"""Aplica movimento suave de hover"""
	# Calcula offset vertical do hover
	var hover_offset = sin(hover_timer * PI) * hover_amplitude

	# Mantém altura do voo com hover
	var target_height = base_height + hover_offset
	global_position.y = lerp(global_position.y, target_height, 0.1)


func _fly_towards_target() -> void:
	"""Voa em direção ao alvo mantendo altura"""
	if not target:
		return

	var direction = (target.global_position - global_position)
	direction.y = 0  # Ignora componente vertical
	direction = direction.normalized()

	velocity.x = direction.x * speed
	velocity.z = direction.z * speed

	global_position += velocity * get_physics_process_delta_time()


func _strafe_movement() -> void:
	"""Movimento lateral enquanto atira"""
	if not target:
		return

	# Calcula direção perpendicular ao player
	var to_player = (target.global_position - global_position).normalized()
	to_player.y = 0

	# Direção de strafe (perpendicular)
	var strafe_dir = Vector3(-to_player.z, 0, to_player.x) * strafe_direction

	velocity.x = strafe_dir.x * strafe_speed
	velocity.z = strafe_dir.z * strafe_speed

	global_position += velocity * get_physics_process_delta_time()


func _start_shooting() -> void:
	"""Inicia sequência de tiro"""
	is_shooting = true
	can_attack = false
	attack_timer = attack_cooldown

	# Telegraph visual
	_show_telegraph()

	await get_tree().create_timer(0.3).timeout

	if _is_alive and target:
		_fire_projectile()

	is_shooting = false


func _show_telegraph() -> void:
	"""Aviso visual antes do tiro"""
	var mesh_instance = _find_mesh_instance()
	if mesh_instance:
		var mat = mesh_instance.get_surface_override_material(0)
		if mat is StandardMaterial3D:
			var original_emission = mat.emission_energy_multiplier
			mat.emission_energy_multiplier = 3.0

			await get_tree().create_timer(0.3).timeout
			if is_instance_valid(mat):
				mat.emission_energy_multiplier = original_emission


func _fire_projectile() -> void:
	"""Dispara projétil"""
	if not projectile_scene:
		# Fallback para dano direto
		if target and target.has_method("take_damage"):
			var actual_damage = damage
			if GameManager:
				actual_damage = damage * GameManager.get_damage_multiplier()
			target.take_damage(actual_damage)
		return

	var projectile = projectile_scene.instantiate()
	get_tree().current_scene.add_child(projectile)

	projectile.global_position = global_position + Vector3(0, -0.5, 0)

	# Direção para o player com pequena predição
	var target_pos = target.global_position
	if target is CharacterBody3D:
		target_pos += target.velocity * 0.2  # Predição básica

	var direction = (target_pos - projectile.global_position).normalized()

	if projectile.has_method("setup"):
		var actual_damage = damage
		if GameManager:
			actual_damage = damage * GameManager.get_damage_multiplier()
		projectile.setup(direction, projectile_speed, actual_damage)
		projectile.projectile_color = Color(0.0, 0.5, 1.0)  # Projétil azul

	attack_performed.emit()


func die() -> void:
	"""Override: Drone cai ao morrer"""
	if not _is_alive:
		return

	_is_alive = false
	current_health = 0.0

	# Dropa XP/coins
	_drop_xp()

	died.emit()

	# Desabilita física
	set_physics_process(false)

	# Animação de queda
	await _fall_animation()

	queue_free()


func _fall_animation() -> void:
	"""Animação do drone caindo"""
	var tween = create_tween()
	tween.set_parallel(true)

	# Cai girando
	tween.tween_property(self, "global_position:y", 0, 0.5).set_ease(Tween.EASE_IN)
	if mesh:
		tween.tween_property(mesh, "rotation:x", mesh.rotation.x + PI * 2, 0.5)
		tween.tween_property(mesh, "rotation:z", mesh.rotation.z + PI, 0.5)

	await tween.finished
