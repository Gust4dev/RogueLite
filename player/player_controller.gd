extends CharacterBody3D

# Player Controller - FPS controller com movimento, mouse look e combat

class_name PlayerController

# Movimento
@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var jump_velocity: float = 4.5
@export var mouse_sensitivity: float = 0.002

# Gravidade
@export var gravity: float = 9.8

# Referências aos nós filhos
@onready var camera: Camera3D = $Camera3D
@onready var stats: PlayerStats = $PlayerStats
@onready var camera_effects: CameraEffects = $Camera3D/CameraEffects

# Weapon slot
var current_weapon: Node3D = null

# Controle de rotação
var camera_rotation: float = 0.0

func _ready() -> void:
	# Captura o mouse
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Adiciona ao grupo "player"
	add_to_group("player")

	# Configura stats se não estiver configurado
	if not stats:
		stats = PlayerStats.new()
		add_child(stats)

	# Configura camera effects se não estiver configurado
	if camera and not camera_effects:
		camera_effects = CameraEffects.new()
		camera.add_child(camera_effects)

func _input(event: InputEvent) -> void:
	# Mouse look
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Rotação horizontal (yaw)
		rotate_y(-event.relative.x * mouse_sensitivity)

		# Rotação vertical (pitch)
		camera_rotation -= event.relative.y * mouse_sensitivity
		camera_rotation = clamp(camera_rotation, -PI/2, PI/2)

		if camera:
			camera.rotation.x = camera_rotation

	# ESC para liberar mouse (debug)
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

# Controle de inicialização
var initialization_frames: int = 0

func _physics_process(delta: float) -> void:
	# Segurança inicial para evitar teleportação por colisão
	if initialization_frames < 2:
		initialization_frames += 1
		velocity = Vector3.ZERO
		move_and_slide()
		return

	# Verifica se está morto
	if stats and not stats.is_alive:
		return

	# Aplica gravidade
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	# Movimento
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	# Sprint
	var current_speed = sprint_speed if Input.is_action_pressed("sprint") else walk_speed

	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed * delta * 10)
		velocity.z = move_toward(velocity.z, 0, current_speed * delta * 10)

	# Atualiza movimento
	move_and_slide()

	# Processar weapon input
	_process_weapon_input()

func _process_weapon_input() -> void:
	"""Processa inputs relacionados às armas"""
	if not current_weapon:
		return

	# Shoot
	if Input.is_action_pressed("shoot"):
		if current_weapon.has_method("shoot"):
			current_weapon.shoot()

	# Reload
	if Input.is_action_just_pressed("reload"):
		if current_weapon.has_method("reload"):
			current_weapon.reload()

	# Melee
	if Input.is_action_just_pressed("melee"):
		if current_weapon.has_method("melee"):
			current_weapon.melee()

func equip_weapon(weapon: Node3D) -> void:
	"""Equipa uma arma"""
	# Remove arma atual
	if current_weapon:
		current_weapon.queue_free()

	current_weapon = weapon

	# Adiciona como filho da câmera
	if camera:
		if weapon.get_parent() != camera:
			if weapon.get_parent():
				weapon.get_parent().remove_child(weapon)
			camera.add_child(weapon)

		# Posiciona a arma centralizada (lógica)
		# O deslocamento visual é tratado dentro da cena da própria arma
		weapon.position = Vector3.ZERO
		weapon.rotation = Vector3.ZERO

func take_damage(amount: float) -> void:
	"""Aplica dano ao jogador"""
	if stats:
		stats.take_damage(amount)

		# Screen shake ao receber dano
		if camera_effects:
			camera_effects.apply_screen_shake(0.1)

func get_camera() -> Camera3D:
	"""Retorna a câmera do jogador"""
	return camera
