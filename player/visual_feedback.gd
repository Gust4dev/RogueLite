extends Node

# Visual Feedback System - Sistema de feedback visual
# Crosshair dinâmico, hitmarker, FOV pulse, vignette

class_name VisualFeedback

# Referências
var camera: Camera3D = null
var hud: CanvasLayer = null

# === CONFIGURAÇÃO DO CROSSHAIR DINÂMICO ===
@export_group("Crosshair")
@export var crosshair_enabled: bool = true
@export var crosshair_base_size: float = 10.0
@export var crosshair_max_expand: float = 30.0
@export var crosshair_expand_speed: float = 20.0
@export var crosshair_recover_speed: float = 8.0
## Expansão por estado de movimento
@export var crosshair_walk_expand: float = 5.0
@export var crosshair_sprint_expand: float = 12.0
@export var crosshair_air_expand: float = 20.0

# === CONFIGURAÇÃO DO HITMARKER ===
@export_group("Hitmarker")
@export var hitmarker_enabled: bool = true
@export var hitmarker_duration: float = 0.15
@export var hitmarker_size: float = 15.0
@export var hitmarker_color: Color = Color.WHITE
@export var hitmarker_kill_color: Color = Color.RED

# === CONFIGURAÇÃO DO FOV ===
@export_group("FOV Effects")
@export var fov_effects_enabled: bool = true
@export var fov_base: float = 75.0
@export var fov_sprint_add: float = 5.0
@export var fov_shoot_kick: float = 2.0
@export var fov_damage_kick: float = -3.0
@export var fov_transition_speed: float = 10.0

# === CONFIGURAÇÃO DA VIGNETTE ===
@export_group("Vignette")
@export var vignette_enabled: bool = true
@export var vignette_damage_intensity: float = 0.5
@export var vignette_damage_duration: float = 0.3
@export var vignette_low_health_threshold: float = 30.0

# === ESTADO INTERNO ===
# Crosshair
var crosshair_current_size: float = 10.0
var crosshair_target_size: float = 10.0

# Hitmarker
var hitmarker_active: bool = false
var hitmarker_timer: float = 0.0
var hitmarker_is_kill: bool = false

# FOV
var fov_current: float = 75.0
var fov_target: float = 75.0
var fov_kick: float = 0.0

# Vignette
var vignette_intensity: float = 0.0
var vignette_target: float = 0.0

# Estado
var is_moving: bool = false
var is_sprinting: bool = false
var is_in_air: bool = false
var current_health_percent: float = 100.0


func _ready() -> void:
	fov_current = fov_base
	fov_target = fov_base
	crosshair_current_size = crosshair_base_size
	crosshair_target_size = crosshair_base_size


func setup(camera_node: Camera3D, hud_node: CanvasLayer = null) -> void:
	"""Configura as referências"""
	camera = camera_node
	hud = hud_node
	if camera:
		fov_base = camera.fov
		fov_current = fov_base
		fov_target = fov_base


func _process(delta: float) -> void:
	_update_crosshair(delta)
	_update_hitmarker(delta)
	_update_fov(delta)
	_update_vignette(delta)


func _update_crosshair(delta: float) -> void:
	"""Atualiza o tamanho do crosshair baseado no estado de movimento"""
	if not crosshair_enabled:
		return

	# Calcula expansão baseada no estado atual
	var state_expand: float = 0.0
	if is_in_air:
		state_expand = crosshair_air_expand
	elif is_sprinting:
		state_expand = crosshair_sprint_expand
	elif is_moving:
		state_expand = crosshair_walk_expand

	# O alvo base é crosshair_base_size + expansão do estado
	var base_with_state: float = crosshair_base_size + state_expand

	# Target tende ao base_with_state (mas pode estar maior por tiro)
	if crosshair_target_size > base_with_state:
		# Se está maior (por tiro), recupera mais devagar
		crosshair_target_size = lerp(crosshair_target_size, base_with_state, delta * crosshair_recover_speed)
	else:
		# Se precisa expandir (mudou de estado), expande rápido
		crosshair_target_size = lerp(crosshair_target_size, base_with_state, delta * crosshair_expand_speed)

	# Current tende ao target
	if crosshair_current_size < crosshair_target_size:
		crosshair_current_size = lerp(crosshair_current_size, crosshair_target_size, delta * crosshair_expand_speed)
	else:
		crosshair_current_size = lerp(crosshair_current_size, crosshair_target_size, delta * crosshair_recover_speed)


func _update_hitmarker(delta: float) -> void:
	"""Atualiza o hitmarker"""
	if not hitmarker_enabled:
		return

	if hitmarker_active:
		hitmarker_timer -= delta
		if hitmarker_timer <= 0:
			hitmarker_active = false


func _update_fov(delta: float) -> void:
	"""Atualiza o FOV"""
	if not fov_effects_enabled or not camera:
		return

	# Calcula FOV alvo
	var target = fov_base
	if is_sprinting:
		target += fov_sprint_add

	fov_target = target

	# Aplica kick (decai rapidamente)
	fov_kick = lerp(fov_kick, 0.0, delta * 15.0)

	# Suaviza transição
	fov_current = lerp(fov_current, fov_target + fov_kick, delta * fov_transition_speed)

	# Aplica à câmera
	camera.fov = fov_current


func _update_vignette(delta: float) -> void:
	"""Atualiza a vignette"""
	if not vignette_enabled:
		return

	# Vignette constante quando vida baixa
	var low_health_vignette = 0.0
	if current_health_percent < vignette_low_health_threshold:
		low_health_vignette = (1.0 - current_health_percent / vignette_low_health_threshold) * 0.3

	# Decai vignette de dano
	vignette_target = lerp(vignette_target, low_health_vignette, delta * (1.0 / vignette_damage_duration))
	vignette_intensity = lerp(vignette_intensity, vignette_target, delta * 10.0)


# === API PÚBLICA ===

func on_shoot() -> void:
	"""Chamado quando atira"""
	# Expande crosshair
	if crosshair_enabled:
		crosshair_target_size = min(crosshair_target_size + 8.0, crosshair_max_expand)

	# FOV kick
	if fov_effects_enabled:
		fov_kick += fov_shoot_kick


func on_hit(is_kill: bool = false) -> void:
	"""Chamado quando acerta um inimigo"""
	if hitmarker_enabled:
		hitmarker_active = true
		hitmarker_timer = hitmarker_duration
		hitmarker_is_kill = is_kill


func on_damage(damage_percent: float) -> void:
	"""Chamado quando toma dano"""
	# Vignette flash
	if vignette_enabled:
		vignette_target = vignette_damage_intensity

	# FOV kick (negativo = diminui)
	if fov_effects_enabled:
		fov_kick += fov_damage_kick


func set_health(health_percent: float) -> void:
	"""Atualiza a porcentagem de vida"""
	current_health_percent = health_percent


func set_movement_state(moving: bool, sprinting: bool) -> void:
	"""Define estado de movimento para a crosshair"""
	is_moving = moving
	is_sprinting = sprinting


func set_in_air(in_air: bool) -> void:
	"""Define se o jogador está no ar"""
	is_in_air = in_air


func set_sprinting(sprinting: bool) -> void:
	"""Define estado de sprint (compatibilidade)"""
	is_sprinting = sprinting


func get_crosshair_size() -> float:
	"""Retorna o tamanho atual do crosshair"""
	return crosshair_current_size


func is_hitmarker_active() -> bool:
	"""Retorna se o hitmarker está ativo"""
	return hitmarker_active


func get_hitmarker_info() -> Dictionary:
	"""Retorna informações do hitmarker para desenhar"""
	return {
		"active": hitmarker_active,
		"size": hitmarker_size,
		"color": hitmarker_kill_color if hitmarker_is_kill else hitmarker_color,
		"alpha": hitmarker_timer / hitmarker_duration if hitmarker_duration > 0 else 0.0
	}


func get_vignette_intensity() -> float:
	"""Retorna a intensidade da vignette"""
	return vignette_intensity


func reset() -> void:
	"""Reseta todos os efeitos"""
	crosshair_current_size = crosshair_base_size
	crosshair_target_size = crosshair_base_size
	hitmarker_active = false
	fov_current = fov_base
	fov_target = fov_base
	fov_kick = 0.0
	vignette_intensity = 0.0
	vignette_target = 0.0
