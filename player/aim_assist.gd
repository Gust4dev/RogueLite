extends Node

# Aim Assist System - Sistema de assistência de mira muito leve
# Magnetismo sutil e slowdown perto de inimigos

class_name AimAssist

# Referência ao player
var player: Node3D = null
var camera: Camera3D = null

# === CONFIGURAÇÃO ===
@export_group("Aim Assist")
@export var enabled: bool = true

# Raio de detecção (em pixels do centro da tela)
@export var detection_radius: float = 100.0

# Força do magnetismo (0 = nenhum, 1 = completo)
@export var magnetism_strength: float = 0.15  # BEM leve

# Slowdown quando perto de inimigo (1 = normal, 0.5 = metade da velocidade)
@export var slowdown_factor: float = 0.7

# Distância máxima para aim assist funcionar
@export var max_distance: float = 50.0

# Ângulo máximo de correção (em graus)
@export var max_correction_angle: float = 3.0

# === ESTADO ===
var current_target: Node3D = null
var target_screen_position: Vector2 = Vector2.ZERO
var is_near_target: bool = false
var correction_vector: Vector2 = Vector2.ZERO

# Cache
var screen_center: Vector2 = Vector2.ZERO
var viewport_size: Vector2 = Vector2.ZERO


func _ready() -> void:
	_update_viewport_info()


func setup(player_node: Node3D, camera_node: Camera3D) -> void:
	"""Configura as referências"""
	player = player_node
	camera = camera_node


func _process(_delta: float) -> void:
	if not enabled or not camera:
		is_near_target = false
		current_target = null
		return

	_update_viewport_info()
	_find_best_target()
	_calculate_correction()


func _update_viewport_info() -> void:
	"""Atualiza informações do viewport"""
	viewport_size = get_viewport().get_visible_rect().size
	screen_center = viewport_size / 2.0


func _find_best_target() -> void:
	"""Encontra o melhor alvo para aim assist"""
	current_target = null
	var best_score: float = INF

	# Pega todos os inimigos
	var enemies = get_tree().get_nodes_in_group("enemies")

	for enemy in enemies:
		if not enemy is Node3D:
			continue

		if not _is_valid_target(enemy):
			continue

		# Calcula posição na tela
		var enemy_pos = _get_target_center(enemy)
		var screen_pos = camera.unproject_position(enemy_pos)

		# Calcula distância do centro da tela
		var screen_distance = screen_pos.distance_to(screen_center)

		if screen_distance > detection_radius:
			continue

		# Calcula score (menor = melhor)
		# Considera distância na tela e distância 3D
		var world_distance = camera.global_position.distance_to(enemy_pos)
		var score = screen_distance + world_distance * 2.0

		if score < best_score:
			best_score = score
			current_target = enemy
			target_screen_position = screen_pos


func _is_valid_target(target: Node3D) -> bool:
	"""Verifica se o alvo é válido"""
	if not target.is_inside_tree():
		return false

	# Verifica se está vivo (se tiver método)
	if target.has_method("is_alive"):
		if not target.is_alive():
			return false

	# Verifica distância
	var distance = camera.global_position.distance_to(target.global_position)
	if distance > max_distance:
		return false

	# Verifica se está na frente da câmera
	var to_target = (target.global_position - camera.global_position).normalized()
	var forward = -camera.global_transform.basis.z
	if to_target.dot(forward) < 0.5:  # Precisa estar aproximadamente à frente
		return false

	# Verifica linha de visão (raycast)
	if not _has_line_of_sight(target):
		return false

	return true


func _has_line_of_sight(target: Node3D) -> bool:
	"""Verifica se há linha de visão para o alvo"""
	var space_state = camera.get_world_3d().direct_space_state

	var query = PhysicsRayQueryParameters3D.create(
		camera.global_position,
		_get_target_center(target)
	)
	query.exclude = [player] if player else []
	query.collision_mask = 0b111  # Layers 1, 2, 3

	var result = space_state.intersect_ray(query)

	if result.is_empty():
		return true

	# Verifica se o que atingimos é o próprio alvo ou filho dele
	var collider = result.get("collider")
	if collider == target:
		return true
	if collider and collider.get_parent() == target:
		return true

	return false


func _get_target_center(target: Node3D) -> Vector3:
	"""Retorna o centro do alvo (preferencialmente a cabeça/torso)"""
	# Tenta encontrar um ponto de mira específico
	var aim_point = target.get_node_or_null("AimPoint")
	if aim_point:
		return aim_point.global_position

	# Usa o centro do alvo com offset para cima
	return target.global_position + Vector3(0, 1.0, 0)


func _calculate_correction() -> void:
	"""Calcula a correção de mira"""
	correction_vector = Vector2.ZERO
	is_near_target = false

	if not current_target:
		return

	# Calcula vetor de correção
	var to_target = target_screen_position - screen_center
	var distance = to_target.length()

	if distance < detection_radius:
		is_near_target = true

		# Normaliza e aplica força do magnetismo
		# Quanto mais perto do centro, menor a correção (já está quase lá)
		var distance_factor = distance / detection_radius
		correction_vector = to_target.normalized() * magnetism_strength * distance_factor


# === API PÚBLICA ===

func get_sensitivity_multiplier() -> float:
	"""Retorna o multiplicador de sensibilidade (slowdown)"""
	if not enabled or not is_near_target:
		return 1.0

	return slowdown_factor


func get_correction() -> Vector2:
	"""Retorna o vetor de correção para aplicar ao input do mouse"""
	if not enabled:
		return Vector2.ZERO

	return correction_vector


func apply_to_mouse_input(input: Vector2) -> Vector2:
	"""Aplica aim assist ao input do mouse"""
	if not enabled:
		return input

	# Aplica slowdown
	var modified_input = input * get_sensitivity_multiplier()

	# Aplica magnetismo sutil
	if is_near_target and correction_vector.length() > 0.001:
		# Adiciona uma pequena tendência em direção ao alvo
		modified_input += correction_vector * 0.5

	return modified_input


func has_target() -> bool:
	"""Retorna se há um alvo no alcance do aim assist"""
	return current_target != null


func get_current_target() -> Node3D:
	"""Retorna o alvo atual"""
	return current_target


func set_enabled(value: bool) -> void:
	"""Ativa/desativa aim assist"""
	enabled = value
	if not enabled:
		current_target = null
		is_near_target = false
		correction_vector = Vector2.ZERO
