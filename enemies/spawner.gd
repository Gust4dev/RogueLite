extends BaseEnemy

# Spawner - Inimigo que fica parado e spawna outros inimigos
# Alta prioridade de kill, não se move

class_name Spawner

# Configuração do Spawner
@export_group("Spawner Config")
@export var spawn_cooldown: float = 5.0
@export var max_spawned_enemies: int = 5
@export var spawn_radius: float = 3.0
@export var spawn_on_death_count: int = 2  # Spawna inimigos ao morrer

# Customização Visual
@export_group("Visual")
@export var mesh_scale: float = 1.2
@export var mesh_y_offset: float = 0.0
@export var mesh_rotation_y: float = 180.0
@export var glow_color: Color = Color(0.8, 0.0, 0.8)  # Roxo

# Estado interno
var spawn_timer: float = 0.0
var spawned_enemies: Array[Node3D] = []
var zombie_scene: PackedScene = null
var is_spawning: bool = false

func _ready() -> void:
	# Stats específicas do Spawner
	max_health = 100.0
	speed = 0.0  # Não se move
	damage = 5.0  # Dano baixo se player chegar perto
	attack_range = 2.0
	attack_cooldown = 2.0
	xp_reward = 75  # Alto XP por ser alvo prioritário

	# Chama o _ready() do pai
	super._ready()

	# Aplica customização visual
	_apply_visual_customization()

	# Carrega cena do zombie para spawnar
	if ResourceLoader.exists("res://enemies/zombie.tscn"):
		zombie_scene = load("res://enemies/zombie.tscn")


func _apply_visual_customization() -> void:
	"""Aplica escala, offset Y e rotação ao mesh"""
	if mesh:
		mesh.scale = Vector3(mesh_scale, mesh_scale, mesh_scale) * 0.01
		mesh.position.y = mesh_y_offset
		mesh.rotation_degrees.y = mesh_rotation_y

	# Aplica visual de spawner
	_setup_spawner_visual()


func _setup_spawner_visual() -> void:
	"""Configura visual específico do spawner"""
	var mesh_instance = _find_mesh_instance()
	if mesh_instance:
		var material = StandardMaterial3D.new()
		material.albedo_color = glow_color
		material.emission_enabled = true
		material.emission = glow_color
		material.emission_energy_multiplier = 1.5
		mesh_instance.set_surface_override_material(0, material)


func _physics_process(delta: float) -> void:
	if not _is_alive:
		return

	# Spawner não se move, mas aplica gravidade
	if not is_on_floor():
		velocity.y -= gravity * delta
		move_and_slide()

	# Atualiza timer de ataque
	if attack_timer > 0:
		attack_timer -= delta
		if attack_timer <= 0:
			can_attack = true

	# Atualiza timer de spawn
	spawn_timer += delta

	# Limpa referências a inimigos mortos
	_clean_dead_spawns()

	# Tenta spawnar inimigo
	if spawn_timer >= spawn_cooldown and not is_spawning:
		if spawned_enemies.size() < max_spawned_enemies:
			_spawn_minion()
			spawn_timer = 0.0

	# Ataque melee se player muito perto
	if target:
		var distance = global_position.distance_to(target.global_position)

		# Olha para o player
		var look_target = Vector3(target.global_position.x, global_position.y, target.global_position.z)
		if global_position.distance_to(look_target) > 0.1:
			look_at(look_target)

		if distance <= attack_range and can_attack:
			attack()


func _clean_dead_spawns() -> void:
	"""Remove referências a inimigos mortos"""
	var valid_spawns: Array[Node3D] = []
	for enemy in spawned_enemies:
		if is_instance_valid(enemy) and enemy.has_method("is_alive"):
			if enemy.is_alive():
				valid_spawns.append(enemy)
	spawned_enemies = valid_spawns


func _spawn_minion() -> void:
	"""Spawna um minion (zombie)"""
	if not zombie_scene:
		return

	is_spawning = true

	# Efeito visual de spawn
	_spawn_telegraph()

	await get_tree().create_timer(0.5).timeout

	if not _is_alive:
		is_spawning = false
		return

	# Calcula posição de spawn
	var angle = randf() * TAU
	var spawn_offset = Vector3(
		cos(angle) * spawn_radius,
		0.5,
		sin(angle) * spawn_radius
	)
	var spawn_pos = global_position + spawn_offset

	# Instancia o minion
	var minion = zombie_scene.instantiate()
	get_tree().current_scene.add_child(minion)
	minion.global_position = spawn_pos

	# Registra o minion
	spawned_enemies.append(minion)

	# Conecta ao signal de morte
	if minion.has_signal("died"):
		minion.died.connect(_on_minion_died.bind(minion))

	# Efeito de spawn completo
	_spawn_effect(spawn_pos)

	is_spawning = false


func _spawn_telegraph() -> void:
	"""Efeito visual antes de spawnar"""
	var mesh_instance = _find_mesh_instance()
	if mesh_instance:
		var mat = mesh_instance.get_surface_override_material(0)
		if mat is StandardMaterial3D:
			var original_intensity = mat.emission_energy_multiplier
			mat.emission_energy_multiplier = 4.0

			await get_tree().create_timer(0.3).timeout
			if is_instance_valid(mat):
				mat.emission_energy_multiplier = original_intensity


func _spawn_effect(pos: Vector3) -> void:
	"""Efeito visual no local do spawn"""
	var effect = MeshInstance3D.new()
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = 0.8
	cylinder.bottom_radius = 0.8
	cylinder.height = 0.1
	effect.mesh = cylinder

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(glow_color.r, glow_color.g, glow_color.b, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = glow_color
	mat.emission_energy_multiplier = 2.0
	effect.set_surface_override_material(0, mat)

	get_tree().current_scene.add_child(effect)
	effect.global_position = pos

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(effect, "scale", Vector3.ONE * 2.0, 0.5)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.5)

	await tween.finished
	effect.queue_free()


func _on_minion_died(minion: Node3D) -> void:
	"""Callback quando um minion morre"""
	if minion in spawned_enemies:
		spawned_enemies.erase(minion)


func die() -> void:
	"""Override: Spawna inimigos ao morrer"""
	if not _is_alive:
		return

	_is_alive = false
	current_health = 0.0

	# Spawna inimigos de morte
	_spawn_death_minions()

	# Dropa XP
	_drop_xp()

	died.emit()

	# Desabilita física
	set_physics_process(false)

	# Animação de morte
	await _death_animation()

	queue_free()


func _spawn_death_minions() -> void:
	"""Spawna minions ao morrer"""
	if not zombie_scene:
		return

	for i in range(spawn_on_death_count):
		var angle = (TAU / spawn_on_death_count) * i
		var spawn_offset = Vector3(
			cos(angle) * 2.0,
			0.5,
			sin(angle) * 2.0
		)
		var spawn_pos = global_position + spawn_offset

		var minion = zombie_scene.instantiate()
		get_tree().current_scene.add_child(minion)
		minion.global_position = spawn_pos

		_spawn_effect(spawn_pos)


func _death_animation() -> void:
	"""Animação de morte do spawner"""
	if mesh:
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(mesh, "scale", Vector3.ZERO, 0.3)
		if mesh:
			tween.tween_property(mesh, "rotation:y", mesh.rotation.y + PI * 2, 0.3)
		await tween.finished
