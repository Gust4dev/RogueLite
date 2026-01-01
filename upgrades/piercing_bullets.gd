extends BaseUpgrade

# Piercing Bullets - Tiros atravessam inimigos
# Lvl 1: Atravessa 1 inimigo
# Lvl 2: Atravessa 2 inimigos
# Lvl 3: Atravessa infinito, sem perda de dano

var max_pierce: int = 1
var damage_decay: float = 0.7  # 70% do dano a cada pierce
var pierce_range: float = 50.0


func _ready() -> void:
	upgrade_id = "piercing_bullets"
	upgrade_name = "Piercing Bullets"


func _on_level_changed() -> void:
	"""Atualiza stats baseado no nível"""
	match level:
		1:
			max_pierce = 1
			damage_decay = 0.7
		2:
			max_pierce = 2
			damage_decay = 0.7
		3:
			max_pierce = 999  # "Infinito"
			damage_decay = 1.0  # Sem perda de dano


func _connect_signals() -> void:
	"""Conecta ao signal de disparo da arma"""
	if weapon and weapon.has_signal("weapon_fired"):
		_safe_connect(weapon.weapon_fired, _on_weapon_fired)


func _on_weapon_fired() -> void:
	"""Quando a arma dispara, processa piercing"""
	if level <= 0:
		return

	# Obtém raycast da arma
	var raycast = weapon.get_node_or_null("RayCast3D")
	if not raycast:
		return

	# Processa múltiplos hits
	_process_piercing_shot(raycast)


func _process_piercing_shot(original_raycast: RayCast3D) -> void:
	"""Processa um tiro com piercing"""
	var origin = original_raycast.global_position
	var direction = -original_raycast.global_transform.basis.z
	var current_damage = weapon.damage
	var pierces_left = max_pierce
	var hit_enemies: Array = []

	# Ignora o primeiro hit (já processado pela arma)
	original_raycast.force_raycast_update()
	if original_raycast.is_colliding():
		var first_hit = original_raycast.get_collider()
		if first_hit:
			hit_enemies.append(first_hit)
			origin = original_raycast.get_collision_point() + direction * 0.1

	# Processa piercing adicional
	var space_state = get_tree().current_scene.get_world_3d().direct_space_state

	while pierces_left > 0:
		var query = PhysicsRayQueryParameters3D.create(
			origin,
			origin + direction * pierce_range
		)
		query.collision_mask = 2  # Apenas Enemies
		query.exclude = []

		# Exclui inimigos já atingidos convertendo para RIDs
		for enemy in hit_enemies:
			if is_instance_valid(enemy) and enemy is CollisionObject3D:
				query.exclude.append(enemy.get_rid())

		var result = space_state.intersect_ray(query)

		if result.is_empty():
			break

		var hit_enemy = result.get("collider")
		var hit_position = result.get("position")

		if hit_enemy and hit_enemy.has_method("take_damage"):
			# Calcula dano com decay
			current_damage *= damage_decay

			# Aplica dano
			hit_enemy.take_damage(current_damage)

			# Efeito visual
			_create_pierce_effect(hit_position)

			# Adiciona à lista
			hit_enemies.append(hit_enemy)

			# Atualiza origem para próximo raycast
			origin = hit_position + direction * 0.1

		pierces_left -= 1


func _create_pierce_effect(position: Vector3) -> void:
	"""Cria efeito visual de pierce"""
	var effect = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.15
	sphere.height = 0.3
	effect.mesh = sphere

	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.7, 0.7, 0.9, 0.8)
	material.emission_enabled = true
	material.emission = Color(0.7, 0.7, 0.9)
	material.emission_energy_multiplier = 2.0
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	effect.material_override = material
	effect.global_position = position

	get_tree().current_scene.add_child(effect)

	var tween = effect.create_tween()
	tween.tween_property(material, "albedo_color:a", 0.0, 0.2)

	await tween.finished
	if is_instance_valid(effect):
		effect.queue_free()


func get_description_for_level(lvl: int) -> String:
	match lvl:
		1:
			return "Bullets pierce through 1 enemy (70% damage)"
		2:
			return "Bullets pierce through 2 enemies (70% damage)"
		3:
			return "Bullets pierce infinitely with no damage loss"
		_:
			return ""
