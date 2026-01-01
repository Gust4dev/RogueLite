extends Node

# Weapon Sway System - Movimento natural da arma
# Sway com mouse, movimento, e respiração

class_name WeaponSway

# Referência à arma
var weapon: Node3D = null

# === CONFIGURAÇÃO DO MOUSE SWAY ===
@export_group("Mouse Sway")
@export var mouse_sway_enabled: bool = true
@export var mouse_sway_amount: Vector2 = Vector2(0.002, 0.002)  # Quanto move com mouse
@export var mouse_sway_max: Vector2 = Vector2(0.05, 0.03)  # Limite máximo
@export var mouse_sway_smooth: float = 10.0  # Suavização
@export var mouse_rotation_amount: Vector2 = Vector2(0.5, 0.3)  # Rotação com mouse (graus)

# === CONFIGURAÇÃO DO MOVEMENT SWAY ===
@export_group("Movement Sway")
@export var movement_sway_enabled: bool = true
@export var movement_sway_amount: float = 0.02  # Quantidade de sway
@export var movement_sway_frequency: float = 8.0  # Frequência
@export var movement_sway_smooth: float = 8.0
@export var sprint_sway_multiplier: float = 1.3

# === CONFIGURAÇÃO DO IDLE SWAY (respiração) ===
@export_group("Idle Sway")
@export var idle_sway_enabled: bool = true
@export var idle_sway_amount: Vector2 = Vector2(0.003, 0.002)  # Amplitude muito sutil
@export var idle_sway_frequency: float = 1.2  # Frequência lenta
@export var idle_rotation_amount: float = 0.3  # Rotação sutil (graus)

# === ESTADO INTERNO ===
# Posição original
var original_position: Vector3 = Vector3.ZERO
var original_rotation: Vector3 = Vector3.ZERO

# Mouse sway
var mouse_input: Vector2 = Vector2.ZERO
var mouse_sway_position: Vector3 = Vector3.ZERO
var mouse_sway_rotation: Vector3 = Vector3.ZERO
var target_mouse_sway_pos: Vector3 = Vector3.ZERO
var target_mouse_sway_rot: Vector3 = Vector3.ZERO

# Movement sway
var movement_sway_time: float = 0.0
var movement_sway_offset: Vector3 = Vector3.ZERO
var current_movement_intensity: float = 0.0

# Idle sway
var idle_sway_time: float = 0.0
var idle_sway_offset: Vector3 = Vector3.ZERO
var idle_sway_rotation_offset: Vector3 = Vector3.ZERO

# Estado
var is_moving: bool = false
var is_sprinting: bool = false
var is_aiming: bool = false  # Para futuro ADS


func _ready() -> void:
	# Randomiza o tempo de idle sway
	idle_sway_time = randf() * TAU


func setup(weapon_node: Node3D) -> void:
	"""Configura a arma alvo"""
	weapon = weapon_node
	if weapon:
		original_position = weapon.position
		original_rotation = weapon.rotation


func _process(delta: float) -> void:
	if not weapon:
		return

	_update_mouse_sway(delta)
	_update_movement_sway(delta)
	_update_idle_sway(delta)

	# Não aplica aqui - deixa o sistema principal aplicar
	# para combinar com outros efeitos


func _update_mouse_sway(delta: float) -> void:
	"""Atualiza o sway baseado no movimento do mouse"""
	if not mouse_sway_enabled:
		mouse_sway_position = Vector3.ZERO
		mouse_sway_rotation = Vector3.ZERO
		return

	# Calcula target baseado no input do mouse
	target_mouse_sway_pos.x = clamp(-mouse_input.x * mouse_sway_amount.x, -mouse_sway_max.x, mouse_sway_max.x)
	target_mouse_sway_pos.y = clamp(-mouse_input.y * mouse_sway_amount.y, -mouse_sway_max.y, mouse_sway_max.y)

	target_mouse_sway_rot.y = clamp(-mouse_input.x * deg_to_rad(mouse_rotation_amount.x), deg_to_rad(-5), deg_to_rad(5))
	target_mouse_sway_rot.x = clamp(mouse_input.y * deg_to_rad(mouse_rotation_amount.y), deg_to_rad(-3), deg_to_rad(3))

	# Suaviza o movimento
	mouse_sway_position = mouse_sway_position.lerp(target_mouse_sway_pos, delta * mouse_sway_smooth)
	mouse_sway_rotation = mouse_sway_rotation.lerp(target_mouse_sway_rot, delta * mouse_sway_smooth)

	# Decai o input do mouse
	mouse_input = mouse_input.lerp(Vector2.ZERO, delta * 5.0)


func _update_movement_sway(delta: float) -> void:
	"""Atualiza o sway baseado no movimento do jogador"""
	if not movement_sway_enabled:
		movement_sway_offset = Vector3.ZERO
		return

	# Suaviza a intensidade
	var target_intensity = 1.0 if is_moving else 0.0
	current_movement_intensity = lerp(current_movement_intensity, target_intensity, delta * movement_sway_smooth)

	if current_movement_intensity < 0.01:
		movement_sway_offset = Vector3.ZERO
		return

	# Calcula frequência e amplitude
	var freq = movement_sway_frequency
	var amp = movement_sway_amount

	if is_sprinting:
		freq *= sprint_sway_multiplier
		amp *= sprint_sway_multiplier

	# Avança o tempo
	movement_sway_time += delta * freq

	# Movimento pendular
	movement_sway_offset.x = sin(movement_sway_time) * amp * current_movement_intensity
	movement_sway_offset.y = abs(cos(movement_sway_time)) * amp * 0.5 * current_movement_intensity


func _update_idle_sway(delta: float) -> void:
	"""Atualiza o sway de idle (respiração)"""
	if not idle_sway_enabled:
		idle_sway_offset = Vector3.ZERO
		idle_sway_rotation_offset = Vector3.ZERO
		return

	# Só aplica quando não está se movendo muito
	var idle_factor = 1.0 - current_movement_intensity

	idle_sway_time += delta * idle_sway_frequency * TAU

	# Movimento muito sutil
	idle_sway_offset.x = sin(idle_sway_time * 0.7) * idle_sway_amount.x * idle_factor
	idle_sway_offset.y = sin(idle_sway_time) * idle_sway_amount.y * idle_factor

	# Rotação muito sutil
	idle_sway_rotation_offset.z = sin(idle_sway_time * 0.5) * deg_to_rad(idle_rotation_amount) * idle_factor


# === API PÚBLICA ===

func get_total_offset() -> Vector3:
	"""Retorna o offset total do sway"""
	return mouse_sway_position + movement_sway_offset + idle_sway_offset


func get_total_rotation() -> Vector3:
	"""Retorna a rotação total do sway"""
	return mouse_sway_rotation + idle_sway_rotation_offset


func add_mouse_input(input: Vector2) -> void:
	"""Adiciona input do mouse para o sway"""
	mouse_input += input


func set_movement_state(moving: bool, sprinting: bool) -> void:
	"""Define o estado de movimento"""
	is_moving = moving
	is_sprinting = sprinting


func set_aiming(aiming: bool) -> void:
	"""Define se está mirando (reduz sway)"""
	is_aiming = aiming
	# TODO: Reduzir sway quando mirando


func reset() -> void:
	"""Reseta o sway"""
	mouse_input = Vector2.ZERO
	mouse_sway_position = Vector3.ZERO
	mouse_sway_rotation = Vector3.ZERO
	target_mouse_sway_pos = Vector3.ZERO
	target_mouse_sway_rot = Vector3.ZERO

	movement_sway_offset = Vector3.ZERO
	current_movement_intensity = 0.0

	idle_sway_offset = Vector3.ZERO
	idle_sway_rotation_offset = Vector3.ZERO
