extends Node3D

# Weapon Recoil System - Sistema avançado de recoil com kickback
# Baseado no padrão de separar posição e rotação com aleatoriedade controlada

class_name WeaponRecoil

# Referência à arma
var weapon: Node3D = null

# === CONFIGURAÇÃO DO KICKBACK ===
# Posição alvo do kickback (quanto a arma se move para trás)
@export var kickback_position: Vector3 = Vector3(0.0, 0.02, 0.08)
# Rotação alvo do kickback (quanto a arma rotaciona)
@export var kickback_rotation: Vector3 = Vector3(-3.0, 1.5, 2.0)  # graus

# Aleatoriedade na posição (min/max range)
@export var position_randomness: Vector3 = Vector3(0.005, 0.005, 0.01)
# Aleatoriedade na rotação (min/max range em graus)
@export var rotation_randomness: Vector3 = Vector3(0.5, 1.0, 0.5)

# === VELOCIDADES ===
@export var kickback_speed: float = 15.0  # Velocidade do kickback (indo)
@export var return_speed: float = 8.0  # Velocidade de retorno (parado)
@export var shooting_return_speed: float = 4.0  # Velocidade de retorno (atirando)

# === ESTADO INTERNO ===
var original_position: Vector3 = Vector3.ZERO
var original_rotation: Vector3 = Vector3.ZERO

var target_position: Vector3 = Vector3.ZERO
var target_rotation: Vector3 = Vector3.ZERO

var current_position: Vector3 = Vector3.ZERO
var current_rotation: Vector3 = Vector3.ZERO

# Controle de kickback
var kickback_progress: float = 0.0  # 0 = posição original, 1 = posição de kickback
var is_returning: bool = true
var is_shooting: bool = false

# Suavização adicional
var velocity_position: Vector3 = Vector3.ZERO
var velocity_rotation: Vector3 = Vector3.ZERO


func _ready() -> void:
	# Encontra a arma parent
	weapon = get_parent()
	if weapon:
		original_position = weapon.position
		original_rotation = weapon.rotation


func _process(delta: float) -> void:
	if not weapon:
		return

	_update_kickback(delta)
	_apply_to_weapon()


func _update_kickback(delta: float) -> void:
	"""Atualiza o estado do kickback"""

	# Se não tem target, volta para posição original
	if target_position == Vector3.ZERO and target_rotation == Vector3.ZERO:
		is_returning = true

	# Determina a velocidade baseado no estado
	var speed: float
	if not is_returning:
		# Kickback está acontecendo
		speed = kickback_speed
	elif is_shooting:
		# Retornando enquanto atira (mais lento)
		speed = shooting_return_speed
	else:
		# Retornando em repouso
		speed = return_speed

	# Atualiza progresso
	if is_returning:
		kickback_progress = move_toward(kickback_progress, 0.0, speed * delta)
	else:
		kickback_progress = move_toward(kickback_progress, 1.0, speed * delta)
		# Quando atinge o máximo, começa a retornar
		if kickback_progress >= 1.0:
			is_returning = true

	# Interpola posição e rotação usando smoothstep para transição mais natural
	var t = _smoothstep(kickback_progress)

	current_position = original_position.lerp(original_position + target_position, t)
	current_rotation = original_rotation.lerp(original_rotation + target_rotation, t)

	# Reset target quando volta à posição original
	if kickback_progress <= 0.0 and is_returning:
		target_position = Vector3.ZERO
		target_rotation = Vector3.ZERO
		is_shooting = false


func _apply_to_weapon() -> void:
	"""Aplica o kickback à arma"""
	if weapon:
		weapon.position = current_position
		weapon.rotation = current_rotation


func _smoothstep(t: float) -> float:
	"""Função smoothstep para transições suaves"""
	t = clamp(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func apply_recoil() -> void:
	"""Aplica um pulso de recoil - chamado quando atira"""
	is_shooting = true
	is_returning = false

	# Calcula novo target com aleatoriedade
	target_position = kickback_position + Vector3(
		randf_range(-position_randomness.x, position_randomness.x),
		randf_range(-position_randomness.y, position_randomness.y),
		randf_range(0, position_randomness.z)  # Z sempre positivo (para trás)
	)

	target_rotation = Vector3(
		deg_to_rad(kickback_rotation.x + randf_range(-rotation_randomness.x, rotation_randomness.x)),
		deg_to_rad(kickback_rotation.y * randf_range(-1.0, 1.0) + randf_range(-rotation_randomness.y, rotation_randomness.y)),
		deg_to_rad(kickback_rotation.z * randf_range(-1.0, 1.0) + randf_range(-rotation_randomness.z, rotation_randomness.z))
	)

	# Reset progress para iniciar novo kickback
	# Se já estava em kickback, mantém um pouco do progresso para acumular
	kickback_progress = max(kickback_progress * 0.3, 0.0)


func set_shooting_state(shooting: bool) -> void:
	"""Define se o jogador está atirando continuamente"""
	is_shooting = shooting


func reset() -> void:
	"""Reseta o recoil para posição original"""
	kickback_progress = 0.0
	is_returning = true
	target_position = Vector3.ZERO
	target_rotation = Vector3.ZERO
	current_position = original_position
	current_rotation = original_rotation

	if weapon:
		weapon.position = original_position
		weapon.rotation = original_rotation


# === CONFIGURAÇÃO DINÂMICA ===

func set_recoil_config(pos: Vector3, rot: Vector3, pos_rand: Vector3, rot_rand: Vector3) -> void:
	"""Configura os parâmetros de recoil dinamicamente"""
	kickback_position = pos
	kickback_rotation = rot
	position_randomness = pos_rand
	rotation_randomness = rot_rand


func set_speeds(kickback: float, ret: float, shooting_ret: float) -> void:
	"""Configura as velocidades de recoil"""
	kickback_speed = kickback
	return_speed = ret
	shooting_return_speed = shooting_ret
