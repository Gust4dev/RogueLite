extends Node

# Camera Effects - Sistema central que coordena todos os efeitos de câmera
# Integra: Recoil, Shake (Perlin Noise), Animações procedurais, Visual Feedback

class_name CameraEffects

# Referência à câmera
@onready var camera: Camera3D = get_parent()

# === SUB-SISTEMAS ===
var camera_shake: CameraShake = null
var camera_animation: CameraAnimation = null
var visual_feedback: VisualFeedback = null

# === RECOIL DA CÂMERA (separado do recoil da arma) ===
@export_group("Camera Recoil")
@export var camera_recoil_enabled: bool = true
@export var camera_recoil_amount: Vector2 = Vector2(0.5, 1.5)  # horizontal, vertical (graus)
@export var camera_recoil_randomness: Vector2 = Vector2(0.3, 0.2)  # aleatoriedade
@export var camera_recoil_recovery_speed: float = 8.0
@export var camera_recoil_snap_speed: float = 15.0

# Estado do recoil de câmera
var camera_recoil_current: Vector2 = Vector2.ZERO
var camera_recoil_target: Vector2 = Vector2.ZERO

# Original rotation para referência
var original_rotation: Vector3 = Vector3.ZERO
var player_look_rotation: Vector2 = Vector2.ZERO  # Rotação controlada pelo jogador


func _ready() -> void:
	if camera:
		original_rotation = camera.rotation

	# Cria sub-sistemas
	_setup_subsystems()


func _setup_subsystems() -> void:
	"""Cria e configura todos os sub-sistemas"""

	# Camera Shake (Perlin Noise)
	camera_shake = CameraShake.new()
	camera_shake.name = "CameraShake"
	add_child(camera_shake)

	# Camera Animation (procedural)
	camera_animation = CameraAnimation.new()
	camera_animation.name = "CameraAnimation"
	add_child(camera_animation)

	# Visual Feedback
	visual_feedback = VisualFeedback.new()
	visual_feedback.name = "VisualFeedback"
	add_child(visual_feedback)

	# Configura referências
	if camera:
		visual_feedback.setup(camera)


func _process(delta: float) -> void:
	_update_camera_recoil(delta)
	_apply_all_effects()


func _update_camera_recoil(delta: float) -> void:
	"""Atualiza o recoil da câmera"""
	if not camera_recoil_enabled:
		camera_recoil_current = Vector2.ZERO
		camera_recoil_target = Vector2.ZERO
		return

	# Move em direção ao target rapidamente
	camera_recoil_current = camera_recoil_current.lerp(
		camera_recoil_target,
		delta * camera_recoil_snap_speed
	)

	# Target decai de volta a zero
	camera_recoil_target = camera_recoil_target.lerp(
		Vector2.ZERO,
		delta * camera_recoil_recovery_speed
	)


func _apply_all_effects() -> void:
	"""Aplica todos os efeitos combinados à câmera"""
	if not camera:
		return

	# Coleta offsets de todos os sistemas
	var total_offset = Vector3.ZERO
	var total_rotation = Vector3.ZERO

	# Camera Shake
	if camera_shake:
		total_offset += camera_shake.get_shake_offset()
		total_rotation.z += camera_shake.get_shake_rotation()

	# Camera Animation
	if camera_animation:
		total_offset += camera_animation.get_total_offset()
		total_rotation += camera_animation.get_total_rotation()

	# Camera Recoil (rotação)
	total_rotation.x += deg_to_rad(camera_recoil_current.y)  # Vertical
	total_rotation.y += deg_to_rad(camera_recoil_current.x)  # Horizontal

	# Aplica offsets (h_offset e v_offset para shake suave)
	camera.h_offset = total_offset.x
	camera.v_offset = total_offset.y

	# A rotação da câmera é controlada pelo player_controller
	# Aqui só adicionamos os efeitos extras
	# O roll é aplicado diretamente
	camera.rotation.z = total_rotation.z


# === API PÚBLICA - RECOIL ===

func apply_camera_recoil(horizontal_factor: float = 1.0, vertical_factor: float = 1.0) -> void:
	"""Aplica recoil à câmera (chamado ao atirar)"""
	if not camera_recoil_enabled:
		return

	# Calcula recoil com aleatoriedade
	var h_recoil = camera_recoil_amount.x * horizontal_factor
	h_recoil += randf_range(-camera_recoil_randomness.x, camera_recoil_randomness.x)

	var v_recoil = camera_recoil_amount.y * vertical_factor
	v_recoil += randf_range(-camera_recoil_randomness.y, camera_recoil_randomness.y)

	# Adiciona ao target (horizontal alterna, vertical sempre sobe)
	camera_recoil_target.x += h_recoil * (1.0 if randf() > 0.5 else -1.0)
	camera_recoil_target.y -= v_recoil  # Negativo = sobe


func get_camera_recoil_offset() -> Vector2:
	"""Retorna o offset atual do recoil para o player compensar"""
	return camera_recoil_current


# === API PÚBLICA - SHAKE ===

func apply_screen_shake(intensity: float) -> void:
	"""Aplica screen shake (compatibilidade com sistema antigo)"""
	if camera_shake:
		camera_shake.add_trauma(intensity)


func shake_shoot() -> void:
	"""Shake para tiro"""
	if camera_shake:
		camera_shake.shake_shoot()


func shake_damage(damage_percent: float) -> void:
	"""Shake para dano"""
	if camera_shake:
		camera_shake.shake_damage(damage_percent)


func shake_land(fall_velocity: float) -> void:
	"""Shake para aterrisagem"""
	if camera_shake:
		camera_shake.shake_land(fall_velocity)


# === API PÚBLICA - ANIMAÇÕES ===

func set_movement_state(moving: bool, sprinting: bool, speed: float) -> void:
	"""Define estado de movimento para animações e crosshair"""
	if camera_animation:
		camera_animation.set_movement_state(moving, sprinting, speed)

	if visual_feedback:
		visual_feedback.set_movement_state(moving, sprinting)


func set_in_air(in_air: bool) -> void:
	"""Define se o jogador está no ar (para crosshair)"""
	if visual_feedback:
		visual_feedback.set_in_air(in_air)


func check_landing(on_floor: bool, velocity_y: float) -> void:
	"""Verifica aterrisagem"""
	if camera_animation:
		camera_animation.check_landing(on_floor, velocity_y)


func trigger_shooting_effects() -> void:
	"""Dispara efeitos de tiro"""
	if camera_animation:
		camera_animation.trigger_shooting_tilt()

	if visual_feedback:
		visual_feedback.on_shoot()


# === API PÚBLICA - VISUAL FEEDBACK ===

func on_hit(is_kill: bool = false) -> void:
	"""Chamado quando acerta inimigo"""
	if visual_feedback:
		visual_feedback.on_hit(is_kill)


func on_damage(damage_percent: float) -> void:
	"""Chamado quando toma dano"""
	if visual_feedback:
		visual_feedback.on_damage(damage_percent)

	shake_damage(damage_percent)


func set_health(health_percent: float) -> void:
	"""Atualiza vida para efeitos"""
	if visual_feedback:
		visual_feedback.set_health(health_percent)


func get_crosshair_size() -> float:
	"""Retorna tamanho do crosshair"""
	if visual_feedback:
		return visual_feedback.get_crosshair_size()
	return 10.0


func get_hitmarker_info() -> Dictionary:
	"""Retorna info do hitmarker"""
	if visual_feedback:
		return visual_feedback.get_hitmarker_info()
	return {"active": false}


func get_vignette_intensity() -> float:
	"""Retorna intensidade da vignette"""
	if visual_feedback:
		return visual_feedback.get_vignette_intensity()
	return 0.0


# === RESET ===

func reset_effects() -> void:
	"""Reseta todos os efeitos"""
	camera_recoil_current = Vector2.ZERO
	camera_recoil_target = Vector2.ZERO

	if camera_shake:
		camera_shake.reset()

	if camera_animation:
		camera_animation.reset()

	if visual_feedback:
		visual_feedback.reset()

	if camera:
		camera.h_offset = 0.0
		camera.v_offset = 0.0
		camera.rotation.z = 0.0


# === COMPATIBILIDADE ===

func apply_recoil(horizontal: float, vertical: float) -> void:
	"""Compatibilidade com sistema antigo - agora usa o novo sistema"""
	apply_camera_recoil(horizontal * 100, vertical * 100)
