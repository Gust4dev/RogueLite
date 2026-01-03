extends BaseUpgrade

# Fast Reload - Reduz tempo de reload
# Lvl 1: -25% reload time
# Lvl 2: -50% reload time
# Lvl 3: -75% reload time + auto reload
#
# === WEAPON INTERACTIONS ===
# Pistol: Normal behavior
# Revolver: Instant reload no nível máximo
# SMG: Normal
# Shotgun: Normal
# Sniper: Normal
# LMG: Reduz overheat cooldown ao invés de reload time

var reload_reduction: float = 0.25
var auto_reload: bool = false
var original_reload_time: float = 0.0

# LMG specific
var original_overheat_cooldown: float = 0.0
var overheat_reduction: float = 0.25

# Weapon type
var weapon_type: String = ""


func _ready() -> void:
	upgrade_id = "fast_reload"
	upgrade_name = "Fast Reload"


func _on_level_changed() -> void:
	"""Atualiza stats baseado no nível"""
	match level:
		1:
			reload_reduction = 0.25
			overheat_reduction = 0.25
			auto_reload = false
		2:
			reload_reduction = 0.50
			overheat_reduction = 0.50
			auto_reload = false
		3:
			reload_reduction = 0.75
			overheat_reduction = 0.75
			auto_reload = true

	# Reaplicar efeitos com novo nível
	_apply_effects()


func _apply_effects() -> void:
	"""Aplica redução de reload à arma (ou overheat para LMG)"""
	if not weapon:
		return

	# Detecta tipo de arma
	if weapon.has_method("get_weapon_type"):
		weapon_type = weapon.get_weapon_type()

	# LMG: reduz overheat cooldown ao invés de reload
	if weapon_type == "lmg":
		_apply_lmg_effects()
		return

	# Revolver: instant reload no max level
	if weapon_type == "revolver" and level >= 3:
		weapon.reload_time = 0.1  # Praticamente instantâneo
		return

	# Armas normais: reduz reload time
	if original_reload_time == 0.0:
		original_reload_time = weapon.reload_time

	weapon.reload_time = original_reload_time * (1.0 - reload_reduction)


func _apply_lmg_effects() -> void:
	"""Aplica efeitos específicos para LMG"""
	if not weapon:
		return

	# Salva cooldown original
	if original_overheat_cooldown == 0.0:
		original_overheat_cooldown = weapon.overheat_cooldown

	# Aplica redução de overheat cooldown
	var new_cooldown = original_overheat_cooldown * (1.0 - overheat_reduction)
	weapon.set_overheat_cooldown(new_cooldown)

	# Level 3: auto-reset de overheat
	if level >= 3 and not weapon.overheat_ended.is_connected(_on_lmg_overheat_ended):
		weapon.overheat_ended.connect(_on_lmg_overheat_ended)


func _on_lmg_overheat_ended() -> void:
	"""Callback quando LMG termina overheat - reload automático"""
	if weapon and weapon.has_method("force_cooldown"):
		# Pequeno delay antes de permitir atirar novamente
		await get_tree().create_timer(0.2).timeout
		# Já esfriou, não precisa fazer nada extra


func _remove_effects() -> void:
	"""Remove efeitos e restaura valores originais"""
	if weapon_type == "lmg":
		if weapon and original_overheat_cooldown > 0:
			weapon.set_overheat_cooldown(original_overheat_cooldown)
		if weapon and weapon.overheat_ended.is_connected(_on_lmg_overheat_ended):
			weapon.overheat_ended.disconnect(_on_lmg_overheat_ended)
	else:
		if weapon and original_reload_time > 0:
			weapon.reload_time = original_reload_time


func _connect_signals() -> void:
	"""Conecta signals para auto reload"""
	if weapon:
		if weapon.has_signal("weapon_empty"):
			_safe_connect(weapon.weapon_empty, _on_weapon_empty)

		if weapon.has_signal("ammo_changed"):
			_safe_connect(weapon.ammo_changed, _on_ammo_changed)


func _on_weapon_empty() -> void:
	"""Auto reload quando a arma fica vazia (nível 3)"""
	if auto_reload and level >= 3:
		# Pequeno delay antes do auto reload
		await get_tree().create_timer(0.1).timeout
		if weapon and weapon.has_method("reload"):
			weapon.reload()


func _on_ammo_changed(current: int, mag_size: int) -> void:
	"""Monitora munição para auto reload (reload infinito)"""
	if auto_reload and level >= 3:
		if current == 0:
			# Inicia reload automaticamente (reload agora é sempre infinito)
			if weapon and not weapon.is_reloading:
				await get_tree().create_timer(0.1).timeout
				if weapon and weapon.has_method("reload"):
					weapon.reload()


func get_description_for_level(lvl: int) -> String:
	match lvl:
		1:
			return "-25% reload time"
		2:
			return "-50% reload time"
		3:
			return "-75% reload time + auto reload"
		_:
			return ""
