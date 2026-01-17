extends BaseEnemy

# Shooter - Inimigo ranged que atira projéteis
# Fica parado e atira de longe com telegraph visual

class_name Shooter

# Configuração do Shooter
@export_group("Shooter Config")
@export var projectile_speed: float = 15.0
@export var telegraph_time: float = 0.5  # Tempo de aviso antes do tiro
@export var shoot_range: float = 15.0  # Range máximo de tiro
@export var min_shoot_range: float = 5.0  # Range mínimo (recua se player muito perto)

# Customização Visual
@export_group("Visual")
@export var mesh_scale: float = 1.0
@export var mesh_y_offset: float = 0.0
@export var mesh_rotation_y: float = 180.0

# Estado interno
var is_shooting: bool = false
var telegraph_active: bool = false
var projectile_scene: PackedScene = null

# Referência ao muzzle point (ponto de onde sai o projétil)
var muzzle_point: Node3D = null

func _ready() -> void:
	# Stats específicas do Shooter
	max_health = 30.0
	speed = 2.0  # Mais lento que zombie
	damage = 5.0  # Dano por projétil
	attack_range = shoot_range
	attack_cooldown = 2.0  # Atira a cada 2 segundos
	xp_reward = 15

	# Chama o _ready() do pai
	super._ready()

	# Aplica customização visual
	_apply_visual_customization()

	# Carrega cena do projétil
	if ResourceLoader.exists("res://enemies/projectiles/enemy_projectile.tscn"):
		projectile_scene = load("res://enemies/projectiles/enemy_projectile.tscn")

	# Cria muzzle point se não existir
	_setup_muzzle_point()


func _apply_visual_customization() -> void:
	"""Aplica escala, offset Y e rotação ao mesh"""
	if mesh:
		mesh.scale = Vector3(mesh_scale, mesh_scale, mesh_scale)
		mesh.position.y = mesh_y_offset
		mesh.rotation_degrees.y = mesh_rotation_y


func _setup_muzzle_point() -> void:
	"""Configura o ponto de origem dos projéteis"""
	muzzle_point = get_node_or_null("MuzzlePoint")
	if not muzzle_point:
		muzzle_point = Node3D.new()
		muzzle_point.name = "MuzzlePoint"
		add_child(muzzle_point)
		muzzle_point.position = Vector3(0, 1.0, 1.0)  # Frente do inimigo


func _physics_process(delta: float) -> void:
	if not _is_alive:
		return

	# Aplica gravidade
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	# Atualiza timer de ataque
	if attack_timer > 0:
		attack_timer -= delta
		if attack_timer <= 0:
			can_attack = true

	# Atualiza cache de inimigos próximos
	nearby_update_timer -= delta
	if nearby_update_timer <= 0:
		_update_nearby_enemies()
		nearby_update_timer = NEARBY_UPDATE_INTERVAL

	if not target:
		move_and_slide()
		return

	var distance_to_target = global_position.distance_to(target.global_position)

	# Sempre olha para o player
	var look_target = Vector3(target.global_position.x, global_position.y, target.global_position.z)
	if global_position.distance_to(look_target) > 0.1:
		look_at(look_target)

	# Se player está muito perto, recua
	if distance_to_target < min_shoot_range:
		_retreat_from_target()
	# Se está em range de tiro, atira
	elif distance_to_target <= shoot_range:
		velocity.x = 0
		velocity.z = 0

		if can_attack and not is_shooting:
			_start_shooting()
	else:
		# Aproxima até estar em range
		_navigate_to_target()

	# Aplica força de separação
	_apply_separation_force()

	move_and_slide()


func _retreat_from_target() -> void:
	"""Recua do player quando muito perto"""
	if not target:
		return

	var direction = (global_position - target.global_position).normalized()
	direction.y = 0

	velocity.x = direction.x * speed * 1.5  # Recua mais rápido
	velocity.z = direction.z * speed * 1.5


func _start_shooting() -> void:
	"""Inicia sequência de tiro com telegraph"""
	is_shooting = true
	telegraph_active = true
	can_attack = false
	attack_timer = attack_cooldown

	# Telegraph visual - flash de aviso
	_show_telegraph()

	await get_tree().create_timer(telegraph_time).timeout

	if _is_alive and target:
		_fire_projectile()

	telegraph_active = false
	is_shooting = false


func _show_telegraph() -> void:
	"""Mostra aviso visual antes do tiro"""
	if not mesh:
		return

	# Flash amarelo de aviso
	var mesh_instance = _find_mesh_instance()
	if mesh_instance:
		var original_color = Color.WHITE
		var mat = mesh_instance.get_surface_override_material(0)
		if mat is StandardMaterial3D:
			original_color = mat.albedo_color

		# Cria material de aviso
		var warning_mat = StandardMaterial3D.new()
		warning_mat.albedo_color = Color.YELLOW
		warning_mat.emission_enabled = true
		warning_mat.emission = Color.YELLOW
		warning_mat.emission_energy_multiplier = 2.0
		mesh_instance.set_surface_override_material(0, warning_mat)

		# Volta ao normal após telegraph
		await get_tree().create_timer(telegraph_time).timeout
		if is_instance_valid(mesh_instance):
			var normal_mat = StandardMaterial3D.new()
			normal_mat.albedo_color = original_color
			mesh_instance.set_surface_override_material(0, normal_mat)


func _fire_projectile() -> void:
	"""Dispara o projétil"""
	if not projectile_scene:
		# Fallback: dano direto se não tem projétil
		if target and target.has_method("take_damage"):
			var actual_damage = damage
			if GameManager:
				actual_damage = damage * GameManager.get_damage_multiplier()
			target.take_damage(actual_damage)
		return

	var projectile = projectile_scene.instantiate()
	get_tree().current_scene.add_child(projectile)

	# Posiciona no muzzle point
	var spawn_pos = muzzle_point.global_position if muzzle_point else global_position + Vector3(0, 1, 0)
	projectile.global_position = spawn_pos

	# Direção para o player
	var direction = (target.global_position - spawn_pos).normalized()

	# Configura o projétil
	if projectile.has_method("setup"):
		var actual_damage = damage
		if GameManager:
			actual_damage = damage * GameManager.get_damage_multiplier()
		projectile.setup(direction, projectile_speed, actual_damage)

	attack_performed.emit()


func attack() -> void:
	"""Override do ataque base - Shooter usa projéteis"""
	# Shooter não usa ataque melee, usa _start_shooting()
	pass
