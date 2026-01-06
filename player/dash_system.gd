extends Node

# Dash System - Sistema de dash com barra de estamina (souls-like)
# Barra regenera gradualmente, cada dash consome uma porção

class_name DashSystem

# === SIGNALS ===
signal dash_started(direction: Vector3)
signal dash_ended()
signal stamina_changed(current: float, maximum: float)
signal dash_used()

# === CONFIGURAÇÃO ===
@export_group("Dash Config")
@export var dash_distance: float = 8.0           # Distância do dash
@export var dash_duration: float = 0.12          # Duração do movimento
@export var invulnerability_duration: float = 0.15  # Frames de invencibilidade

@export_group("Stamina Config")
@export var max_stamina: float = 100.0           # Estamina máxima
@export var stamina_cost: float = 33.33          # Custo por dash (~3 dashes com barra cheia)
@export var stamina_regen_rate: float = 15.0     # Pontos por segundo
@export var stamina_regen_delay: float = 0.3     # Delay após usar dash antes de regenerar

# === ESTADO ===
var current_stamina: float = 100.0
var regen_cooldown: float = 0.0
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
	current_stamina = max_stamina
	stamina_changed.emit(current_stamina, max_stamina)


func setup(player_ref: CharacterBody3D, camera_fx: CameraEffects = null) -> void:
	"""Configura referências do sistema de dash"""
	player = player_ref
	camera_effects = camera_fx


func _process(delta: float) -> void:
	_update_stamina_regen(delta)
	
	if is_dashing:
		_process_dash(delta)


func _update_stamina_regen(delta: float) -> void:
	"""Regenera estamina gradualmente após cooldown"""
	# Atualiza cooldown
	if regen_cooldown > 0:
		regen_cooldown -= delta
		return
	
	# Regenera estamina
	if current_stamina < max_stamina:
		var old_stamina = current_stamina
		current_stamina = minf(current_stamina + stamina_regen_rate * delta, max_stamina)
		
		if current_stamina != old_stamina:
			stamina_changed.emit(current_stamina, max_stamina)


func can_dash() -> bool:
	"""Verifica se pode usar dash (tem estamina suficiente)"""
	return current_stamina >= stamina_cost and not is_dashing and player != null


func get_dash_count() -> int:
	"""Retorna quantos dashes podem ser feitos com a estamina atual"""
	return int(current_stamina / stamina_cost)


func execute_dash(direction: Vector3) -> void:
	"""Executa o dash na direção especificada"""
	if not can_dash():
		return
	
	# Consome estamina
	current_stamina -= stamina_cost
	regen_cooldown = stamina_regen_delay
	
	stamina_changed.emit(current_stamina, max_stamina)
	dash_used.emit()
	
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


func get_stamina() -> float:
	"""Retorna estamina atual"""
	return current_stamina


func get_stamina_percentage() -> float:
	"""Retorna porcentagem de estamina (0.0 a 1.0)"""
	return current_stamina / max_stamina


func is_player_invulnerable() -> bool:
	"""Retorna se o player está invulnerável pelo dash"""
	return is_invulnerable


func reset() -> void:
	"""Reseta o sistema de dash"""
	current_stamina = max_stamina
	is_dashing = false
	is_invulnerable = false
	dash_progress = 0.0
	regen_cooldown = 0.0
	stamina_changed.emit(current_stamina, max_stamina)


# === UPGRADE SUPPORT ===

func upgrade_stamina(additional_stamina: float) -> void:
	"""Aumenta a estamina máxima (chamado por upgrades)"""
	max_stamina += additional_stamina
	current_stamina += additional_stamina  # Também aumenta a atual
	stamina_changed.emit(current_stamina, max_stamina)


func upgrade_regen(additional_regen: float) -> void:
	"""Aumenta a taxa de regeneração (chamado por upgrades)"""
	stamina_regen_rate += additional_regen


func upgrade_cost_reduction(reduction_percent: float) -> void:
	"""Reduz o custo de estamina por dash (chamado por upgrades)"""
	stamina_cost *= (1.0 - reduction_percent)
	stamina_cost = maxf(stamina_cost, 10.0)  # Mínimo de 10 de custo


# === BACKWARD COMPATIBILITY ===
# Mantém compatibilidade com código antigo que esperava charges

func get_charges() -> int:
	"""DEPRECATED: Use get_dash_count() instead. Returns available dash count."""
	return get_dash_count()


func get_charge_progress(index: int) -> float:
	"""DEPRECATED: Returns fill percentage for a given 'charge slot'"""
	var dashes_available = current_stamina / stamina_cost
	if index < int(dashes_available):
		return 1.0
	elif index == int(dashes_available):
		# Carga parcial
		return fmod(dashes_available, 1.0)
	else:
		return 0.0
