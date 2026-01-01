extends Node

# Camera Animation System - Animações procedurais de câmera
# Headbob, landing, shooting tilt, interaction feedback

class_name CameraAnimation

# Referência à câmera
var camera: Camera3D = null

# === HEADBOB (movimento ao andar) ===
@export_group("Headbob")
@export var headbob_enabled: bool = true
@export var headbob_frequency: float = 12.0  # Frequência do bob
@export var headbob_amplitude_v: float = 0.03  # Amplitude vertical
@export var headbob_amplitude_h: float = 0.02  # Amplitude horizontal
@export var headbob_roll_amplitude: float = 0.01  # Roll ao andar
@export var sprint_multiplier: float = 1.4  # Multiplica quando correndo

# === LANDING (aterrisagem) ===
@export_group("Landing")
@export var landing_enabled: bool = true
@export var landing_dip_amount: float = 0.15  # Quanto a câmera abaixa
@export var landing_dip_speed: float = 15.0  # Velocidade de descida
@export var landing_recovery_speed: float = 8.0  # Velocidade de recuperação
@export var landing_tilt_amount: float = 0.02  # Tilt ao pousar

# === SHOOTING TILT (tilt ao atirar) ===
@export_group("Shooting")
@export var shooting_tilt_enabled: bool = true
@export var shooting_tilt_amount: float = 0.015  # Quantidade de tilt
@export var shooting_tilt_speed: float = 20.0  # Velocidade do tilt
@export var shooting_tilt_recovery: float = 10.0  # Recuperação

# === BREATHING (respiração sutil) ===
@export_group("Breathing")
@export var breathing_enabled: bool = true
@export var breathing_amplitude: float = 0.003  # Amplitude muito sutil
@export var breathing_frequency: float = 0.3  # Frequência lenta

# === ESTADO INTERNO ===
# Headbob
var headbob_time: float = 0.0
var headbob_offset: Vector3 = Vector3.ZERO
var headbob_roll: float = 0.0
var current_headbob_intensity: float = 0.0

# Landing
var landing_offset: float = 0.0
var landing_tilt: float = 0.0
var is_landing: bool = false
var was_on_floor: bool = true
var fall_velocity: float = 0.0

# Shooting
var shooting_tilt: float = 0.0
var shooting_tilt_target: float = 0.0
var last_shot_direction: float = 1.0  # 1 ou -1 para alternar

# Breathing
var breathing_time: float = 0.0
var breathing_offset: Vector3 = Vector3.ZERO

# Estado de movimento
var is_moving: bool = false
var is_sprinting: bool = false
var movement_speed: float = 0.0


func _ready() -> void:
	_find_camera()
	# Randomiza o tempo de breathing para não começar igual
	breathing_time = randf() * TAU


func _find_camera() -> void:
	"""Encontra a câmera parent"""
	var parent = get_parent()
	if parent is Camera3D:
		camera = parent


func _process(delta: float) -> void:
	_update_headbob(delta)
	_update_landing(delta)
	_update_shooting_tilt(delta)
	_update_breathing(delta)


func _update_headbob(delta: float) -> void:
	"""Atualiza o headbob baseado no movimento"""
	if not headbob_enabled:
		headbob_offset = Vector3.ZERO
		headbob_roll = 0.0
		return

	# Suaviza a intensidade do headbob
	var target_intensity = 1.0 if is_moving else 0.0
	current_headbob_intensity = lerp(current_headbob_intensity, target_intensity, delta * 10.0)

	if current_headbob_intensity < 0.01:
		headbob_offset = Vector3.ZERO
		headbob_roll = 0.0
		return

	# Calcula frequência baseada na velocidade
	var freq = headbob_frequency
	var amp_v = headbob_amplitude_v
	var amp_h = headbob_amplitude_h
	var amp_roll = headbob_roll_amplitude

	if is_sprinting:
		freq *= sprint_multiplier
		amp_v *= sprint_multiplier
		amp_h *= sprint_multiplier
		amp_roll *= sprint_multiplier

	# Avança o tempo
	headbob_time += delta * freq

	# Calcula offset usando funções sinusoidais
	# Vertical: usa abs(sin) para criar o padrão de "passo"
	headbob_offset.y = sin(headbob_time) * amp_v * current_headbob_intensity

	# Horizontal: frequência dobrada para balançar dos dois lados
	headbob_offset.x = cos(headbob_time * 0.5) * amp_h * current_headbob_intensity

	# Roll: inclinação sutil ao andar
	headbob_roll = sin(headbob_time * 0.5) * amp_roll * current_headbob_intensity


func _update_landing(delta: float) -> void:
	"""Atualiza a animação de aterrisagem"""
	if not landing_enabled:
		landing_offset = 0.0
		landing_tilt = 0.0
		return

	if is_landing:
		# Movimento de descida
		landing_offset = lerp(landing_offset, landing_dip_amount, delta * landing_dip_speed)
		landing_tilt = lerp(landing_tilt, landing_tilt_amount, delta * landing_dip_speed)

		# Verifica se atingiu o pico
		if abs(landing_offset - landing_dip_amount) < 0.01:
			is_landing = false
	else:
		# Recuperação
		landing_offset = lerp(landing_offset, 0.0, delta * landing_recovery_speed)
		landing_tilt = lerp(landing_tilt, 0.0, delta * landing_recovery_speed)


func _update_shooting_tilt(delta: float) -> void:
	"""Atualiza o tilt ao atirar"""
	if not shooting_tilt_enabled:
		shooting_tilt = 0.0
		return

	# Move em direção ao target
	if abs(shooting_tilt_target) > 0.001:
		shooting_tilt = lerp(shooting_tilt, shooting_tilt_target, delta * shooting_tilt_speed)
		# Decai o target
		shooting_tilt_target = lerp(shooting_tilt_target, 0.0, delta * shooting_tilt_recovery)
	else:
		# Recuperação suave
		shooting_tilt = lerp(shooting_tilt, 0.0, delta * shooting_tilt_recovery)


func _update_breathing(delta: float) -> void:
	"""Atualiza a respiração sutil"""
	if not breathing_enabled:
		breathing_offset = Vector3.ZERO
		return

	breathing_time += delta * breathing_frequency * TAU

	# Movimento muito sutil de respiração
	breathing_offset.y = sin(breathing_time) * breathing_amplitude
	breathing_offset.x = cos(breathing_time * 0.7) * breathing_amplitude * 0.5


# === API PÚBLICA ===

func get_total_offset() -> Vector3:
	"""Retorna o offset total de todas as animações"""
	var offset = Vector3.ZERO
	offset += headbob_offset
	offset.y -= landing_offset  # Landing move para baixo
	offset += breathing_offset
	return offset


func get_total_rotation() -> Vector3:
	"""Retorna a rotação total de todas as animações"""
	var rotation = Vector3.ZERO
	rotation.z = headbob_roll + shooting_tilt + landing_tilt
	return rotation


func set_movement_state(moving: bool, sprinting: bool, speed: float) -> void:
	"""Define o estado de movimento atual"""
	is_moving = moving
	is_sprinting = sprinting
	movement_speed = speed


func trigger_landing(velocity: float) -> void:
	"""Dispara a animação de landing"""
	if not landing_enabled:
		return

	# Calcula intensidade baseada na velocidade de queda
	var intensity = clamp(abs(velocity) / 15.0, 0.2, 1.0)

	landing_dip_amount = 0.05 + 0.1 * intensity
	landing_tilt_amount = 0.01 + 0.02 * intensity
	is_landing = true


func trigger_shooting_tilt() -> void:
	"""Dispara o tilt de tiro"""
	if not shooting_tilt_enabled:
		return

	# Alterna a direção do tilt para variar
	last_shot_direction *= -1
	shooting_tilt_target = shooting_tilt_amount * last_shot_direction


func check_landing(on_floor: bool, velocity_y: float) -> void:
	"""Verifica se houve aterrisagem"""
	if on_floor and not was_on_floor:
		trigger_landing(fall_velocity)

	# Armazena a velocidade de queda
	if not on_floor:
		fall_velocity = velocity_y

	was_on_floor = on_floor


func reset() -> void:
	"""Reseta todas as animações"""
	headbob_offset = Vector3.ZERO
	headbob_roll = 0.0
	headbob_time = 0.0
	current_headbob_intensity = 0.0

	landing_offset = 0.0
	landing_tilt = 0.0
	is_landing = false

	shooting_tilt = 0.0
	shooting_tilt_target = 0.0

	breathing_offset = Vector3.ZERO
