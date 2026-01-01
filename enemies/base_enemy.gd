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

func _ready() -> void:
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

		# Olha para o player
		look_at(Vector3(target.global_position.x, global_position.y, target.global_position.z))

		# Ataca
		if can_attack:
			attack()
	else:
		# Se está longe, segue o player
		if navigation_agent:
			navigation_agent.target_position = target.global_position

			# Pega próxima posição do path
			var next_position = navigation_agent.get_next_path_position()
			var direction = (next_position - global_position).normalized()

			# Move em direção ao target
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed

			# Olha para onde está indo
			if direction.length() > 0.1:
				look_at(Vector3(global_position.x + direction.x, global_position.y, global_position.z + direction.z))

	# Atualiza movimento
	move_and_slide()

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

	died.emit()

	# Desabilita física
	set_physics_process(false)

	# Animação de morte (fade out simples)
	if mesh:
		var tween = create_tween()
		tween.tween_property(mesh, "transparency", 1.0, 0.5)
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
		target.take_damage(damage)

	attack_performed.emit()

func is_alive() -> bool:
	"""Retorna se o inimigo está vivo"""
	return _is_alive


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
