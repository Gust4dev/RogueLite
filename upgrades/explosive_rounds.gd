extends BaseUpgrade

# Explosive Rounds - Tiros explodem em AoE
# Lvl 1: 3m radius, 50% damage
# Lvl 2: 5m radius, 75% damage
# Lvl 3: 7m radius, 100% damage

var explosion_radius: float = 3.0
var explosion_damage_percent: float = 0.5


func _ready() -> void:
	upgrade_id = "explosive_rounds"
	upgrade_name = "Explosive Rounds"


func _on_level_changed() -> void:
	"""Atualiza stats baseado no nível"""
	match level:
		1:
			explosion_radius = 3.0
			explosion_damage_percent = 0.5
		2:
			explosion_radius = 5.0
			explosion_damage_percent = 0.75
		3:
			explosion_radius = 7.0
			explosion_damage_percent = 1.0


func _connect_signals() -> void:
	"""Conecta ao signal de hit da arma"""
	if weapon and weapon.has_signal("hit_enemy"):
		_safe_connect(weapon.hit_enemy, _on_hit_enemy)


func _on_hit_enemy(enemy: Node3D, damage: float, is_kill: bool) -> void:
	"""Quando acerta um inimigo, cria explosão"""
	if level <= 0:
		return

	var hit_position = enemy.global_position

	# Cria efeito visual da explosão
	_create_explosion_effect(hit_position)

	# Aplica dano em área
	_apply_aoe_damage(hit_position, damage, enemy)


func _apply_aoe_damage(center: Vector3, base_damage: float, source_enemy: Node3D) -> void:
	"""Aplica dano em área ao redor do ponto de impacto"""
	var explosion_damage = base_damage * explosion_damage_percent

	var enemies = get_tree().get_nodes_in_group("enemies")

	for enemy in enemies:
		if enemy == source_enemy:
			continue  # Já tomou o dano direto

		if not is_instance_valid(enemy):
			continue

		if enemy.has_method("is_alive") and not enemy.is_alive():
			continue

		var distance = center.distance_to(enemy.global_position)

		if distance <= explosion_radius:
			# Dano diminui com distância
			var damage_falloff = 1.0 - (distance / explosion_radius)
			var final_damage = explosion_damage * damage_falloff

			if enemy.has_method("take_damage"):
				enemy.take_damage(final_damage)


func _create_explosion_effect(position: Vector3) -> void:
	"""Cria efeito visual de explosão"""
	# Esfera de explosão
	var explosion = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.1
	sphere.height = 0.2
	explosion.mesh = sphere

	var material = StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.5, 0.1, 0.8)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.4, 0.1)
	material.emission_energy_multiplier = 5.0
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	explosion.material_override = material
	explosion.global_position = position

	get_tree().current_scene.add_child(explosion)

	# Anima expansão
	var tween = explosion.create_tween()
	tween.set_parallel(true)
	tween.tween_property(explosion, "scale", Vector3.ONE * explosion_radius, 0.2)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.3)

	await tween.finished
	if is_instance_valid(explosion):
		explosion.queue_free()


func get_description_for_level(lvl: int) -> String:
	match lvl:
		1:
			return "Explosions: 3m radius, 50% damage"
		2:
			return "Explosions: 5m radius, 75% damage"
		3:
			return "Explosions: 7m radius, 100% damage"
		_:
			return ""
