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
@onready var mesh: MeshInstance3D = $MeshInstance3D

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

	# Configura NavigationAgent
	if navigation_agent:
		navigation_agent.path_desired_distance = 0.5
		navigation_agent.target_desired_distance = 0.5
		navigation_agent.max_speed = speed

	# Encontra o player
	call_deferred("_find_player")

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

	# Pega ou cria material
	var material: StandardMaterial3D = null
	if mesh.get_surface_override_material(0) is StandardMaterial3D:
		material = mesh.get_surface_override_material(0)
	else:
		material = StandardMaterial3D.new()
		mesh.set_surface_override_material(0, material)

	if not material:
		return

	# Flash vermelho
	material.albedo_color = Color.RED

	# Volta ao normal
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(material):
		material.albedo_color = Color.WHITE
