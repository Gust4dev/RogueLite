extends BaseUpgrade

# Fast Reload - Reduz tempo de reload
# Lvl 1: -25% reload time
# Lvl 2: -50% reload time
# Lvl 3: -75% reload time + auto reload

var reload_reduction: float = 0.25
var auto_reload: bool = false
var original_reload_time: float = 0.0


func _ready() -> void:
	upgrade_id = "fast_reload"
	upgrade_name = "Fast Reload"


func _on_level_changed() -> void:
	"""Atualiza stats baseado no nível"""
	match level:
		1:
			reload_reduction = 0.25
			auto_reload = false
		2:
			reload_reduction = 0.50
			auto_reload = false
		3:
			reload_reduction = 0.75
			auto_reload = true


func _apply_effects() -> void:
	"""Aplica redução de reload à arma"""
	if not weapon:
		return

	# Salva tempo original
	if original_reload_time == 0.0:
		original_reload_time = weapon.reload_time

	# Aplica redução
	weapon.reload_time = original_reload_time * (1.0 - reload_reduction)


func _remove_effects() -> void:
	"""Remove efeitos e restaura valores originais"""
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


func _on_ammo_changed(current: int, mag_size: int, reserve: int) -> void:
	"""Monitora munição para auto reload"""
	if auto_reload and level >= 3:
		if current == 0 and reserve > 0:
			# Inicia reload automaticamente
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
