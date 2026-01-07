extends Node

# Character Manager - Gerencia personagens e suas armas
# Cada personagem está linked a uma arma específica
# Sistema de unlock baseado em achievements

signal character_selected(character_id: String)
signal character_unlocked(character_id: String)

# Dados de personagens
var characters: Dictionary = {}

# Personagem atualmente selecionado
var selected_character_id: String = "soldier"

# Persistência
const SAVE_PATH = "user://character_data.save"


func _ready() -> void:
	_init_characters()
	_load_data()


func _init_characters() -> void:
	"""Inicializa dados de todos os personagens"""

	# 1. Soldier - Pistol (desbloqueado)
	characters["soldier"] = {
		"id": "soldier",
		"name": "Soldier",
		"description": "Balanced fighter with reliable pistol.",
		"weapon_scene": "res://weapons/pistol/pistol.tscn",
		"weapon_name": "Pistol",
		"stats": {
			"damage": 15,
			"fire_rate": 0.25,
			"magazine": 12,
			"dps": 60
		},
		"unlocked": true,
		"unlock_condition": "Starting character",
		"portrait_color": Color(0.2, 0.5, 0.8),  # Azul
		"special_ability": "None"
	}

	# 2. Gunslinger - Revolver (desbloqueado)
	characters["gunslinger"] = {
		"id": "gunslinger",
		"name": "Gunslinger",
		"description": "High damage, slow shots. Precision is key.",
		"weapon_scene": "res://weapons/revolver/revolver.tscn",
		"weapon_name": "Revolver",
		"stats": {
			"damage": 40,
			"fire_rate": 0.6,
			"magazine": 8,
			"dps": 66
		},
		"unlocked": true,
		"unlock_condition": "Starting character",
		"portrait_color": Color(0.6, 0.3, 0.1),  # Marrom
		"special_ability": "Critical hits deal 2.5x damage"
	}

	# 3. Commando - SMG (desbloqueado)
	characters["commando"] = {
		"id": "commando",
		"name": "Commando",
		"description": "Spray and pray! High rate of fire, lower damage.",
		"weapon_scene": "res://weapons/smg/smg.tscn",
		"weapon_name": "SMG",
		"stats": {
			"damage": 7,
			"fire_rate": 0.08,
			"magazine": 30,
			"dps": 87
		},
		"unlocked": true,
		"unlock_condition": "Starting character",
		"portrait_color": Color(0.3, 0.6, 0.3),  # Verde
		"special_ability": "Spread decreases as you fire"
	}

	# 4. Hunter - Shotgun (unlock: kill 100 enemies)
	characters["hunter"] = {
		"id": "hunter",
		"name": "Hunter",
		"description": "Devastating at close range. 8 pellets per shot.",
		"weapon_scene": "res://weapons/shotgun/shotgun.tscn",
		"weapon_name": "Shotgun",
		"stats": {
			"damage": 64,  # 8 pellets x 8 dmg
			"fire_rate": 0.8,
			"magazine": 6,
			"dps": 80
		},
		"unlocked": true,  # TEMP: Desbloqueado para testes
		"unlock_condition": "Kill 100 enemies",
		"unlock_stat": "total_kills",
		"unlock_value": 100,
		"portrait_color": Color(0.7, 0.4, 0.2),  # Laranja
		"special_ability": "Damage falloff at range"
	}

	# 5. Sniper - Sniper Rifle (unlock: kill boss sem morrer)
	characters["sniper"] = {
		"id": "sniper",
		"name": "Sniper",
		"description": "Long range precision. Scope for accuracy.",
		"weapon_scene": "res://weapons/sniper/sniper.tscn",
		"weapon_name": "Sniper Rifle",
		"stats": {
			"damage": 100,
			"fire_rate": 1.5,
			"magazine": 5,
			"dps": 66
		},
		"unlocked": true,  # TEMP: Desbloqueado para testes
		"unlock_condition": "Kill a boss without taking damage",
		"unlock_stat": "boss_flawless",
		"unlock_value": 1,
		"portrait_color": Color(0.4, 0.4, 0.5),  # Cinza
		"special_ability": "Right-click to scope, headshots deal 2x damage"
	}

	# 6. Heavy - LMG (unlock: complete run com todas armas)
	characters["heavy"] = {
		"id": "heavy",
		"name": "Heavy",
		"description": "Suppressive fire. Spinup required, watch the heat!",
		"weapon_scene": "res://weapons/lmg/lmg.tscn",
		"weapon_name": "LMG",
		"stats": {
			"damage": 12,
			"fire_rate": 0.1,
			"magazine": 100,
			"dps": 120
		},
		"unlocked": true,  # TEMP: Desbloqueado para testes
		"unlock_condition": "Complete a run with all other characters",
		"unlock_stat": "characters_completed",
		"unlock_value": 5,
		"portrait_color": Color(0.5, 0.2, 0.2),  # Vermelho escuro
		"special_ability": "Spinup time, overheat mechanic, slows movement"
	}


# === API PÚBLICA ===

func get_character(character_id: String) -> Dictionary:
	"""Retorna dados de um personagem"""
	return characters.get(character_id, {})


func get_all_characters() -> Array:
	"""Retorna lista de todos os personagens"""
	return characters.values()


func get_unlocked_characters() -> Array:
	"""Retorna apenas personagens desbloqueados"""
	var unlocked = []
	for char in characters.values():
		if char.unlocked:
			unlocked.append(char)
	return unlocked


func is_character_unlocked(character_id: String) -> bool:
	"""Verifica se personagem está desbloqueado"""
	var char = characters.get(character_id, {})
	return char.get("unlocked", false)


func select_character(character_id: String) -> bool:
	"""Seleciona um personagem"""
	if not is_character_unlocked(character_id):
		return false

	selected_character_id = character_id
	character_selected.emit(character_id)
	_save_data()
	return true


func get_selected_character() -> Dictionary:
	"""Retorna o personagem selecionado"""
	return characters.get(selected_character_id, characters["soldier"])


func get_selected_weapon_scene() -> String:
	"""Retorna o caminho da cena da arma do personagem selecionado"""
	var char = get_selected_character()
	return char.get("weapon_scene", "res://weapons/pistol/pistol.tscn")


func spawn_selected_weapon() -> Node3D:
	"""Instancia a arma do personagem selecionado"""
	var weapon_path = get_selected_weapon_scene()
	var weapon_scene = load(weapon_path)
	if weapon_scene:
		return weapon_scene.instantiate()
	return null


# === SISTEMA DE UNLOCK ===

func try_unlock_character(character_id: String) -> bool:
	"""Tenta desbloquear um personagem"""
	if is_character_unlocked(character_id):
		return false

	characters[character_id].unlocked = true
	character_unlocked.emit(character_id)
	_save_data()
	return true


func check_unlock_conditions(stats: Dictionary) -> void:
	"""Verifica condições de unlock baseado em stats do jogador"""
	for char_id in characters.keys():
		var char = characters[char_id]
		if char.unlocked:
			continue

		var unlock_stat = char.get("unlock_stat", "")
		var unlock_value = char.get("unlock_value", 0)

		if unlock_stat != "" and stats.has(unlock_stat):
			if stats[unlock_stat] >= unlock_value:
				try_unlock_character(char_id)


# === PERSISTÊNCIA ===

func _save_data() -> void:
	"""Salva dados de personagens"""
	var save_data = {
		"selected": selected_character_id,
		"unlocked": []
	}

	for char in characters.values():
		if char.unlocked:
			save_data.unlocked.append(char.id)

	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(save_data)


func _load_data() -> void:
	"""Carrega dados de personagens"""
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var save_data = file.get_var()
		if save_data is Dictionary:
			selected_character_id = save_data.get("selected", "soldier")

			var unlocked_list = save_data.get("unlocked", [])
			for char_id in unlocked_list:
				if characters.has(char_id):
					characters[char_id].unlocked = true


func reset_progress() -> void:
	"""Reseta progresso (debug)"""
	for char_id in characters.keys():
		if char_id in ["soldier", "gunslinger", "commando"]:
			characters[char_id].unlocked = true
		else:
			characters[char_id].unlocked = false

	selected_character_id = "soldier"
	_save_data()


# === DEBUG ===

func unlock_all() -> void:
	"""Desbloqueia todos os personagens (debug)"""
	for char_id in characters.keys():
		characters[char_id].unlocked = true
	_save_data()
