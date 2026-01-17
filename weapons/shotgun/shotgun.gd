extends BaseWeapon

# Shotgun - Close Range Burst
# 8 pellets por tiro, dano alto de perto
# Spread amplo, efetivo a curta distância
# Upgrade Interactions:
#   - Explosive: Cada pellet explode
#   - Ricochet: Pellets rebatem (loucura)
#   - Sawed Off (Item especial): Aumenta dano e spread

class_name Shotgun

# Tipo de arma para upgrade interactions
var weapon_type: String = "shotgun"

# === SISTEMA DE PELLETS ===
@export_group("Pellet System")
@export var pellet_count: int = 8
@export var damage_per_pellet: float = 8.0
@export var pellet_spread: float = 0.12  # Spread base em radianos
@export var effective_range: float = 10.0  # Metros
@export var damage_falloff_start: float = 5.0  # Começa falloff
@export var damage_falloff_end: float = 15.0  # Dano mínimo

# Sawed Off mode (item especial)
var is_sawed_off: bool = false
var sawed_off_damage_bonus: float = 1.25  # +25% dano
var sawed_off_spread_bonus: float = 1.4   # +40% spread

# Pump action
var is_pumping: bool = false
var pump_time: float = 0.4  # Tempo da animação de pump


func _ready() -> void:
	# === STATS BÁSICOS ===
	# 8 pellets * 8 dmg = 64 / 0.8s = 80 DPS (target)
	damage = damage_per_pellet  # Dano por pellet
	fire_rate = 0.8  # Pump action
	reload_time = 2.2  # Reload mais longo
	magazine_size = 6

	# === RECOIL DA ARMA (kickback visual) ===
	# Shotgun tem recoil MUITO forte
	kickback_position = Vector3(0.0, 0.06, 0.18)  # Grande kickback
	kickback_rotation = Vector3(-12.0, 3.0, 4.0)   # Rotação pesada
	position_randomness = Vector3(0.01, 0.01, 0.02)
	rotation_randomness = Vector3(2.0, 2.5, 1.5)
	kickback_speed = 22.0   # Kickback rápido
	return_speed = 5.0      # Retorno lento (pump action)
	shooting_return_speed = 3.0

	# === RECOIL DA CÂMERA ===
	camera_recoil_horizontal = 1.0   # Kick horizontal
	camera_recoil_vertical = 3.5     # Punch vertical massivo

	# === SWAY ===
	sway_enabled = true
	mouse_sway_amount = Vector2(0.0012, 0.0012)  # Menos sway (arma pesada)
	mouse_sway_max = Vector2(0.03, 0.02)
	movement_sway_amount = 0.01

	# Nomes das animações
	# Nomes das animações - UPDATED FOR NEW MODEL
	anim_shoot = "Armature|Shoot" # Assumindo mesmo padrão
	anim_reload = "Armature|Reload"
	anim_draw = "Armature|Take"
	anim_idle = ""

	# Velocidade das animações
	anim_speed_shoot = 1.2  # Animação mais lenta (pump)
	anim_speed_reload = 1.0

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


# === OVERRIDE DO MÉTODO SHOOT ===

func shoot() -> void:
	"""Override: Dispara múltiplos pellets"""
	# Verifica se pode atirar
	if not can_shoot or is_reloading or is_pumping:
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

	# Dispara todos os pellets
	var total_damage = _fire_pellets()

	# Toca animação
	_play_animation(anim_shoot)

	# Muzzle flash (mais intenso)
	_trigger_shotgun_muzzle_flash()

	# Aplica recoil
	_apply_weapon_recoil()

	# Aplica recoil da câmera
	_apply_camera_recoil()

	# Efeitos visuais
	_apply_shooting_effects()

	# Emite signal (com dano total para upgrades)
	weapon_fired.emit()

	# Inicia pump action
	_do_pump_action()


func _fire_pellets() -> float:
	"""Dispara todos os pellets e retorna dano total causado"""
	if not raycast:
		return 0.0

	var total_damage: float = 0.0
	var original_target = raycast.target_position

	# Calcula spread atual
	var current_spread = pellet_spread
	if is_sawed_off:
		current_spread *= sawed_off_spread_bonus

	# Dispara cada pellet
	for i in range(pellet_count):
		# Aplica spread ao pellet
		var spread_x = randf_range(-current_spread, current_spread)
		var spread_y = randf_range(-current_spread, current_spread)

		# Adiciona um pouco de pattern circular
		var angle = randf() * TAU
		var radius = randf() * current_spread
		spread_x = cos(angle) * radius
		spread_y = sin(angle) * radius

		raycast.target_position = original_target.rotated(Vector3.UP, spread_x)
		raycast.target_position = raycast.target_position.rotated(Vector3.RIGHT, spread_y)

		# Force update
		raycast.force_raycast_update()

		if raycast.is_colliding():
			var collider = raycast.get_collider()
			var hit_point = raycast.get_collision_point()

			# Calcula dano com falloff
			var pellet_damage = _calculate_pellet_damage(hit_point)

			if collider.has_method("take_damage"):
				var was_alive = true
				if collider.has_method("is_alive"):
					was_alive = collider.is_alive()

				collider.take_damage(pellet_damage)
				total_damage += pellet_damage

				var is_kill = false
				if collider.has_method("is_alive"):
					is_kill = was_alive and not collider.is_alive()

				# Emite hit para cada pellet (importante para upgrades)
				hit_enemy.emit(collider, pellet_damage, is_kill)

				if camera_effects and is_kill:
					camera_effects.on_hit(true)

			# Spawn impact particles
			_spawn_impact_particles(hit_point)

	# Restaura direção original
	raycast.target_position = original_target

	return total_damage


func _calculate_pellet_damage(hit_point: Vector3) -> float:
	"""Calcula dano do pellet com falloff baseado na distância"""
	var distance = global_position.distance_to(hit_point)
	var pellet_dmg = damage_per_pellet

	if is_sawed_off:
		pellet_dmg *= sawed_off_damage_bonus

	# Falloff de distância
	if distance <= damage_falloff_start:
		return pellet_dmg  # Dano total
	elif distance >= damage_falloff_end:
		return pellet_dmg * 0.3  # Dano mínimo (30%)
	else:
		# Interpolação linear
		var falloff_range = damage_falloff_end - damage_falloff_start
		var distance_into_falloff = distance - damage_falloff_start
		var falloff_factor = 1.0 - (distance_into_falloff / falloff_range) * 0.7
		return pellet_dmg * falloff_factor


func _trigger_shotgun_muzzle_flash() -> void:
	"""Muzzle flash mais intenso para shotgun"""
	if muzzle_flash:
		if muzzle_flash.has_method("trigger"):
			muzzle_flash.trigger()
		else:
			muzzle_flash.visible = true

			for child in muzzle_flash.get_children():
				if child is GPUParticles3D:
					child.amount = 16  # Mais partículas
					child.restart()
					child.emitting = true

			await get_tree().create_timer(0.15).timeout
			if muzzle_flash:
				muzzle_flash.visible = false


func _do_pump_action() -> void:
	"""Executa animação de pump action após o tiro"""
	is_pumping = true

	# Anima o pump visualmente
	var tween = create_tween()
	tween.tween_property(self, "position:z", position.z + 0.05, pump_time * 0.4)
	tween.tween_property(self, "position:z", position.z, pump_time * 0.6)

	await get_tree().create_timer(pump_time).timeout
	is_pumping = false


# === SHOTGUN SPECIFIC METHODS ===

func get_weapon_type() -> String:
	"""Retorna o tipo de arma para upgrade interactions"""
	return weapon_type


func get_pellet_count() -> int:
	"""Retorna número de pellets"""
	return pellet_count


func enable_sawed_off() -> void:
	"""Ativa modo Sawed Off (item especial)"""
	is_sawed_off = true
	# Aumenta spread visual
	pellet_spread *= sawed_off_spread_bonus * 0.5  # Já vai multiplicar de novo no tiro


func disable_sawed_off() -> void:
	"""Desativa modo Sawed Off"""
	is_sawed_off = false
	pellet_spread = 0.12  # Reset para valor original


func get_effective_range() -> float:
	"""Retorna range efetivo"""
	return effective_range


func is_in_effective_range(target_position: Vector3) -> bool:
	"""Verifica se alvo está no range efetivo"""
	return global_position.distance_to(target_position) <= effective_range
