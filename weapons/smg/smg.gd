extends BaseWeapon

# SMG - Spray & Pray
# Full auto, dano baixo, alta cadência
# Spread aumenta com tiro contínuo
# Upgrade Interactions:
#   - Piercing: Spray atravessa grupos
#   - Chain Lightning: Cada tiro pode chain (chaos)

class_name SMG

# Tipo de arma para upgrade interactions
var weapon_type: String = "smg"

# === SISTEMA DE SPREAD DINÂMICO ===
@export_group("Spread System")
@export var base_spread: float = 0.01  # Spread base em radianos
@export var max_spread: float = 0.12   # Spread máximo
@export var spread_increase_per_shot: float = 0.008  # Aumento por tiro
@export var spread_recovery_rate: float = 0.15  # Recuperação por segundo
@export var spread_recovery_delay: float = 0.15  # Delay antes de recuperar

# Estado de spread
var current_spread: float = 0.0
var last_shot_time: float = 0.0
var continuous_shots: int = 0

# Recoil ascendente
var recoil_buildup: float = 0.0
var max_recoil_buildup: float = 3.0
var recoil_buildup_rate: float = 0.15
var recoil_decay_rate: float = 2.0

# Full auto
var is_trigger_held: bool = false


func _ready() -> void:
	# === STATS BÁSICOS ===
	# 7 dmg / 0.08s = ~87.5 DPS (target: 87)
	damage = 7.0
	fire_rate = 0.08  # Full auto muito rápido
	reload_time = 1.8
	magazine_size = 30

	# === RECOIL DA ARMA (kickback visual) ===
	# SMG tem recoil leve mas constante
	kickback_position = Vector3(0.0, 0.008, 0.03)  # Kickback pequeno
	kickback_rotation = Vector3(-1.5, 0.8, 0.5)    # Rotação leve
	position_randomness = Vector3(0.002, 0.002, 0.004)
	rotation_randomness = Vector3(0.3, 0.5, 0.3)
	kickback_speed = 25.0   # Kickback muito rápido
	return_speed = 20.0     # Retorno rápido para próximo tiro
	shooting_return_speed = 15.0

	# === RECOIL DA CÂMERA ===
	camera_recoil_horizontal = 0.2   # Leve
	camera_recoil_vertical = 0.5     # Principalmente vertical

	# === SWAY ===
	sway_enabled = true
	mouse_sway_amount = Vector2(0.002, 0.002)
	mouse_sway_max = Vector2(0.05, 0.035)
	movement_sway_amount = 0.018

	# Nomes das animações
	anim_shoot = "Shoot"
	anim_reload = "Reload"
	anim_draw = "Draw"
	anim_idle = "Idle"

	# Velocidade das animações
	anim_speed_shoot = 3.0  # Animação muito rápida
	anim_speed_reload = 1.3

	# Chama o _ready() do pai
	super._ready()

	# Toca animação inicial
	_play_initial_sequence()


func _play_initial_sequence() -> void:
	"""Toca Draw e depois vai para Idle"""
	if not animation_player:
		return

	if animation_player.has_animation(anim_draw):
		animation_player.play(anim_draw)
		await animation_player.animation_finished

	if animation_player.has_animation(anim_idle):
		animation_player.play(anim_idle)


func _process(delta: float) -> void:
	# Chama process do pai
	super._process(delta)

	# Recupera spread quando não está atirando
	var time_since_shot = Time.get_ticks_msec() / 1000.0 - last_shot_time
	if time_since_shot > spread_recovery_delay:
		current_spread = move_toward(current_spread, base_spread, spread_recovery_rate * delta)
		continuous_shots = max(0, continuous_shots - 1)

	# Decai recoil buildup
	if not is_shooting:
		recoil_buildup = move_toward(recoil_buildup, 0.0, recoil_decay_rate * delta)


# === OVERRIDE DO MÉTODO SHOOT ===

func shoot() -> void:
	"""Override: Dispara com spread dinâmico"""
	# Verifica se pode atirar
	if not can_shoot or is_reloading:
		return

	# Verifica ammo
	if current_ammo <= 0:
		weapon_empty.emit()
		reload()
		return

	# Decrementa ammo
	current_ammo -= 1
	ammo_changed.emit(current_ammo, magazine_size)

	# Cooldown de disparo
	can_shoot = false
	fire_timer = fire_rate
	is_shooting = true

	# Atualiza estado de spread
	_update_spread_state()

	# Raycast com spread aplicado
	_process_raycast_with_spread()

	# Toca animação
	_play_animation(anim_shoot)

	# Muzzle flash
	_trigger_muzzle_flash()

	# Aplica recoil da arma (com buildup)
	_apply_weapon_recoil_with_buildup()

	# Aplica recoil da câmera (com buildup)
	_apply_camera_recoil_with_buildup()

	# Efeitos visuais
	_apply_shooting_effects()

	# Emite signal
	weapon_fired.emit()


func _update_spread_state() -> void:
	"""Atualiza o estado de spread baseado no tiro contínuo"""
	last_shot_time = Time.get_ticks_msec() / 1000.0
	continuous_shots += 1

	# Aumenta spread
	current_spread = min(current_spread + spread_increase_per_shot, max_spread)

	# Aumenta recoil buildup
	recoil_buildup = min(recoil_buildup + recoil_buildup_rate, max_recoil_buildup)


func _process_raycast_with_spread() -> void:
	"""Processa raycast com spread aplicado"""
	if not raycast:
		return

	# Salva direção original
	var original_target = raycast.target_position

	# Aplica spread
	var total_spread = base_spread + current_spread
	var spread_x = randf_range(-total_spread, total_spread)
	var spread_y = randf_range(-total_spread, total_spread)

	raycast.target_position = original_target.rotated(Vector3.UP, spread_x)
	raycast.target_position = raycast.target_position.rotated(Vector3.RIGHT, spread_y)

	# Force update
	raycast.force_raycast_update()

	if raycast.is_colliding():
		var collider = raycast.get_collider()

		if collider.has_method("take_damage"):
			var was_alive = true
			if collider.has_method("is_alive"):
				was_alive = collider.is_alive()

			collider.take_damage(damage)

			var is_kill = false
			if collider.has_method("is_alive"):
				is_kill = was_alive and not collider.is_alive()

			hit_enemy.emit(collider, damage, is_kill)

			if camera_effects:
				camera_effects.on_hit(is_kill)

		var hit_point = raycast.get_collision_point()
		_spawn_impact_particles(hit_point)

	# Restaura direção original
	raycast.target_position = original_target


func _apply_weapon_recoil_with_buildup() -> void:
	"""Aplica recoil com buildup ascendente"""
	if weapon_recoil:
		weapon_recoil.set_shooting_state(true)

		# Modifica recoil baseado no buildup
		var buildup_factor = 1.0 + recoil_buildup * 0.5
		var original_kick_rot = weapon_recoil.kickback_rotation
		weapon_recoil.kickback_rotation = kickback_rotation * buildup_factor

		weapon_recoil.apply_recoil()

		# Restaura
		weapon_recoil.kickback_rotation = original_kick_rot


func _apply_camera_recoil_with_buildup() -> void:
	"""Aplica recoil da câmera com buildup ascendente"""
	if camera_effects:
		var buildup_factor = 1.0 + recoil_buildup * 0.3
		camera_effects.apply_camera_recoil(
			camera_recoil_horizontal * buildup_factor,
			camera_recoil_vertical * buildup_factor
		)
		camera_effects.shake_shoot()


# === SMG SPECIFIC METHODS ===

func get_weapon_type() -> String:
	"""Retorna o tipo de arma para upgrade interactions"""
	return weapon_type


func get_current_spread() -> float:
	"""Retorna o spread atual (para UI ou efeitos)"""
	return base_spread + current_spread


func get_spread_percentage() -> float:
	"""Retorna porcentagem do spread (0.0 a 1.0)"""
	return current_spread / max_spread


func reset_spread() -> void:
	"""Reseta spread para o base (chamado ao parar de atirar)"""
	current_spread = 0.0
	continuous_shots = 0
	recoil_buildup = 0.0


# === FULL AUTO SUPPORT ===

func start_auto_fire() -> void:
	"""Inicia disparo automático (segurar mouse)"""
	is_trigger_held = true


func stop_auto_fire() -> void:
	"""Para disparo automático"""
	is_trigger_held = false
	is_shooting = false
	if weapon_recoil:
		weapon_recoil.set_shooting_state(false)
