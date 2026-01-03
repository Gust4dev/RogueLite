extends BaseUpgrade

# Ricochet - Tiros rebatem em paredes/inimigos
# Lvl 1: 1 ricochet
# Lvl 2: 2 ricochets
# Lvl 3: 3 ricochets + busca inimigos próximos
#
# === WEAPON INTERACTIONS ===
# Pistol: Normal behavior
# Revolver: Ricochets mais poderosos (menos decay)
# SMG: Menos ricochets por tiro (já são muitos)
# Shotgun: CADA pellet ricocheta! (loucura)
# Sniper: Ricochets atravessam (piercing + ricochet)
# LMG: Normal

var ricochet_range: float = 20.0
var seek_range: float = 8.0  # Range para buscar inimigos no nível 3

# Weapon type
var weapon_type: String = ""

# Modificadores por arma
var ricochet_multiplier: int = 1  # Multiplicador de ricochets
var damage_retention: float = 0.7  # % de dano mantido por ricochet


func _ready() -> void:
	upgrade_id = "ricochet"
	upgrade_name = "Ricochet"


func _apply_effects() -> void:
	"""Detecta tipo de arma e ajusta comportamento"""
	if weapon and weapon.has_method("get_weapon_type"):
		weapon_type = weapon.get_weapon_type()
		_update_weapon_modifiers()


func _update_weapon_modifiers() -> void:
	"""Define modificadores baseados na arma"""
	match weapon_type:
		"pistol":
			ricochet_multiplier = 1
			damage_retention = 0.7
		"revolver":
			ricochet_multiplier = 1
			damage_retention = 0.85  # Mantém mais dano
		"smg":
			ricochet_multiplier = 1
			damage_retention = 0.5  # Menos dano (muitos tiros)
		"shotgun":
			ricochet_multiplier = 1  # Já é OP pq cada pellet ricocheta
			damage_retention = 0.6
		"sniper":
			ricochet_multiplier = 1
			damage_retention = 0.9  # Mantém quase todo dano
		"lmg":
			ricochet_multiplier = 1
			damage_retention = 0.5
		_:
			ricochet_multiplier = 1
			damage_retention = 0.7


func _connect_signals() -> void:
	"""Conecta ao signal de disparo da arma"""
	if weapon and weapon.has_signal("weapon_fired"):
		_safe_connect(weapon.weapon_fired, _on_weapon_fired)


func _on_weapon_fired() -> void:
	"""Quando a arma dispara, processa ricochet"""
	if level <= 0:
		return

	# Obtém raycast da arma
	var raycast = weapon.get_node_or_null("RayCast3D")
	if not raycast:
		return

	raycast.force_raycast_update()

	if not raycast.is_colliding():
		return

	var hit_point = raycast.get_collision_point()
	var hit_normal = raycast.get_collision_normal()
	var collider = raycast.get_collider()

	# Número de ricochets baseado no nível e multiplicador
	var max_ricochets = level * ricochet_multiplier

	# Inicia cadeia de ricochets
	_process_ricochet(hit_point, raycast.global_transform.basis.z * -1, hit_normal, max_ricochets, [collider])


func _process_ricochet(origin: Vector3, direction: Vector3, normal: Vector3, ricochets_left: int, hit_list: Array) -> void:
	"""Processa um ricochet"""
	if ricochets_left <= 0:
		return

	# Calcula direção refletida
	var reflected_dir = direction.bounce(normal).normalized()

	# No nível 3, busca inimigo próximo
	if level >= 3:
		var target = _find_nearby_enemy(origin, hit_list)
		if target:
			reflected_dir = (target.global_position - origin).normalized()

	# Cria novo raycast para o ricochet
	var space_state = get_tree().current_scene.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		origin + normal * 0.1,  # Offset para evitar auto-colisão
		origin + reflected_dir * ricochet_range
	)
	query.collision_mask = 6  # Enemies + World

	var result = space_state.intersect_ray(query)

	# Efeito visual do ricochet
	_create_ricochet_effect(origin, result.get("position", origin + reflected_dir * ricochet_range))

	if result.is_empty():
		return

	var hit_collider = result.get("collider")
	var hit_position = result.get("position")
	var hit_norm = result.get("normal")

	# Se acertou um inimigo
	if hit_collider and hit_collider.has_method("take_damage"):
		if hit_collider not in hit_list:
			hit_collider.take_damage(weapon.damage * damage_retention)  # Dano ajustado por arma
			hit_list.append(hit_collider)

	# Continua ricocheteando
	await get_tree().create_timer(0.02).timeout
	_process_ricochet(hit_position, reflected_dir, hit_norm, ricochets_left - 1, hit_list)


func _find_nearby_enemy(from_pos: Vector3, exclude: Array) -> Node3D:
	"""Encontra inimigo próximo para homing no nível 3"""
	var enemies = get_tree().get_nodes_in_group("enemies")
	var nearest: Node3D = null
	var nearest_dist = seek_range

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


func _create_ricochet_effect(from: Vector3, to: Vector3) -> void:
	"""Cria efeito visual do projétil ricocheteando"""
	var line = ImmediateMesh.new()
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = line

	var material = StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.8, 0.2)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.8, 0.2)
	material.emission_energy_multiplier = 2.0
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	mesh_instance.material_override = material

	get_tree().current_scene.add_child(mesh_instance)

	line.clear_surfaces()
	line.surface_begin(Mesh.PRIMITIVE_LINES)
	line.surface_add_vertex(from)
	line.surface_add_vertex(to)
	line.surface_end()

	await get_tree().create_timer(0.08).timeout
	if is_instance_valid(mesh_instance):
		mesh_instance.queue_free()


func get_description_for_level(lvl: int) -> String:
	match lvl:
		1:
			return "Bullets ricochet 1 time"
		2:
			return "Bullets ricochet 2 times"
		3:
			return "Bullets ricochet 3 times and seek enemies"
		_:
			return ""
