extends BaseUpgrade

# Chain Lightning - Tiros chainam para inimigos próximos
# Lvl 1: 1 chain (2 inimigos)
# Lvl 2: 2 chains (3 inimigos)
# Lvl 3: 3 chains + dano aumentado
#
# === WEAPON INTERACTIONS ===
# Pistol: Single target → 3 chains max (normal)
# Revolver: Chains poderosos (mais dano, menos decay)
# SMG: Cada bala pode chain (visual chaos!) - reduz max_chains
# Shotgun: Cada pellet pode chain independentemente (OP)
# Sniper: Single shot, chains muito poderosos
# LMG: Chain constantemente (screen filled!) - reduz range

var chain_range: float = 10.0
var damage_decay: float = 0.8  # Cada chain faz 80% do dano anterior
var chain_visual_duration: float = 0.1

# Weapon type
var weapon_type: String = ""

# Multiplicadores por arma
var chain_multiplier: int = 1  # Multiplicador de chains
var decay_multiplier: float = 1.0  # Multiplica o decay
var range_multiplier: float = 1.0  # Multiplica o range


func _ready() -> void:
	upgrade_id = "chain_lightning"
	upgrade_name = "Chain Lightning"


func _apply_effects() -> void:
	"""Detecta tipo de arma e ajusta comportamento"""
	if weapon and weapon.has_method("get_weapon_type"):
		weapon_type = weapon.get_weapon_type()
		_update_weapon_modifiers()


func _update_weapon_modifiers() -> void:
	"""Define modificadores baseados na arma"""
	match weapon_type:
		"pistol":
			chain_multiplier = 1
			decay_multiplier = 1.0
			range_multiplier = 1.0
		"revolver":
			chain_multiplier = 1
			decay_multiplier = 0.7  # Menos decay (mais dano por chain)
			range_multiplier = 1.2  # Maior range
		"smg":
			chain_multiplier = 1
			decay_multiplier = 1.2  # Mais decay (para não ser OP)
			range_multiplier = 0.8  # Menor range
		"shotgun":
			chain_multiplier = 1
			decay_multiplier = 1.0
			range_multiplier = 0.7  # Menor range (já é OP por pellet)
		"sniper":
			chain_multiplier = 2  # Dobro de chains
			decay_multiplier = 0.5  # Muito menos decay
			range_multiplier = 1.5  # Range maior
		"lmg":
			chain_multiplier = 1
			decay_multiplier = 1.3  # Mais decay
			range_multiplier = 0.6  # Bem menor range
		_:
			chain_multiplier = 1
			decay_multiplier = 1.0
			range_multiplier = 1.0


func _connect_signals() -> void:
	"""Conecta ao signal de hit da arma"""
	if weapon and weapon.has_signal("hit_enemy"):
		_safe_connect(weapon.hit_enemy, _on_hit_enemy)


func _on_hit_enemy(enemy: Node3D, damage: float, is_kill: bool) -> void:
	"""Quando acerta um inimigo, chaina para outros"""
	if level <= 0:
		return

	# Número de chains baseado no nível e multiplicador de arma
	var max_chains = level * chain_multiplier

	# Dano base (aumentado no nível 3)
	var chain_damage = damage
	if level >= 3:
		chain_damage *= 1.2

	# Inicia chain
	_chain_to_enemies(enemy, chain_damage, max_chains, [enemy])


func _chain_to_enemies(from_enemy: Node3D, base_damage: float, chains_left: int, hit_list: Array) -> void:
	"""Processa chain de um inimigo para o próximo"""
	if chains_left <= 0:
		return

	if not is_instance_valid(from_enemy):
		return

	# Encontra próximo inimigo mais próximo (com range modificado por arma)
	var effective_range = chain_range * range_multiplier
	var next_enemy = _find_nearest_enemy(from_enemy.global_position, hit_list, effective_range)

	if not next_enemy:
		return

	# Calcula dano com decay (modificado por arma)
	var effective_decay = damage_decay * decay_multiplier
	var chain_damage = base_damage * effective_decay

	# Cria efeito visual de raio (cor varia por arma)
	_create_chain_effect(from_enemy.global_position, next_enemy.global_position)

	# Aplica dano
	if next_enemy.has_method("take_damage"):
		next_enemy.take_damage(chain_damage)

	# Adiciona à lista de atingidos
	hit_list.append(next_enemy)

	# Continua chain (delay varia por arma)
	var chain_delay = 0.05 if weapon_type != "smg" and weapon_type != "lmg" else 0.02
	await get_tree().create_timer(chain_delay).timeout
	_chain_to_enemies(next_enemy, chain_damage, chains_left - 1, hit_list)


func _find_nearest_enemy(from_pos: Vector3, exclude: Array, max_range: float = -1.0) -> Node3D:
	"""Encontra o inimigo mais próximo não na lista de exclusão"""
	var enemies = get_tree().get_nodes_in_group("enemies")
	var nearest: Node3D = null
	var search_range = max_range if max_range > 0 else chain_range
	var nearest_dist = search_range

	for enemy in enemies:
		if enemy in exclude:
			continue

		if not is_instance_valid(enemy):
			continue

		if enemy.has_method("is_alive") and not enemy.is_alive():
			continue

		var dist = from_pos.distance_to(enemy.global_position)
		if dist < nearest_dist:
			nearest = enemy
			nearest_dist = dist

	return nearest


func _create_chain_effect(from: Vector3, to: Vector3) -> void:
	"""Cria efeito visual do raio entre dois pontos"""
	# Cria linha 3D simples
	var line = ImmediateMesh.new()
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = line

	# Cor varia por arma
	var chain_color = _get_chain_color()

	# Material do raio
	var material = StandardMaterial3D.new()
	material.albedo_color = chain_color
	material.emission_enabled = true
	material.emission = chain_color
	material.emission_energy_multiplier = 3.0
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	mesh_instance.material_override = material

	# Adiciona à cena
	get_tree().current_scene.add_child(mesh_instance)

	# Desenha linha
	line.clear_surfaces()
	line.surface_begin(Mesh.PRIMITIVE_LINES)
	line.surface_add_vertex(from + Vector3(0, 1, 0))
	line.surface_add_vertex(to + Vector3(0, 1, 0))
	line.surface_end()

	# Remove após duração
	await get_tree().create_timer(chain_visual_duration).timeout
	if is_instance_valid(mesh_instance):
		mesh_instance.queue_free()


func _get_chain_color() -> Color:
	"""Retorna cor do raio baseada na arma"""
	match weapon_type:
		"sniper":
			return Color(0.8, 0.2, 1.0)  # Roxo (poderoso)
		"shotgun":
			return Color(1.0, 0.5, 0.2)  # Laranja
		"revolver":
			return Color(0.2, 0.8, 1.0)  # Cyan
		"smg", "lmg":
			return Color(0.5, 1.0, 0.5)  # Verde (caótico)
		_:
			return Color(0.3, 0.6, 1.0)  # Azul padrão


func get_description_for_level(lvl: int) -> String:
	match lvl:
		1:
			return "Shots chain to 1 nearby enemy"
		2:
			return "Shots chain to 2 nearby enemies"
		3:
			return "Shots chain to 3 enemies with +20% damage"
		_:
			return ""
