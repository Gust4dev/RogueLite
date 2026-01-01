extends Node

# Camera Shake System - Sistema de shake usando Perlin Noise
# Usa trauma system para shakes mais naturais e cinematográficos

class_name CameraShake

# Referência à câmera
var camera: Camera3D = null

# === CONFIGURAÇÃO DO SHAKE ===
# Intensidade máxima do shake
@export var max_offset: Vector2 = Vector2(0.5, 0.5)  # Offset máximo X/Y
@export var max_roll: float = 0.1  # Roll máximo em radianos

# Velocidade do noise (quanto maior, mais rápido o shake)
@export var noise_speed: float = 30.0

# Decaimento do trauma (quanto maior, mais rápido desaparece)
@export var trauma_decay: float = 1.5

# Expoente do trauma (2 = quadrático, mais natural)
@export var trauma_power: float = 2.0

# === PERLIN NOISE ===
var noise: FastNoiseLite
var noise_offset: float = 0.0

# === ESTADO ===
var trauma: float = 0.0  # 0 a 1, quantidade de "trauma"
var shake_offset: Vector3 = Vector3.ZERO
var shake_rotation: float = 0.0

# === LAYERS DE SHAKE (diferentes fontes) ===
var continuous_trauma: float = 0.0  # Para efeitos contínuos


func _ready() -> void:
	# Configura o Perlin Noise
	noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 1.0
	noise.seed = randi()

	# Encontra a câmera
	_find_camera()


func _find_camera() -> void:
	"""Encontra a câmera parent"""
	var parent = get_parent()
	if parent is Camera3D:
		camera = parent


func _process(delta: float) -> void:
	# Avança o offset do noise
	noise_offset += delta * noise_speed

	# Decai o trauma
	if trauma > 0:
		trauma = max(trauma - trauma_decay * delta, 0.0)

	# Calcula shake total (trauma + continuous)
	var total_trauma = clamp(trauma + continuous_trauma, 0.0, 1.0)

	# Calcula a intensidade do shake (trauma elevado ao expoente)
	var shake_intensity = pow(total_trauma, trauma_power)

	if shake_intensity > 0.001:
		_calculate_shake(shake_intensity)
		_apply_shake()
	else:
		_reset_shake()


func _calculate_shake(intensity: float) -> void:
	"""Calcula os valores de shake usando Perlin Noise"""
	# Usa diferentes offsets para cada eixo para evitar correlação
	var noise_x = noise.get_noise_1d(noise_offset)
	var noise_y = noise.get_noise_1d(noise_offset + 100.0)
	var noise_roll = noise.get_noise_1d(noise_offset + 200.0)

	# Aplica intensidade
	shake_offset.x = noise_x * max_offset.x * intensity
	shake_offset.y = noise_y * max_offset.y * intensity
	shake_rotation = noise_roll * max_roll * intensity


func _apply_shake() -> void:
	"""Aplica o shake à câmera"""
	if camera:
		camera.h_offset = shake_offset.x
		camera.v_offset = shake_offset.y
		# Roll é aplicado como rotação Z adicional
		# Nota: vamos aplicar isso no sistema principal de câmera


func _reset_shake() -> void:
	"""Reseta o shake quando não há trauma"""
	shake_offset = Vector3.ZERO
	shake_rotation = 0.0
	if camera:
		camera.h_offset = 0.0
		camera.v_offset = 0.0


# === API PÚBLICA ===

func add_trauma(amount: float) -> void:
	"""Adiciona trauma (causa shake)"""
	trauma = clamp(trauma + amount, 0.0, 1.0)


func set_continuous_trauma(amount: float) -> void:
	"""Define trauma contínuo (para efeitos persistentes)"""
	continuous_trauma = clamp(amount, 0.0, 0.3)  # Limitado para não ser muito forte


func get_shake_offset() -> Vector3:
	"""Retorna o offset atual do shake"""
	return shake_offset


func get_shake_rotation() -> float:
	"""Retorna a rotação atual do shake (roll)"""
	return shake_rotation


func get_current_intensity() -> float:
	"""Retorna a intensidade atual do shake"""
	var total_trauma = clamp(trauma + continuous_trauma, 0.0, 1.0)
	return pow(total_trauma, trauma_power)


func reset() -> void:
	"""Reseta completamente o shake"""
	trauma = 0.0
	continuous_trauma = 0.0
	_reset_shake()


# === PRESETS DE SHAKE ===

func shake_shoot() -> void:
	"""Shake para tiro - leve e rápido"""
	add_trauma(0.15)


func shake_damage(damage_percent: float) -> void:
	"""Shake para dano recebido - baseado na quantidade de dano"""
	add_trauma(0.2 + damage_percent * 0.3)


func shake_explosion(distance: float, max_distance: float = 20.0) -> void:
	"""Shake para explosão - baseado na distância"""
	var intensity = 1.0 - clamp(distance / max_distance, 0.0, 1.0)
	add_trauma(0.5 * intensity)


func shake_land(fall_velocity: float) -> void:
	"""Shake para aterrisagem - baseado na velocidade de queda"""
	var intensity = clamp(abs(fall_velocity) / 20.0, 0.0, 0.4)
	add_trauma(intensity)


# === CONFIGURAÇÃO DINÂMICA ===

func set_shake_config(offset: Vector2, roll: float, speed: float, decay: float) -> void:
	"""Configura os parâmetros de shake"""
	max_offset = offset
	max_roll = roll
	noise_speed = speed
	trauma_decay = decay
