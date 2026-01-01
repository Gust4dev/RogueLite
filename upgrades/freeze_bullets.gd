extends BaseUpgrade

# Freeze Bullets - Slow/congela inimigos
# Lvl 1: Slow 30% por 2s
# Lvl 2: Slow 50% por 3s
# Lvl 3: Freeze completo por 2s

var slow_percent: float = 0.30
var effect_duration: float = 2.0
var is_freeze: bool = false

# Tracking de inimigos afetados
var affected_enemies: Dictionary = {}  # enemy -> { original_speed, timer }


func _ready() -> void:
	upgrade_id = "freeze_bullets"
	upgrade_name = "Freeze Bullets"


func _on_level_changed() -> void:
	"""Atualiza stats baseado no nível"""
	match level:
		1:
			slow_percent = 0.30
			effect_duration = 2.0
			is_freeze = false
		2:
			slow_percent = 0.50
			effect_duration = 3.0
			is_freeze = false
		3:
			slow_percent = 1.0  # 100% = freeze total
			effect_duration = 2.0
			is_freeze = true


func _connect_signals() -> void:
	"""Conecta ao signal de hit da arma"""
	if weapon and weapon.has_signal("hit_enemy"):
		_safe_connect(weapon.hit_enemy, _on_hit_enemy)


func _process(delta: float) -> void:
	"""Processa timers de slow/freeze"""
	var to_remove: Array = []

	for enemy in affected_enemies:
		if not is_instance_valid(enemy):
			to_remove.append(enemy)
			continue

		var data = affected_enemies[enemy]
		data.timer -= delta

		if data.timer <= 0:
			# Remove efeito
			_remove_effect_from_enemy(enemy, data)
			to_remove.append(enemy)

	for enemy in to_remove:
		affected_enemies.erase(enemy)


func _on_hit_enemy(enemy: Node3D, damage: float, is_kill: bool) -> void:
	"""Quando acerta um inimigo, aplica slow/freeze"""
	if level <= 0:
		return

	if is_kill:
		return  # Não aplica em inimigos mortos

	if not is_instance_valid(enemy):
		return

	# Aplica ou renova efeito
	_apply_effect_to_enemy(enemy)


func _apply_effect_to_enemy(enemy: Node3D) -> void:
	"""Aplica efeito de slow/freeze ao inimigo"""
	var original_speed: float = 3.0

	# Obtém velocidade original
	if "speed" in enemy:
		if enemy not in affected_enemies:
			original_speed = enemy.speed
		else:
			original_speed = affected_enemies[enemy].original_speed
	else:
		return

	# Registra o inimigo
	affected_enemies[enemy] = {
		"original_speed": original_speed,
		"timer": effect_duration
	}

	# Aplica slow/freeze
	if is_freeze:
		enemy.speed = 0.0
		# Também para o physics process se possível
		if enemy.has_method("set_physics_process"):
			enemy.set_physics_process(false)
	else:
		enemy.speed = original_speed * (1.0 - slow_percent)

	# Efeito visual
	_apply_freeze_visual(enemy)


func _remove_effect_from_enemy(enemy: Node3D, data: Dictionary) -> void:
	"""Remove efeito de slow/freeze do inimigo"""
	if not is_instance_valid(enemy):
		return

	# Restaura velocidade
	if "speed" in enemy:
		enemy.speed = data.original_speed

	# Restaura physics process
	if is_freeze and enemy.has_method("set_physics_process"):
		enemy.set_physics_process(true)

	# Remove visual
	_remove_freeze_visual(enemy)


func _apply_freeze_visual(enemy: Node3D) -> void:
	"""Aplica efeito visual de gelo ao inimigo"""
	# Busca mesh do inimigo
	var mesh_instance: MeshInstance3D = null

	if enemy.has_node("EnemyMesh"):
		var mesh = enemy.get_node("EnemyMesh")
		if mesh is MeshInstance3D:
			mesh_instance = mesh
		else:
			mesh_instance = mesh.find_child("*", true, false) as MeshInstance3D

	if not mesh_instance:
		for child in enemy.get_children():
			if child is MeshInstance3D:
				mesh_instance = child
				break

	if not mesh_instance:
		return

	# Cria ou atualiza material de gelo
	var freeze_material = mesh_instance.get_surface_override_material(0)
	if not freeze_material or not freeze_material is StandardMaterial3D:
		freeze_material = StandardMaterial3D.new()
		mesh_instance.set_surface_override_material(0, freeze_material)

	# Aplica cor azul gelado
	var ice_color = Color(0.4, 0.8, 1.0) if not is_freeze else Color(0.6, 0.9, 1.0)
	freeze_material.albedo_color = ice_color
	freeze_material.emission_enabled = true
	freeze_material.emission = Color(0.3, 0.6, 0.9)
	freeze_material.emission_energy_multiplier = 1.0 if not is_freeze else 2.0


func _remove_freeze_visual(enemy: Node3D) -> void:
	"""Remove efeito visual de gelo"""
	var mesh_instance: MeshInstance3D = null

	if enemy.has_node("EnemyMesh"):
		var mesh = enemy.get_node("EnemyMesh")
		if mesh is MeshInstance3D:
			mesh_instance = mesh
		else:
			mesh_instance = mesh.find_child("*", true, false) as MeshInstance3D

	if not mesh_instance:
		for child in enemy.get_children():
			if child is MeshInstance3D:
				mesh_instance = child
				break

	if not mesh_instance:
		return

	# Restaura material original
	var material = mesh_instance.get_surface_override_material(0)
	if material is StandardMaterial3D:
		material.albedo_color = Color.WHITE
		material.emission_enabled = false


func get_description_for_level(lvl: int) -> String:
	match lvl:
		1:
			return "Slow enemies by 30% for 2 seconds"
		2:
			return "Slow enemies by 50% for 3 seconds"
		3:
			return "Completely freeze enemies for 2 seconds"
		_:
			return ""
