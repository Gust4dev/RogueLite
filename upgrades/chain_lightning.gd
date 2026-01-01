extends BaseUpgrade

# Chain Lightning - Tiros chainam para inimigos próximos
# Lvl 1: 1 chain (2 inimigos)
# Lvl 2: 2 chains (3 inimigos)
# Lvl 3: 3 chains + dano aumentado

var chain_range: float = 10.0
var damage_decay: float = 0.8  # Cada chain faz 80% do dano anterior
var chain_visual_duration: float = 0.1


func _ready() -> void:
	upgrade_id = "chain_lightning"
	upgrade_name = "Chain Lightning"


func _connect_signals() -> void:
	"""Conecta ao signal de hit da arma"""
	if weapon and weapon.has_signal("hit_enemy"):
		_safe_connect(weapon.hit_enemy, _on_hit_enemy)


func _on_hit_enemy(enemy: Node3D, damage: float, is_kill: bool) -> void:
	"""Quando acerta um inimigo, chaina para outros"""
	if level <= 0:
		return

	# Número de chains baseado no nível
	var max_chains = level

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

	# Encontra próximo inimigo mais próximo
	var next_enemy = _find_nearest_enemy(from_enemy.global_position, hit_list)

	if not next_enemy:
		return

	# Calcula dano com decay
	var chain_damage = base_damage * damage_decay

	# Cria efeito visual de raio
	_create_chain_effect(from_enemy.global_position, next_enemy.global_position)

	# Aplica dano
	if next_enemy.has_method("take_damage"):
		next_enemy.take_damage(chain_damage)

	# Adiciona à lista de atingidos
	hit_list.append(next_enemy)

	# Continua chain
	await get_tree().create_timer(0.05).timeout
	_chain_to_enemies(next_enemy, chain_damage, chains_left - 1, hit_list)


func _find_nearest_enemy(from_pos: Vector3, exclude: Array) -> Node3D:
	"""Encontra o inimigo mais próximo não na lista de exclusão"""
	var enemies = get_tree().get_nodes_in_group("enemies")
	var nearest: Node3D = null
	var nearest_dist = chain_range

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

	# Material do raio
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.3, 0.6, 1.0)
	material.emission_enabled = true
	material.emission = Color(0.3, 0.6, 1.0)
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
