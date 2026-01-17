extends CharacterBody3D

# Base Enemy - Classe base para todos os inimigos
# Implementa pathfinding, health, e ataque básico

class_name BaseEnemy

# Signals
signal died()
signal damage_received(amount: float)
signal attack_performed()

# Stats (para serem sobrescritos pelas classes filhas)
@export var max_health: float = 50.0
@export var speed: float = 3.0
@export var damage: float = 10.0
@export var attack_range: float = 2.0
@export var attack_cooldown: float = 1.5
@export var xp_reward: int = 10  # XP dropado ao morrer

# === SEPARATION BEHAVIOR ===
@export_group("Separation")
@export var separation_radius: float = 2.0       # Raio de detecção de outros inimigos
@export var separation_strength: float = 4.0    # Força de repulsão
@export var max_separation_force: float = 3.0   # Limite da força

# Estado
var current_health: float = 50.0
var _is_alive: bool = true
var can_attack: bool = true

# Target (player)
var target: Node3D = null

# Referências
@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D

# Mesh e animação (buscados dinamicamente)
var mesh: Node3D = null
var animation_player: AnimationPlayer = null

# Controle de ataque
var attack_timer: float = 0.0

# Gravidade
var gravity: float = 9.8

# Separation cache (atualiza periodicamente para performance)
var nearby_enemies: Array[Node3D] = []
var nearby_update_timer: float = 0.0
const NEARBY_UPDATE_INTERVAL: float = 0.2  # Atualiza a cada 200ms

func _ready() -> void:
	# Aplica scaling de dificuldade baseado no tempo
	_apply_difficulty_scaling()

	# Inicializa health
	current_health = max_health
	_is_alive = true

	# Adiciona ao grupo enemies
	add_to_group("enemies")

	# Buscar mesh dinamicamente (pode ser EnemyMesh ou qualquer outro nome)
	mesh = get_node_or_null("EnemyMesh")
	if not mesh:
		for child in get_children():
			if child is Node3D and not child is NavigationAgent3D and not child is CollisionShape3D:
				mesh = child
				break

	# Buscar AnimationPlayer dentro do mesh (GLBs importados geralmente têm um)
	if mesh:
		animation_player = mesh.find_child("AnimationPlayer", true, false)

	# Configura NavigationAgent
	if navigation_agent:
		navigation_agent.path_desired_distance = 0.5
		navigation_agent.target_desired_distance = 0.5
		navigation_agent.max_speed = speed

	# Encontra o player
	call_deferred("_find_player")

	# Toca animação de spawn
	_play_spawn_animation()


func _apply_difficulty_scaling() -> void:
	"""Aplica scaling de dificuldade baseado no tempo decorrido"""
	if not GameManager:
		return

	# Obtém stats escalados
	var scaled = GameManager.get_scaled_enemy_stats(max_health, damage)
	max_health = scaled["hp"]
	damage = scaled["damage"]

func _find_player() -> void:
	"""Encontra o player na cena"""
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		target = players[0]

func _physics_process(delta: float) -> void:
	if not _is_alive:
		return

	# Aplica gravidade
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	# Atualiza timer de ataque
	if attack_timer > 0:
		attack_timer -= delta
		if attack_timer <= 0:
			can_attack = true
	
	# Atualiza cache de inimigos próximos (performance)
	nearby_update_timer -= delta
	if nearby_update_timer <= 0:
		_update_nearby_enemies()
		nearby_update_timer = NEARBY_UPDATE_INTERVAL

	# Se não tem target, não faz nada
	if not target:
		move_and_slide()
		return

	# Calcula distância até o target
	var distance_to_target = global_position.distance_to(target.global_position)

	# Se está em range de ataque, ataca
	if distance_to_target <= attack_range:
		# Para de se mover
		velocity.x = 0
		velocity.z = 0

		# Olha para o player (com verificação de distância)
		var look_target = Vector3(target.global_position.x, global_position.y, target.global_position.z)
		if global_position.distance_to(look_target) > 0.1:
			look_at(look_target)

		# Ataca
		if can_attack:
			attack()
	else:
		# Se está longe, segue o player usando navegação
		_navigate_to_target()
	
	# Aplica força de separação para evitar ficar grudado com outros inimigos
	_apply_separation_force()

	# Atualiza movimento
	move_and_slide()


func _navigate_to_target() -> void:
	"""Navega em direção ao target usando NavigationAgent ou movimento direto"""
	if not target:
		return
	
	var target_pos = target.global_position
	var direction = Vector3.ZERO
	
	if navigation_agent:
		# Define o destino
		navigation_agent.target_position = target_pos
		
		# Verifica se há um caminho disponível
		# get_next_path_position retorna a posição atual se não houver caminho
		var next_pos = navigation_agent.get_next_path_position()
		var distance_to_next = global_position.distance_to(next_pos)
		
		# Se a próxima posição é muito próxima ou igual à atual, não há path
		if distance_to_next < 0.1:
			# Sem caminho válido - fallback para movimento direto
			direction = (target_pos - global_position).normalized()
		else:
			# Há caminho - segue o path
			direction = (next_pos - global_position).normalized()
	else:
		# Sem NavigationAgent - movimento direto
		direction = (target_pos - global_position).normalized()
	
	# Remove componente Y para manter no plano horizontal
	direction.y = 0
	
	# Aplica velocidade
	if direction.length() > 0.1:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		
		# Olha para onde está indo
		var look_target = global_position + direction
		look_target.y = global_position.y
		if global_position.distance_to(look_target) > 0.1:
			look_at(look_target)


func _update_nearby_enemies() -> void:
	"""Atualiza cache de inimigos próximos para separation"""
	nearby_enemies.clear()
	
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy == self:
			continue
		if not is_instance_valid(enemy):
			continue
		
		var dist = global_position.distance_to(enemy.global_position)
		if dist < separation_radius:
			nearby_enemies.append(enemy)


func _apply_separation_force() -> void:
	"""Aplica força de separação para evitar agrupar com outros inimigos"""
	if nearby_enemies.is_empty():
		return
	
	var separation_velocity = Vector3.ZERO
	
	for enemy in nearby_enemies:
		if not is_instance_valid(enemy):
			continue
		
		var to_self = global_position - enemy.global_position
		var dist = to_self.length()
		
		if dist < 0.01:
			# Inimigos no mesmo lugar - empurra em direção aleatória
			to_self = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
			dist = 0.1
		
		# Força inversamente proporcional à distância
		var force_magnitude = separation_strength * (1.0 - (dist / separation_radius))
		force_magnitude = clampf(force_magnitude, 0.0, max_separation_force)
		
		separation_velocity += to_self.normalized() * force_magnitude
	
	# Limita força total
	if separation_velocity.length() > max_separation_force:
		separation_velocity = separation_velocity.normalized() * max_separation_force
	
	# Aplica à velocidade horizontal
	velocity.x += separation_velocity.x
	velocity.z += separation_velocity.z

func take_damage(amount: float) -> void:
	"""Aplica dano ao inimigo"""
	if not _is_alive:
		return

	current_health -= amount
	damage_received.emit(amount)

	# Flash de dano (vermelho)
	_damage_flash()

	# Verifica se morreu
	if current_health <= 0:
		die()

func die() -> void:
	"""Mata o inimigo"""
	if not _is_alive:
		return

	_is_alive = false
	current_health = 0.0

	# Dropa XP orbs
	_drop_xp()

	died.emit()

	# Desabilita física e colisão imediatamente
	set_physics_process(false)
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)

	# Animação de morte: afunda no chão + fica transparente
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Afunda no chão
	tween.tween_property(self, "position:y", position.y - 2.0, 0.5).set_ease(Tween.EASE_IN)
	
	# Fade de transparência em todos os materiais do mesh
	if mesh:
		_set_all_materials_transparent(mesh)
		_fade_all_materials(mesh, tween, 0.5)
	
	await tween.finished

	# Remove da cena
	queue_free()

func attack() -> void:
	"""Ataca o target"""
	if not can_attack or not _is_alive:
		return

	can_attack = false
	attack_timer = attack_cooldown

	# Aplica dano ao player se ele tem o método take_damage
	if target and target.has_method("take_damage"):
		# Aplica multiplicador de dificuldade ao dano
		var actual_damage = damage
		if GameManager:
			actual_damage = damage * GameManager.get_damage_multiplier()
		target.take_damage(actual_damage)

	attack_performed.emit()

func is_alive() -> bool:
	"""Retorna se o inimigo está vivo"""
	return _is_alive

func _find_mesh_instance() -> MeshInstance3D:
	"""Busca o primeiro MeshInstance3D dentro do mesh"""
	if not mesh:
		return null
	
	if mesh is MeshInstance3D:
		return mesh
	
	# Busca recursivamente
	var found = mesh.find_child("*", true, false) as MeshInstance3D
	if found:
		return found
	
	for child in mesh.get_children():
		if child is MeshInstance3D:
			return child
		for grandchild in child.get_children():
			if grandchild is MeshInstance3D:
				return grandchild
	
	return null

func _get_or_create_material(mesh_instance: MeshInstance3D) -> StandardMaterial3D:
	"""Retorna ou cria um material para o MeshInstance"""
	if not mesh_instance:
		return null
	
	var material: StandardMaterial3D = null
	if mesh_instance.get_surface_override_material(0) is StandardMaterial3D:
		material = mesh_instance.get_surface_override_material(0)
	else:
		material = StandardMaterial3D.new()
		mesh_instance.set_surface_override_material(0, material)
	
	return material

func _set_all_materials_transparent(node: Node) -> void:
	"""Configura todos os materiais para suportar transparência"""
	for child in node.get_children():
		if child is MeshInstance3D:
			for i in range(child.get_surface_override_material_count()):
				var mat = child.get_surface_override_material(i)
				if mat == null:
					mat = child.mesh.surface_get_material(i) if child.mesh else null
				if mat == null:
					mat = StandardMaterial3D.new()
				if mat is StandardMaterial3D:
					var new_mat = mat.duplicate()
					new_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					child.set_surface_override_material(i, new_mat)
		_set_all_materials_transparent(child)

func _fade_all_materials(node: Node, tween: Tween, duration: float) -> void:
	"""Faz fade de todos os materiais no node"""
	for child in node.get_children():
		if child is MeshInstance3D:
			for i in range(child.get_surface_override_material_count()):
				var mat = child.get_surface_override_material(i)
				if mat is StandardMaterial3D:
					tween.tween_property(mat, "albedo_color:a", 0.0, duration)
		_fade_all_materials(child, tween, duration)

func _damage_flash() -> void:
	"""Flash vermelho ao receber dano"""
	if not mesh:
		return

	# Busca o primeiro MeshInstance3D dentro do modelo
	var mesh_instance: MeshInstance3D = null
	if mesh is MeshInstance3D:
		mesh_instance = mesh
	else:
		mesh_instance = mesh.find_child("*", true, false) as MeshInstance3D
		if not mesh_instance:
			# Busca qualquer MeshInstance3D
			for child in mesh.get_children():
				if child is MeshInstance3D:
					mesh_instance = child
					break
				for grandchild in child.get_children():
					if grandchild is MeshInstance3D:
						mesh_instance = grandchild
						break

	if not mesh_instance:
		return

	# Pega ou cria material
	var material: StandardMaterial3D = null
	if mesh_instance.get_surface_override_material(0) is StandardMaterial3D:
		material = mesh_instance.get_surface_override_material(0)
	else:
		material = StandardMaterial3D.new()
		mesh_instance.set_surface_override_material(0, material)

	if not material:
		return

	# Flash vermelho
	material.albedo_color = Color.RED

	# Volta ao normal
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(material):
		material.albedo_color = Color.WHITE

func _play_death_animation() -> void:
	"""Toca animação de morte (Start invertida)"""
	if not animation_player:
		return
	
	if animation_player.has_animation("Start"):
		animation_player.play_backwards("Start")
		await animation_player.animation_finished

func _play_spawn_animation() -> void:
	"""Toca animação de spawn (Start) e depois Idle"""
	if not animation_player:
		return

	# Conecta sinal para quando a animação terminar
	if animation_player.has_animation("Start"):
		animation_player.play("Start")
		await animation_player.animation_finished
	
	# Depois do Start, toca Idle em loop
	if animation_player.has_animation("Idle"):
		animation_player.play("Idle")

func _play_animation(anim_name: String) -> void:
	"""Toca uma animação se existir"""
	if animation_player and animation_player.has_animation(anim_name):
		animation_player.play(anim_name)


func _drop_xp() -> void:
	"""Spawna orbs de XP ao morrer"""
	if xp_reward <= 0:
		return
	
	# Carrega cena do orb
	if not ResourceLoader.exists("res://items/xp_orb.tscn"):
		# Fallback: adiciona XP diretamente
		if XPManager:
			XPManager.add_xp(xp_reward)
		return
	
	var orb_scene = load("res://items/xp_orb.tscn")
	
	# Determina quantos orbs spawnar (1 orb por cada 10 XP, máx 5)
	var orb_count = clamp(xp_reward / 10, 1, 5)
	var xp_per_orb = xp_reward / orb_count
	
	for i in range(orb_count):
		var orb = orb_scene.instantiate()
		orb.xp_value = xp_per_orb
		
		# Posição com spread aleatório
		var offset = Vector3(
			randf_range(-0.8, 0.8),
			0.5,
			randf_range(-0.8, 0.8)
		)
		
		get_tree().current_scene.add_child(orb)
		orb.global_position = global_position + offset
	
	# Dropa moedas também
	_drop_coins()


func _drop_coins() -> void:
	"""Spawna moedas ao morrer"""
	if not ResourceLoader.exists("res://items/coin.tscn"):
		return
	
	var coin_scene = load("res://items/coin.tscn")
	
	# Calcula valor baseado no tempo decorrido
	var time_elapsed: float = 0.0
	if GameManager:
		time_elapsed = 900.0 - float(GameManager.time_remaining)
	
	var coin_value = 2 + int(time_elapsed / 60.0 * 0.5)
	
	# Spawna 1-2 moedas
	var coin_count = 1 + (randi() % 2)  # 1 ou 2 moedas
	var value_per_coin = maxi(1, coin_value / coin_count)
	
	for i in range(coin_count):
		var coin = coin_scene.instantiate()
		coin.coin_value = value_per_coin
		
		# Posição com spread aleatório (diferente do XP)
		var angle = randf() * TAU
		var offset = Vector3(
			cos(angle) * 0.5,
			0.4,
			sin(angle) * 0.5
		)
		
		get_tree().current_scene.add_child(coin)
		coin.global_position = global_position + offset
