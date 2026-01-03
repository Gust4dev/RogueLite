extends BaseUpgrade

# Burst Fire - Múltiplos tiros por click
# Lvl 1: 3 tiros, spread pequeno
# Lvl 2: 4 tiros, spread reduzido
# Lvl 3: 5 tiros, zero spread
#
# === WEAPON INTERACTIONS ===
# Pistol: Normal behavior
# Revolver: Recoil MUITO alto até nível máximo (então quase zero)
# SMG: Disabled (já é full auto)
# Shotgun: Adiciona pellets extras ao invés de tiros extras
# Sniper: Delay maior entre bursts
# LMG: Disabled (já é full auto)

var burst_count: int = 3
var burst_spread: float = 0.05  # Radianos
var burst_delay: float = 0.05  # Segundos entre tiros do burst

var is_bursting: bool = false

# Multiplicadores por arma
var weapon_type: String = ""
var revolver_recoil_multiplier: float = 3.0  # Recoil 3x para revolver
var sniper_burst_delay: float = 0.15  # Delay maior para sniper


func _ready() -> void:
	upgrade_id = "burst_fire"
	upgrade_name = "Burst Fire"


func _apply_effects() -> void:
	"""Detecta tipo de arma quando upgrade é aplicado"""
	if weapon and weapon.has_method("get_weapon_type"):
		weapon_type = weapon.get_weapon_type()


func _on_level_changed() -> void:
	"""Atualiza stats baseado no nível e tipo de arma"""
	match level:
		1:
			burst_count = 3
			burst_spread = 0.05
		2:
			burst_count = 4
			burst_spread = 0.03
		3:
			burst_count = 5
			burst_spread = 0.0

	# Ajusta para revolver: recoil diminui com nível
	if weapon_type == "revolver":
		if level >= 3:
			revolver_recoil_multiplier = 0.1  # Praticamente zero no max
		elif level == 2:
			revolver_recoil_multiplier = 2.0
		else:
			revolver_recoil_multiplier = 3.0


func _connect_signals() -> void:
	"""Conecta ao signal de disparo da arma"""
	if weapon and weapon.has_signal("weapon_fired"):
		_safe_connect(weapon.weapon_fired, _on_weapon_fired)


func _on_weapon_fired() -> void:
	"""Quando a arma dispara, adiciona tiros extras"""
	if level <= 0:
		return

	if is_bursting:
		return

	# Verifica tipo de arma para comportamento especial
	if weapon_type == "smg" or weapon_type == "lmg":
		# SMG e LMG já são full auto, burst não faz sentido
		return

	if weapon_type == "shotgun":
		# Shotgun: adiciona pellets extras ao próximo tiro
		_add_shotgun_pellets()
		return

	# Dispara tiros adicionais (o primeiro já foi disparado pela arma)
	_fire_burst()


func _add_shotgun_pellets() -> void:
	"""Para shotgun: aumenta pellets temporariamente"""
	if not weapon or not weapon.has_method("get_pellet_count"):
		return

	# Aumenta pellets baseado no nível
	var extra_pellets = level + 1  # 2, 3, 4 pellets extras
	weapon.pellet_count += extra_pellets

	# Reseta após um frame
	await get_tree().process_frame
	weapon.pellet_count -= extra_pellets


func _fire_burst() -> void:
	"""Dispara os tiros adicionais do burst"""
	is_bursting = true

	# Já disparou 1 tiro, dispara os restantes
	var extra_shots = burst_count - 1

	# Delay ajustado por arma
	var delay = burst_delay
	if weapon_type == "sniper":
		delay = sniper_burst_delay  # Sniper tem delay maior

	for i in range(extra_shots):
		await get_tree().create_timer(delay).timeout

		if not is_instance_valid(weapon):
			break

		# Verifica se tem munição
		if weapon.current_ammo <= 0:
			break

		# Dispara tiro extra com spread
		_fire_extra_shot()

	is_bursting = false


func _fire_extra_shot() -> void:
	"""Dispara um tiro extra do burst"""
	if not weapon:
		return

	var raycast = weapon.get_node_or_null("RayCast3D")
	if not raycast:
		return

	# Salva direção original
	var original_target = raycast.target_position

	# Aplica spread aleatório
	if burst_spread > 0:
		var spread_x = randf_range(-burst_spread, burst_spread)
		var spread_y = randf_range(-burst_spread, burst_spread)
		raycast.target_position = original_target.rotated(Vector3.UP, spread_x)
		raycast.target_position = raycast.target_position.rotated(Vector3.RIGHT, spread_y)

	# Força update do raycast
	raycast.force_raycast_update()

	# Processa hit
	if raycast.is_colliding():
		var collider = raycast.get_collider()
		if collider and collider.has_method("take_damage"):
			var was_alive = true
			if collider.has_method("is_alive"):
				was_alive = collider.is_alive()

			collider.take_damage(weapon.damage)

			var is_kill = false
			if collider.has_method("is_alive"):
				is_kill = was_alive and not collider.is_alive()

			# Emite signal de hit
			if weapon.has_signal("hit_enemy"):
				weapon.hit_enemy.emit(collider, weapon.damage, is_kill)

	# Restaura direção original
	raycast.target_position = original_target

	# Consome munição
	weapon.current_ammo -= 1
	if weapon.has_signal("ammo_changed"):
		weapon.ammo_changed.emit(weapon.current_ammo, weapon.magazine_size)

	# Efeitos visuais com recoil ajustado por arma
	if weapon.has_method("_apply_weapon_recoil"):
		# Revolver: aplica recoil multiplicado (ou reduzido no max level)
		if weapon_type == "revolver" and weapon.has_node("WeaponRecoil"):
			var recoil = weapon.get_node("WeaponRecoil")
			var original_kick_rot = recoil.kickback_rotation
			recoil.kickback_rotation = original_kick_rot * revolver_recoil_multiplier
			weapon._apply_weapon_recoil()
			recoil.kickback_rotation = original_kick_rot
		else:
			weapon._apply_weapon_recoil()


func get_description_for_level(lvl: int) -> String:
	match lvl:
		1:
			return "Fire 3 shots per click (small spread)"
		2:
			return "Fire 4 shots per click (reduced spread)"
		3:
			return "Fire 5 shots per click (no spread)"
		_:
			return ""
