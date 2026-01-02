extends Node

# XP Manager - Singleton que gerencia XP, níveis e upgrades obtidos
# Autoload global para sistema de progressão

class_name XPManagerClass

# === SIGNALS ===
signal xp_gained(amount: int, total: int)
signal xp_changed(current: int, required: int)
signal level_up(new_level: int)

# === ESTADO ===
var current_xp: int = 0
var current_level: int = 1
var total_xp: int = 0

# Multiplicador de XP (pode ser aumentado por upgrades)
var xp_multiplier: float = 1.0

# === CONFIGURAÇÃO ===
const BASE_XP: int = 100            # XP para level 2
const XP_GROWTH_RATE: float = 1.3   # Multiplicador por level

# Pool de upgrades de boss já obtidos pelo jogador
var acquired_boss_upgrades: Array[String] = []


func _ready() -> void:
	reset()


func get_xp_for_level(level: int) -> int:
	"""Retorna o XP necessário para atingir um level"""
	return int(BASE_XP * pow(XP_GROWTH_RATE, level - 1))


func get_xp_to_next_level() -> int:
	"""Retorna XP restante para próximo level"""
	return get_xp_for_level(current_level) - current_xp


func get_xp_progress() -> float:
	"""Retorna progresso do XP atual como porcentagem (0.0 a 1.0)"""
	var required = get_xp_for_level(current_level)
	return float(current_xp) / float(required) if required > 0 else 0.0


func add_xp(amount: int) -> void:
	"""Adiciona XP e verifica level up"""
	# Aplica multiplicador
	var actual_amount = int(amount * xp_multiplier)
	
	current_xp += actual_amount
	total_xp += actual_amount
	xp_gained.emit(actual_amount, total_xp)
	
	var required = get_xp_for_level(current_level)
	while current_xp >= required:
		current_xp -= required
		current_level += 1
		level_up.emit(current_level)
		required = get_xp_for_level(current_level)
	
	xp_changed.emit(current_xp, get_xp_for_level(current_level))


func register_boss_upgrade(upgrade_id: String) -> void:
	"""Registra upgrade de boss obtido para aparecer no level up"""
	if upgrade_id not in acquired_boss_upgrades:
		acquired_boss_upgrades.append(upgrade_id)
		print("[XPManager] Boss upgrade registrado: ", upgrade_id)


func get_acquired_boss_upgrades() -> Array[String]:
	"""Retorna lista de upgrades de boss obtidos"""
	return acquired_boss_upgrades


func has_boss_upgrade(upgrade_id: String) -> bool:
	"""Verifica se um upgrade de boss específico foi obtido"""
	return upgrade_id in acquired_boss_upgrades


func reset() -> void:
	"""Reseta todo o progresso de XP"""
	current_xp = 0
	current_level = 1
	total_xp = 0
	xp_multiplier = 1.0
	acquired_boss_upgrades.clear()
	xp_changed.emit(0, get_xp_for_level(1))


func get_stats() -> Dictionary:
	"""Retorna estatísticas de XP para debug/UI"""
	return {
		"level": current_level,
		"current_xp": current_xp,
		"required_xp": get_xp_for_level(current_level),
		"total_xp": total_xp,
		"xp_multiplier": xp_multiplier,
		"boss_upgrades": acquired_boss_upgrades.size()
	}
