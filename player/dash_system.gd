extends Node

# Dash System - Sistema de dash com 3 cargas
# Movimento rápido com efeitos visuais satisfatórios

class_name DashSystem

# === SIGNALS ===
signal dash_started(direction: Vector3)
signal dash_ended()
signal charge_used(remaining: int)
signal charge_restored(total: int)
signal charges_changed(current: int, max_charges: int, timers: Array)

# === CONFIGURAÇÃO ===
@export_group("Dash Config")
@export var max_charges: int = 3           # Máximo de cargas
@export var charge_cooldown: float = 10.0  # Cooldown por carga (segundos)
@export var dash_distance: float = 8.0     # Distância do dash
@export var dash_duration: float = 0.12    # Duração do movimento
@export var invulnerability_duration: float = 0.15  # Frames de invencibilidade

# === ESTADO ===
var charges: int = 3
var charge_timers: Array[float] = [0.0, 0.0, 0.0]  # Timers individuais
var is_dashing: bool = false
var is_invulnerable: bool = false
var dash_direction: Vector3 = Vector3.ZERO
var dash_progress: float = 0.0

# Referências
var player: CharacterBody3D = null
var camera_effects: CameraEffects = null
var current_weapon: Node3D = null

# Posições para o dash
var dash_start_pos: Vector3 = Vector3.ZERO
var dash_end_pos: Vector3 = Vector3.ZERO


func _ready() -> void:
	charges = max_charges
	charge_timers.resize(max_charges)
	for i in range(max_charges):
		charge_timers[i] = 0.0


func setup(player_ref: CharacterBody3D, camera_fx: CameraEffects = null) -> void:
	"""Configura referências do sistema de dash"""
	player = player_ref
	camera_effects = camera_fx


func _process(delta: float) -> void:
	_update_charge_timers(delta)
	
	if is_dashing:
		_process_dash(delta)


func _update_charge_timers(delta: float) -> void:
	"""Atualiza timers de recarga das cargas"""
	var charges_restored = false
	
	for i in range(max_charges):
		if charge_timers[i] > 0:
			charge_timers[i] -= delta
			
			if charge_timers[i] <= 0:
				charge_timers[i] = 0.0
				charges += 1
				charges = min(charges, max_charges)
				charges_restored = true
				charge_restored.emit(charges)
	
	# Emite sinal de mudança de cargas
	charges_changed.emit(charges, max_charges, charge_timers.duplicate())


func can_dash() -> bool:
	"""Verifica se pode usar dash"""
	return charges > 0 and not is_dashing and player != null


func execute_dash(direction: Vector3) -> void:
	"""Executa o dash na direção especificada"""
	if not can_dash():
		return
	
	# Consome uma carga
	charges -= 1
	
	# Encontra o índice do timer que está em 0 (carga que foi usada)
	for i in range(max_charges):
		if charge_timers[i] <= 0:
			charge_timers[i] = charge_cooldown
			break
	
	charge_used.emit(charges)
	
	# Configura o dash
	dash_direction = direction.normalized()
	dash_direction.y = 0  # Mantém no plano horizontal
	
	if dash_direction.length() < 0.1:
		# Se não tem direção, usa a direção que o player está olhando
		dash_direction = -player.transform.basis.z
		dash_direction.y = 0
		dash_direction = dash_direction.normalized()
	
	is_dashing = true
	is_invulnerable = true
	dash_progress = 0.0
	
	dash_start_pos = player.global_position
	dash_end_pos = dash_start_pos + dash_direction * dash_distance
	
	# Auto-reload da arma
	_trigger_auto_reload()
	
	# Efeitos visuais
	_trigger_dash_effects()
	
	dash_started.emit(dash_direction)
	
	# Timer de invulnerabilidade
	get_tree().create_timer(invulnerability_duration).timeout.connect(_end_invulnerability)


func _process_dash(delta: float) -> void:
	"""Processa o movimento do dash"""
	if not player:
		is_dashing = false
		return
	
	dash_progress += delta / dash_duration
	
	if dash_progress >= 1.0:
		# Dash finalizado
		dash_progress = 1.0
		_end_dash()
		return
	
	# Interpolação suave (ease out)
	var eased_progress = 1.0 - pow(1.0 - dash_progress, 3.0)
	
	# Calcula nova posição
	var new_pos = dash_start_pos.lerp(dash_end_pos, eased_progress)
	
	# Usa move_and_slide para respeitar colisões
	var velocity = (new_pos - player.global_position) / delta
	player.velocity = velocity
	player.move_and_slide()


func _end_dash() -> void:
	"""Finaliza o dash"""
	is_dashing = false
	dash_progress = 0.0
	
	# Efeito de finalização
	if camera_effects and camera_effects.has_method("on_dash_end"):
		camera_effects.on_dash_end()
	
	dash_ended.emit()


func _end_invulnerability() -> void:
	"""Termina a invulnerabilidade"""
	is_invulnerable = false


func _trigger_auto_reload() -> void:
	"""Recarrega a arma instantaneamente"""
	if not player:
		return
	
	# Busca a arma atual
	current_weapon = player.get("current_weapon")
	if not current_weapon:
		return
	
	# Chama instant_reload se existir
	if current_weapon.has_method("instant_reload"):
		current_weapon.instant_reload()
	elif "current_ammo" in current_weapon and "magazine_size" in current_weapon:
		# Fallback: recarrega diretamente
		current_weapon.current_ammo = current_weapon.magazine_size
		if current_weapon.has_signal("ammo_changed"):
			current_weapon.ammo_changed.emit(current_weapon.current_ammo, current_weapon.magazine_size)


func _trigger_dash_effects() -> void:
	"""Dispara efeitos visuais do dash"""
	if camera_effects:
		if camera_effects.has_method("on_dash_start"):
			camera_effects.on_dash_start()
		elif camera_effects.has_method("apply_screen_shake"):
			camera_effects.apply_screen_shake(0.3)


func get_charges() -> int:
	"""Retorna cargas atuais"""
	return charges


func get_charge_progress(index: int) -> float:
	"""Retorna progresso de recarga de uma carga específica (0.0 a 1.0)"""
	if index < 0 or index >= max_charges:
		return 1.0
	
	if charge_timers[index] <= 0:
		return 1.0
	
	return 1.0 - (charge_timers[index] / charge_cooldown)


func is_player_invulnerable() -> bool:
	"""Retorna se o player está invulnerável pelo dash"""
	return is_invulnerable


func reset() -> void:
	"""Reseta o sistema de dash"""
	charges = max_charges
	is_dashing = false
	is_invulnerable = false
	dash_progress = 0.0
	
	for i in range(max_charges):
		charge_timers[i] = 0.0
