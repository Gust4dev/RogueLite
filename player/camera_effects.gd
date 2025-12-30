extends Node

# Camera Effects - Gerencia efeitos da câmera como recoil e screen shake

class_name CameraEffects

# Referência à câmera
@onready var camera: Camera3D = get_parent()

# Recoil
var recoil_amount: Vector2 = Vector2.ZERO
var recoil_recovery_speed: float = 5.0

# Screen shake
var shake_amount: float = 0.0
var shake_decay: float = 10.0
var shake_offset: Vector3 = Vector3.ZERO

# Original rotation pra retornar após recoil
var original_rotation: Vector3 = Vector3.ZERO

func _ready() -> void:
	if camera:
		original_rotation = camera.rotation

func _process(delta: float) -> void:
	# Processa recoil recovery
	if recoil_amount.length() > 0.01:
		recoil_amount = recoil_amount.lerp(Vector2.ZERO, recoil_recovery_speed * delta)

		# Aplica recoil à rotação
		if camera:
			camera.rotation.x = original_rotation.x + recoil_amount.y
			camera.rotation.y = original_rotation.y + recoil_amount.x
	else:
		recoil_amount = Vector2.ZERO

	# Processa screen shake
	if shake_amount > 0.0:
		shake_amount -= shake_decay * delta
		shake_amount = max(0.0, shake_amount)

		# Gera offset aleatório
		shake_offset = Vector3(
			randf_range(-shake_amount, shake_amount),
			randf_range(-shake_amount, shake_amount),
			0.0
		)

		# Aplica shake
		if camera:
			camera.h_offset = shake_offset.x
			camera.v_offset = shake_offset.y
	else:
		shake_offset = Vector3.ZERO
		if camera:
			camera.h_offset = 0.0
			camera.v_offset = 0.0

func apply_recoil(horizontal: float, vertical: float) -> void:
	"""Aplica recoil à câmera"""
	recoil_amount += Vector2(horizontal, vertical)

func apply_screen_shake(intensity: float) -> void:
	"""Aplica screen shake"""
	shake_amount += intensity

func reset_effects() -> void:
	"""Reseta todos os efeitos"""
	recoil_amount = Vector2.ZERO
	shake_amount = 0.0
	shake_offset = Vector3.ZERO

	if camera:
		camera.rotation = original_rotation
		camera.h_offset = 0.0
		camera.v_offset = 0.0
