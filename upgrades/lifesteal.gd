extends BaseUpgrade

# Lifesteal - Recupera HP ao acertar
# Lvl 1: 5% do dano vira HP
# Lvl 2: 10% do dano vira HP
# Lvl 3: 15% + overheal (shield)

var lifesteal_percent: float = 0.05
var can_overheal: bool = false
var max_overheal: float = 50.0  # Shield máximo

var current_shield: float = 0.0


func _ready() -> void:
	upgrade_id = "lifesteal"
	upgrade_name = "Lifesteal"


func _on_level_changed() -> void:
	"""Atualiza stats baseado no nível"""
	match level:
		1:
			lifesteal_percent = 0.05
			can_overheal = false
		2:
			lifesteal_percent = 0.10
			can_overheal = false
		3:
			lifesteal_percent = 0.15
			can_overheal = true


func _connect_signals() -> void:
	"""Conecta ao signal de hit da arma"""
	if weapon and weapon.has_signal("hit_enemy"):
		_safe_connect(weapon.hit_enemy, _on_hit_enemy)


func _on_hit_enemy(enemy: Node3D, damage: float, is_kill: bool) -> void:
	"""Quando acerta um inimigo, rouba vida"""
	if level <= 0:
		return

	if not player_stats:
		return

	# Calcula HP a recuperar
	var heal_amount = damage * lifesteal_percent

	if can_overheal and level >= 3:
		# Verifica se já está no máximo de HP
		if player_stats.current_health >= player_stats.max_health:
			# Adiciona como shield
			_add_shield(heal_amount)
		else:
			# Cura normalmente, overflow vai para shield
			var missing_health = player_stats.max_health - player_stats.current_health
			if heal_amount > missing_health:
				player_stats.heal(missing_health)
				_add_shield(heal_amount - missing_health)
			else:
				player_stats.heal(heal_amount)
	else:
		# Cura normal
		if player_stats.has_method("heal"):
			player_stats.heal(heal_amount)

	# Efeito visual
	_create_lifesteal_effect()


func _add_shield(amount: float) -> void:
	"""Adiciona shield (overheal)"""
	current_shield = min(current_shield + amount, max_overheal)

	# Visual de shield
	_create_shield_effect()


func _process(delta: float) -> void:
	"""Processa decay do shield"""
	if current_shield > 0:
		# Shield decai lentamente
		current_shield -= delta * 2.0
		current_shield = max(0, current_shield)


func take_damage_with_shield(amount: float) -> float:
	"""Processa dano considerando shield - retorna dano restante"""
	if current_shield <= 0:
		return amount

	if amount <= current_shield:
		current_shield -= amount
		return 0.0
	else:
		var remaining = amount - current_shield
		current_shield = 0
		return remaining


func _create_lifesteal_effect() -> void:
	"""Cria efeito visual de lifesteal"""
	if not player:
		return

	# Partícula verde subindo
	var effect = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.1
	sphere.height = 0.2
	effect.mesh = sphere

	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 1.0, 0.3, 0.8)
	material.emission_enabled = true
	material.emission = Color(0.2, 1.0, 0.3)
	material.emission_energy_multiplier = 2.0
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	effect.material_override = material
	effect.global_position = player.global_position + Vector3(0, 1, 0)

	get_tree().current_scene.add_child(effect)

	var tween = effect.create_tween()
	tween.set_parallel(true)
	tween.tween_property(effect, "global_position:y", effect.global_position.y + 1.5, 0.5)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.5)

	await tween.finished
	if is_instance_valid(effect):
		effect.queue_free()


func _create_shield_effect() -> void:
	"""Cria efeito visual de shield"""
	if not player:
		return

	# Efeito roxo pulsante
	var effect = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.8
	sphere.height = 1.6
	effect.mesh = sphere

	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.6, 0.2, 0.8, 0.3)
	material.emission_enabled = true
	material.emission = Color(0.6, 0.2, 0.8)
	material.emission_energy_multiplier = 1.5
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED

	effect.material_override = material
	effect.global_position = player.global_position + Vector3(0, 1, 0)

	get_tree().current_scene.add_child(effect)

	var tween = effect.create_tween()
	tween.tween_property(material, "albedo_color:a", 0.0, 0.3)

	await tween.finished
	if is_instance_valid(effect):
		effect.queue_free()


func get_description_for_level(lvl: int) -> String:
	match lvl:
		1:
			return "Heal 5% of damage dealt"
		2:
			return "Heal 10% of damage dealt"
		3:
			return "Heal 15% of damage + overheal as shield"
		_:
			return ""
