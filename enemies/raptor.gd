extends BaseEnemy

# Raptor - Inimigo melee rápido com dash attack
# Muito rápido, faz lunge attacks devastadores

class_name Raptor

# Configuração do Raptor
@export_group("Raptor Config")
@export var dash_speed: float = 20.0
@export var dash_duration: float = 0.3
@export var dash_cooldown: float = 3.0
@export var dash_range: float = 10.0  # Distância para iniciar dash
@export var dash_min_range: float = 3.0  # Não faz dash se muito perto

# Customização Visual
@export_group("Visual")
@export var mesh_scale: float = 0.8  # Menor que zombie
@export var mesh_y_offset: float = 0.0
@export var mesh_rotation_y: float = 180.0

# Estado interno
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_direction: Vector3 = Vector3.ZERO
var dash_elapsed: float = 0.0

func _ready() -> void:
	# Stats específicas do Raptor
	max_health = 20.0  # Frágil
	speed = 6.0  # Muito rápido
	damage = 15.0  # Alto dano
	attack_range = 2.0
	attack_cooldown = 1.0  # Ataca rápido
	xp_reward = 20

	# Chama o _ready() do pai
	super._ready()

	# Aplica customização visual
	_apply_visual_customization()


func _apply_visual_customization() -> void:
	"""Aplica escala, offset Y e rotação ao mesh"""
	if mesh:
		mesh.scale = Vector3(mesh_scale, mesh_scale, mesh_scale)
		mesh.position.y = mesh_y_offset
		mesh.rotation_degrees.y = mesh_rotation_y


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

	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta

	# Atualiza cache de inimigos próximos
	nearby_update_timer -= delta
	if nearby_update_timer <= 0:
		_update_nearby_enemies()
		nearby_update_timer = NEARBY_UPDATE_INTERVAL

	# Se está fazendo dash
	if is_dashing:
		_process_dash(delta)
		move_and_slide()
		return

	if not target:
		move_and_slide()
		return

	var distance_to_target = global_position.distance_to(target.global_position)

	# Verifica se pode iniciar dash
	if dash_cooldown_timer <= 0 and not is_dashing:
		if distance_to_target >= dash_min_range and distance_to_target <= dash_range:
			_start_dash()
			return

	# Comportamento normal - ataque melee rápido
	if distance_to_target <= attack_range:
		velocity.x = 0
		velocity.z = 0

		var look_target = Vector3(target.global_position.x, global_position.y, target.global_position.z)
		if global_position.distance_to(look_target) > 0.1:
			look_at(look_target)

		if can_attack:
			attack()
	else:
		# Persegue rapidamente
		_navigate_to_target()

	_apply_separation_force()
	move_and_slide()


func _start_dash() -> void:
	"""Inicia o dash attack"""
	if not target:
		return

	is_dashing = true
	dash_cooldown_timer = dash_cooldown
	dash_elapsed = 0.0

	# Calcula direção do dash
	dash_direction = (target.global_position - global_position).normalized()
	dash_direction.y = 0

	# Telegraph visual - breve preparação
	_dash_telegraph()


func _dash_telegraph() -> void:
	"""Animação de preparação do dash"""
	if mesh:
		# Agacha antes de pular
		var tween = create_tween()
		tween.tween_property(mesh, "scale:y", mesh_scale * 0.7, 0.1)
		tween.tween_property(mesh, "scale:y", mesh_scale, 0.05)


func _process_dash(delta: float) -> void:
	"""Processa o movimento do dash"""
	dash_elapsed += delta

	# Move rapidamente na direção do dash
	velocity.x = dash_direction.x * dash_speed
	velocity.z = dash_direction.z * dash_speed

	# Olha na direção do dash
	var look_target = global_position + dash_direction
	look_target.y = global_position.y
	if global_position.distance_to(look_target) > 0.1:
		look_at(look_target)

	# Verifica colisão com player durante dash
	if target:
		var distance = global_position.distance_to(target.global_position)
		if distance <= attack_range * 1.5:
			_dash_hit()
			_end_dash()
			return

	# Verifica se bateu na parede
	if is_on_wall():
		_end_dash()
		return

	# Verifica se dash terminou
	if dash_elapsed >= dash_duration:
		_end_dash()


func _dash_hit() -> void:
	"""Aplica dano do dash"""
	if target and target.has_method("take_damage"):
		var actual_damage = damage * 1.5  # Dash causa 50% mais dano
		if GameManager:
			actual_damage = damage * 1.5 * GameManager.get_damage_multiplier()
		target.take_damage(actual_damage)

	attack_performed.emit()


func _end_dash() -> void:
	"""Finaliza o dash"""
	is_dashing = false
	velocity.x = 0
	velocity.z = 0

	# Pequeno stun após dash
	set_physics_process(false)
	await get_tree().create_timer(0.2).timeout
	if _is_alive:
		set_physics_process(true)
