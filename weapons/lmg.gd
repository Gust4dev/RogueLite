extends BaseWeapon

# LMG/Minigun - Suppressive Fire
# Spinup mechanic, overheat, movement slow
# Dano constante massivo quando aquecido
# Upgrade Interactions:
#   - Fast Reload: Reduz overheat cooldown
#   - Chain Lightning: Laser show

class_name LMG

# Tipo de arma para upgrade interactions
var weapon_type: String = "lmg"

# === SISTEMA DE SPINUP ===
@export_group("Spinup System")
@export var spinup_time: float = 0.5  # Tempo para começar a atirar
@export var spindown_time: float = 0.8  # Tempo para parar de girar

var is_spinning: bool = false
var spin_progress: float = 0.0  # 0.0 a 1.0
var is_trigger_held: bool = false

# === SISTEMA DE OVERHEAT ===
@export_group("Overheat System")
@export var max_heat: float = 100.0
@export var heat_per_shot: float = 2.0  # 50 tiros = 100 heat
@export var overheat_cooldown: float = 2.0  # Tempo para esfriar quando overheated
@export var heat_decay_rate: float = 25.0  # Heat perdido por segundo quando não atira
@export var heat_decay_delay: float = 0.3  # Delay antes de começar a esfriar

var current_heat: float = 0.0
var is_overheated: bool = false
var last_shot_time: float = 0.0
var overheat_timer: float = 0.0

# === SISTEMA DE MOVIMENTO ===
@export_group("Movement Penalty")
@export var firing_speed_multiplier: float = 0.4  # 40% da velocidade normal
@export var spinup_speed_multiplier: float = 0.7  # 70% durante spinup

var player_controller: Node = null

# Signals específicos do LMG
signal heat_changed(current: float, max_heat: float)
signal overheat_started()
signal overheat_ended()
signal spinup_started()
signal spinup_ready()
signal spindown_complete()


func _ready() -> void:
	# === STATS BÁSICOS ===
	# 12 dmg / 0.1s = 120 DPS (target)
	damage = 12.0
	fire_rate = 0.1  # Rápido quando spinning
	reload_time = 3.5  # Reload muito longo
	magazine_size = 100

	# === RECOIL DA ARMA (kickback visual) ===
	# LMG tem recoil constante mas controlável
	kickback_position = Vector3(0.0, 0.012, 0.04)  # Kickback moderado
	kickback_rotation = Vector3(-2.0, 1.2, 0.8)    # Rotação leve
	position_randomness = Vector3(0.004, 0.004, 0.006)
	rotation_randomness = Vector3(0.6, 0.8, 0.4)
	kickback_speed = 22.0   # Kickback rápido
	return_speed = 18.0     # Retorno rápido para próximo tiro
	shooting_return_speed = 12.0

	# === RECOIL DA CÂMERA ===
	camera_recoil_horizontal = 0.3   # Leve horizontal
	camera_recoil_vertical = 0.6     # Moderado vertical

	# === SWAY ===
	sway_enabled = true
	mouse_sway_amount = Vector2(0.0008, 0.0008)  # Pouco sway (arma pesada montada)
	mouse_sway_max = Vector2(0.02, 0.015)
	movement_sway_amount = 0.006  # Muito pouco movimento (arma pesada)

	# Nomes das animações
	anim_shoot = "Shoot"
	anim_reload = "Reload"
	anim_draw = "Draw"
	anim_idle = "Idle"

	# Velocidade das animações
	anim_speed_shoot = 4.0  # Animação muito rápida
	anim_speed_reload = 0.8  # Reload lento

	# Chama o _ready() do pai
	super._ready()

	# Toca animação inicial
	_play_initial_sequence()

	# Encontra player controller
	_find_player_controller()


func _play_initial_sequence() -> void:
	"""Toca Draw e depois vai para Idle"""
	if not animation_player:
		return

	if animation_player.has_animation(anim_draw):
		animation_player.play(anim_draw)
		await animation_player.animation_finished

	if animation_player.has_animation(anim_idle):
		animation_player.play(anim_idle)


func _find_player_controller() -> void:
	"""Encontra o player controller para aplicar slow"""
	await get_tree().process_frame
	var parent = get_parent()
	while parent:
		if parent.has_method("set_speed_multiplier"):
			player_controller = parent
			break
		parent = parent.get_parent()


func _process(delta: float) -> void:
	# Chama process do pai
	super._process(delta)

	# Atualiza spinup/spindown
	_update_spin(delta)

	# Atualiza heat
	_update_heat(delta)

	# Atualiza overheat cooldown
	_update_overheat(delta)

	# Atualiza movimento do player
	_update_movement_penalty()


func _update_spin(delta: float) -> void:
	"""Atualiza estado de spin do barril"""
	if is_trigger_held and not is_overheated:
		# Spinning up
		if spin_progress < 1.0:
			var old_progress = spin_progress
			spin_progress = min(spin_progress + delta / spinup_time, 1.0)

			if old_progress < 1.0 and spin_progress >= 1.0:
				is_spinning = true
				spinup_ready.emit()
	else:
		# Spinning down
		if spin_progress > 0.0:
			spin_progress = max(spin_progress - delta / spindown_time, 0.0)

			if spin_progress <= 0.0:
				is_spinning = false
				spindown_complete.emit()


func _update_heat(delta: float) -> void:
	"""Atualiza sistema de heat"""
	if is_overheated:
		return  # Heat não decai durante overheat cooldown

	# Decay heat quando não está atirando
	var time_since_shot = Time.get_ticks_msec() / 1000.0 - last_shot_time
	if time_since_shot > heat_decay_delay and current_heat > 0:
		current_heat = max(0, current_heat - heat_decay_rate * delta)
		heat_changed.emit(current_heat, max_heat)


func _update_overheat(delta: float) -> void:
	"""Atualiza cooldown de overheat"""
	if not is_overheated:
		return

	overheat_timer -= delta

	if overheat_timer <= 0:
		is_overheated = false
		current_heat = 0.0
		overheat_ended.emit()
		heat_changed.emit(current_heat, max_heat)


func _update_movement_penalty() -> void:
	"""Aplica penalidade de movimento durante uso"""
	if not player_controller:
		return

	if is_shooting and is_spinning:
		player_controller.set_speed_multiplier(firing_speed_multiplier)
	elif is_trigger_held and spin_progress > 0:
		player_controller.set_speed_multiplier(spinup_speed_multiplier)
	else:
		player_controller.set_speed_multiplier(1.0)


# === CONTROLES DE DISPARO ===

func start_firing() -> void:
	"""Começa a segurar o gatilho (inicia spinup)"""
	if is_overheated:
		return

	is_trigger_held = true

	if spin_progress <= 0:
		spinup_started.emit()


func stop_firing() -> void:
	"""Solta o gatilho"""
	is_trigger_held = false
	is_shooting = false

	if weapon_recoil:
		weapon_recoil.set_shooting_state(false)


# === OVERRIDE DO MÉTODO SHOOT ===

func shoot() -> void:
	"""Override: Só atira se estiver spinning e não overheated"""
	# Verifica condições especiais do LMG
	if not is_spinning or is_overheated:
		return

	# Verifica se pode atirar
	if not can_shoot or is_reloading:
		return

	# Verifica ammo
	if current_ammo <= 0:
		weapon_empty.emit()
		stop_firing()
		reload()
		return

	# Decrementa ammo
	current_ammo -= 1
	ammo_changed.emit(current_ammo, magazine_size)

	# Adiciona heat
	_add_heat()

	# Cooldown de disparo
	can_shoot = false
	fire_timer = fire_rate
	is_shooting = true
	last_shot_time = Time.get_ticks_msec() / 1000.0

	# Raycast para detectar hit
	_process_raycast()

	# Toca animação
	_play_animation(anim_shoot)

	# Muzzle flash
	_trigger_muzzle_flash()

	# Aplica recoil
	_apply_weapon_recoil()

	# Aplica recoil da câmera
	_apply_camera_recoil()

	# Efeitos visuais
	_apply_shooting_effects()

	# Emite signal
	weapon_fired.emit()


func _add_heat() -> void:
	"""Adiciona heat e verifica overheat"""
	current_heat = min(current_heat + heat_per_shot, max_heat)
	heat_changed.emit(current_heat, max_heat)

	if current_heat >= max_heat:
		_trigger_overheat()


func _trigger_overheat() -> void:
	"""Ativa estado de overheat"""
	is_overheated = true
	is_spinning = false
	spin_progress = 0.0
	overheat_timer = overheat_cooldown
	stop_firing()

	overheat_started.emit()

	# Visual feedback de overheat
	_play_overheat_effect()


func _play_overheat_effect() -> void:
	"""Efeito visual de overheat"""
	# Faz a arma tremer e brilhar vermelho
	var tween = create_tween()
	tween.set_loops(3)
	tween.tween_property(self, "position:x", position.x + 0.02, 0.1)
	tween.tween_property(self, "position:x", position.x - 0.02, 0.1)
	tween.tween_property(self, "position:x", position.x, 0.1)


# === LMG SPECIFIC METHODS ===

func get_weapon_type() -> String:
	"""Retorna o tipo de arma para upgrade interactions"""
	return weapon_type


func get_heat_percentage() -> float:
	"""Retorna porcentagem de heat (0.0 a 1.0)"""
	return current_heat / max_heat


func get_spin_percentage() -> float:
	"""Retorna porcentagem de spin (0.0 a 1.0)"""
	return spin_progress


func is_ready_to_fire() -> bool:
	"""Verifica se está pronto para atirar"""
	return is_spinning and not is_overheated and current_ammo > 0


func get_overheat_remaining() -> float:
	"""Retorna tempo restante de overheat"""
	return overheat_timer if is_overheated else 0.0


func reduce_overheat_cooldown(reduction: float) -> void:
	"""Reduz cooldown de overheat (para upgrade Fast Reload)"""
	overheat_cooldown = max(0.5, overheat_cooldown - reduction)


func set_overheat_cooldown(new_cooldown: float) -> void:
	"""Define cooldown de overheat diretamente"""
	overheat_cooldown = max(0.5, new_cooldown)


func force_cooldown() -> void:
	"""Força reset do overheat (para upgrades especiais)"""
	is_overheated = false
	current_heat = 0.0
	overheat_timer = 0.0
	heat_changed.emit(current_heat, max_heat)
	overheat_ended.emit()
