extends Node

# Meta Progression Manager - Sistema de progressão permanente entre runs
# Gerencia currency, upgrades permanentes, stats e unlocks

class_name MetaProgressionManager

# Signals
signal meta_currency_changed(amount: int)
signal permanent_upgrade_purchased(upgrade_id: String)
signal stats_updated()

# === SAVE FILE ===
const SAVE_FILE = "user://meta_progression.save"

# === META CURRENCY ===
# "Souls" ou "Essence" coletados durante runs
var meta_currency: int = 0

# === PERMANENT UPGRADES ===
# Cada upgrade tem níveis (0-4)
var permanent_upgrades: Dictionary = {
	"damage_bonus": 0,      # +5% damage per level (max 20%)
	"hp_bonus": 0,          # +10% HP per level (max 40%)
	"speed_bonus": 0,       # +5% speed per level (max 20%)
	"xp_bonus": 0,          # +10% XP per level (max 40%)
	"starting_money": 0,    # +50 starting money per level (max 200)
	"starting_upgrade": 0,  # Start with 1 random upgrade (1 level only)
}

# Custo dos upgrades (por nível)
const UPGRADE_COSTS: Dictionary = {
	"damage_bonus": [100, 250, 500, 1000],
	"hp_bonus": [100, 250, 500, 1000],
	"speed_bonus": [100, 250, 500, 1000],
	"xp_bonus": [75, 200, 400, 800],
	"starting_money": [50, 150, 350, 700],
	"starting_upgrade": [500],  # Só tem 1 nível
}

# Max level por upgrade
const MAX_LEVELS: Dictionary = {
	"damage_bonus": 4,
	"hp_bonus": 4,
	"speed_bonus": 4,
	"xp_bonus": 4,
	"starting_money": 4,
	"starting_upgrade": 1,
}

# === RUN STATS ===
# Stats da run atual (resetam a cada run)
var current_run_stats: Dictionary = {
	"enemies_killed": 0,
	"bosses_killed": 0,
	"damage_dealt": 0,
	"damage_taken": 0,
	"upgrades_collected": 0,
	"money_collected": 0,
	"xp_collected": 0,
	"time_survived": 0,
	"run_won": false,
}

# === LIFETIME STATS ===
# Stats permanentes (persistem entre runs)
var lifetime_stats: Dictionary = {
	"total_runs": 0,
	"total_wins": 0,
	"total_deaths": 0,
	"total_enemies_killed": 0,
	"total_bosses_killed": 0,
	"total_damage_dealt": 0,
	"total_damage_taken": 0,
	"total_money_collected": 0,
	"total_xp_collected": 0,
	"total_time_played": 0,
	"highest_kill_streak": 0,
	"fastest_boss_kill": 999999.0,
	"longest_run": 0,
}

# === ACHIEVEMENTS ===
var achievements: Dictionary = {
	"first_win": false,
	"kill_100_enemies": false,
	"kill_1000_enemies": false,
	"kill_all_bosses": false,
	"no_damage_boss": false,
	"speedrun_5min": false,
	"max_upgrades": false,
}


func _ready() -> void:
	load_data()


# === CURRENCY FUNCTIONS ===

func add_meta_currency(amount: int) -> void:
	"""Adiciona currency meta (obtido ao fim de uma run)"""
	meta_currency += amount
	meta_currency_changed.emit(meta_currency)
	save_data()


func spend_meta_currency(amount: int) -> bool:
	"""Gasta currency meta, retorna true se bem sucedido"""
	if meta_currency >= amount:
		meta_currency -= amount
		meta_currency_changed.emit(meta_currency)
		save_data()
		return true
	return false


func get_meta_currency() -> int:
	return meta_currency


# === PERMANENT UPGRADES ===

func get_upgrade_level(upgrade_id: String) -> int:
	"""Retorna nível atual de um upgrade"""
	return permanent_upgrades.get(upgrade_id, 0)


func get_upgrade_cost(upgrade_id: String) -> int:
	"""Retorna custo do próximo nível do upgrade"""
	var current_level = get_upgrade_level(upgrade_id)
	var costs = UPGRADE_COSTS.get(upgrade_id, [])

	if current_level >= costs.size():
		return -1  # Já no max
	return costs[current_level]


func can_purchase_upgrade(upgrade_id: String) -> bool:
	"""Verifica se pode comprar o upgrade"""
	var cost = get_upgrade_cost(upgrade_id)
	if cost < 0:
		return false  # Já no max
	return meta_currency >= cost


func purchase_upgrade(upgrade_id: String) -> bool:
	"""Compra um nível do upgrade"""
	if not can_purchase_upgrade(upgrade_id):
		return false

	var cost = get_upgrade_cost(upgrade_id)
	if spend_meta_currency(cost):
		permanent_upgrades[upgrade_id] += 1
		permanent_upgrade_purchased.emit(upgrade_id)
		save_data()
		return true
	return false


func get_upgrade_effect(upgrade_id: String) -> float:
	"""Retorna o efeito atual do upgrade"""
	var level = get_upgrade_level(upgrade_id)
	match upgrade_id:
		"damage_bonus":
			return level * 0.05  # 5% por nível
		"hp_bonus":
			return level * 0.10  # 10% por nível
		"speed_bonus":
			return level * 0.05  # 5% por nível
		"xp_bonus":
			return level * 0.10  # 10% por nível
		"starting_money":
			return level * 50.0  # 50 por nível
		"starting_upgrade":
			return float(level)  # 0 ou 1
	return 0.0


# === STAT TRACKING ===

func start_run() -> void:
	"""Inicia uma nova run - reseta stats da run atual"""
	current_run_stats = {
		"enemies_killed": 0,
		"bosses_killed": 0,
		"damage_dealt": 0,
		"damage_taken": 0,
		"upgrades_collected": 0,
		"money_collected": 0,
		"xp_collected": 0,
		"time_survived": 0,
		"run_won": false,
	}
	lifetime_stats["total_runs"] += 1
	save_data()


func end_run(won: bool = false) -> int:
	"""Finaliza a run e calcula meta currency ganho"""
	current_run_stats["run_won"] = won

	# Atualiza lifetime stats
	lifetime_stats["total_enemies_killed"] += current_run_stats["enemies_killed"]
	lifetime_stats["total_bosses_killed"] += current_run_stats["bosses_killed"]
	lifetime_stats["total_damage_dealt"] += current_run_stats["damage_dealt"]
	lifetime_stats["total_damage_taken"] += current_run_stats["damage_taken"]
	lifetime_stats["total_money_collected"] += current_run_stats["money_collected"]
	lifetime_stats["total_xp_collected"] += current_run_stats["xp_collected"]
	lifetime_stats["total_time_played"] += current_run_stats["time_survived"]

	if won:
		lifetime_stats["total_wins"] += 1
	else:
		lifetime_stats["total_deaths"] += 1

	# Verifica recordes
	if current_run_stats["time_survived"] > lifetime_stats["longest_run"]:
		lifetime_stats["longest_run"] = current_run_stats["time_survived"]

	# Calcula meta currency ganho
	var currency_earned = _calculate_run_currency()
	add_meta_currency(currency_earned)

	# Verifica achievements
	_check_achievements()

	save_data()
	stats_updated.emit()

	return currency_earned


func _calculate_run_currency() -> int:
	"""Calcula quanto meta currency a run rendeu"""
	var currency = 0

	# Base por enemies
	currency += current_run_stats["enemies_killed"] * 1

	# Bonus por bosses
	currency += current_run_stats["bosses_killed"] * 25

	# Bonus por win
	if current_run_stats["run_won"]:
		currency += 100

	# Bonus por tempo sobrevivido (1 por 30 segundos)
	currency += int(current_run_stats["time_survived"] / 30)

	return currency


# === STAT TRACKING HELPERS ===

func track_enemy_killed() -> void:
	current_run_stats["enemies_killed"] += 1


func track_boss_killed() -> void:
	current_run_stats["bosses_killed"] += 1


func track_damage_dealt(amount: float) -> void:
	current_run_stats["damage_dealt"] += int(amount)


func track_damage_taken(amount: float) -> void:
	current_run_stats["damage_taken"] += int(amount)


func track_upgrade_collected() -> void:
	current_run_stats["upgrades_collected"] += 1


func track_money_collected(amount: int) -> void:
	current_run_stats["money_collected"] += amount


func track_xp_collected(amount: int) -> void:
	current_run_stats["xp_collected"] += amount


func track_time(seconds: int) -> void:
	current_run_stats["time_survived"] = seconds


# === ACHIEVEMENTS ===

func _check_achievements() -> void:
	"""Verifica e desbloqueia achievements"""
	if current_run_stats["run_won"] and not achievements["first_win"]:
		achievements["first_win"] = true

	if lifetime_stats["total_enemies_killed"] >= 100:
		achievements["kill_100_enemies"] = true

	if lifetime_stats["total_enemies_killed"] >= 1000:
		achievements["kill_1000_enemies"] = true

	if current_run_stats["bosses_killed"] >= 4:
		achievements["kill_all_bosses"] = true


func has_achievement(achievement_id: String) -> bool:
	return achievements.get(achievement_id, false)


# === SAVE/LOAD ===

func save_data() -> void:
	"""Salva dados de meta progression"""
	var save_data = {
		"meta_currency": meta_currency,
		"permanent_upgrades": permanent_upgrades,
		"lifetime_stats": lifetime_stats,
		"achievements": achievements,
	}

	var file = FileAccess.open(SAVE_FILE, FileAccess.WRITE)
	if file:
		file.store_var(save_data)
		file.close()


func load_data() -> void:
	"""Carrega dados de meta progression"""
	if not FileAccess.file_exists(SAVE_FILE):
		return

	var file = FileAccess.open(SAVE_FILE, FileAccess.READ)
	if file:
		var data = file.get_var()
		file.close()

		if data is Dictionary:
			meta_currency = data.get("meta_currency", 0)
			permanent_upgrades = data.get("permanent_upgrades", permanent_upgrades)
			lifetime_stats = data.get("lifetime_stats", lifetime_stats)
			achievements = data.get("achievements", achievements)


func reset_all_data() -> void:
	"""Reseta todos os dados de meta progression (cuidado!)"""
	meta_currency = 0
	permanent_upgrades = {
		"damage_bonus": 0,
		"hp_bonus": 0,
		"speed_bonus": 0,
		"xp_bonus": 0,
		"starting_money": 0,
		"starting_upgrade": 0,
	}
	lifetime_stats = {
		"total_runs": 0,
		"total_wins": 0,
		"total_deaths": 0,
		"total_enemies_killed": 0,
		"total_bosses_killed": 0,
		"total_damage_dealt": 0,
		"total_damage_taken": 0,
		"total_money_collected": 0,
		"total_xp_collected": 0,
		"total_time_played": 0,
		"highest_kill_streak": 0,
		"fastest_boss_kill": 999999.0,
		"longest_run": 0,
	}
	achievements = {
		"first_win": false,
		"kill_100_enemies": false,
		"kill_1000_enemies": false,
		"kill_all_bosses": false,
		"no_damage_boss": false,
		"speedrun_5min": false,
		"max_upgrades": false,
	}
	save_data()


# === UPGRADE INFO FOR UI ===

func get_upgrade_info(upgrade_id: String) -> Dictionary:
	"""Retorna informações do upgrade para UI"""
	return {
		"id": upgrade_id,
		"name": _get_upgrade_name(upgrade_id),
		"description": _get_upgrade_description(upgrade_id),
		"current_level": get_upgrade_level(upgrade_id),
		"max_level": MAX_LEVELS.get(upgrade_id, 0),
		"cost": get_upgrade_cost(upgrade_id),
		"effect": get_upgrade_effect(upgrade_id),
		"can_purchase": can_purchase_upgrade(upgrade_id),
	}


func _get_upgrade_name(upgrade_id: String) -> String:
	match upgrade_id:
		"damage_bonus": return "Força"
		"hp_bonus": return "Vitalidade"
		"speed_bonus": return "Agilidade"
		"xp_bonus": return "Sabedoria"
		"starting_money": return "Herança"
		"starting_upgrade": return "Treinamento"
	return "Desconhecido"


func _get_upgrade_description(upgrade_id: String) -> String:
	match upgrade_id:
		"damage_bonus": return "+5% dano por nível"
		"hp_bonus": return "+10% HP por nível"
		"speed_bonus": return "+5% velocidade por nível"
		"xp_bonus": return "+10% XP por nível"
		"starting_money": return "+50 dinheiro inicial por nível"
		"starting_upgrade": return "Começa com 1 upgrade aleatório"
	return ""


func get_all_upgrades() -> Array:
	"""Retorna lista de todos os upgrades disponíveis"""
	var upgrades = []
	for upgrade_id in permanent_upgrades.keys():
		upgrades.append(get_upgrade_info(upgrade_id))
	return upgrades
