extends CharacterBody3D

# Player Controller - FPS controller com movimento, mouse look e combat
# Integra todos os sistemas de gunplay: recoil, sway, animações, aim assist

class_name PlayerController

# === MOVIMENTO ===
@export_group("Movement")
@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var jump_velocity: float = 4.5
@export var mouse_sensitivity: float = 0.002

# Gravidade
@export var gravity: float = 9.8

# === REFERÊNCIAS ===
@onready var camera: Camera3D = $Camera3D
@onready var stats: PlayerStats = $PlayerStats
@onready var camera_effects: CameraEffects = $Camera3D/CameraEffects

# Sub-sistemas
var aim_assist: AimAssist = null

# Weapon slot
var current_weapon: BaseWeapon = null

# Controle de rotação
var camera_rotation: float = 0.0

# Estado de movimento
var is_moving: bool = false
var is_sprinting: bool = false
var was_on_floor: bool = true
var initialization_frames: int = 0


func _ready() -> void:
	# Captura o mouse
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Adiciona ao grupo "player"
	add_to_group("player")

	# Configura stats
	if not stats:
		stats = PlayerStats.new()
		add_child(stats)

	# Configura camera effects
	if camera and not camera_effects:
		camera_effects = CameraEffects.new()
		camera.add_child(camera_effects)

	# Configura aim assist
	_setup_aim_assist()

	# Conecta signals de stats
	if stats:
		stats.health_changed.connect(_on_health_changed)
		stats.damage_taken.connect(_on_damage_taken)


func _setup_aim_assist() -> void:
	"""Configura o sistema de aim assist"""
	aim_assist = AimAssist.new()
	aim_assist.name = "AimAssist"
	add_child(aim_assist)
	aim_assist.setup(self, camera)

	# Configura aim assist MUITO leve
	aim_assist.enabled = true
	aim_assist.magnetism_strength = 0.1      # Bem leve
	aim_assist.slowdown_factor = 0.8          # Slowdown sutil
	aim_assist.detection_radius = 80.0        # Raio moderado
	aim_assist.max_correction_angle = 2.0     # Correção mínima


func _input(event: InputEvent) -> void:
	# Mouse look
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mouse_input = event.relative

		# Aplica aim assist ao input
		if aim_assist:
			mouse_input = aim_assist.apply_to_mouse_input(mouse_input)

		# Rotação horizontal (yaw)
		rotate_y(-mouse_input.x * mouse_sensitivity)

		# Rotação vertical (pitch)
		camera_rotation -= mouse_input.y * mouse_sensitivity
		camera_rotation = clamp(camera_rotation, -PI/2, PI/2)

		if camera:
			camera.rotation.x = camera_rotation

		# Envia input para weapon sway
		if current_weapon and current_weapon.has_method("add_mouse_sway"):
			current_weapon.add_mouse_sway(event.relative)

	# ESC para liberar mouse (debug)
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


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

	# Armazena estado anterior
	var prev_on_floor = is_on_floor()

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
	is_sprinting = Input.is_action_pressed("sprint") and direction.length() > 0
	var current_speed = sprint_speed if is_sprinting else walk_speed

	# Atualiza estado de movimento
	is_moving = direction.length() > 0.1

	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed * delta * 10)
		velocity.z = move_toward(velocity.z, 0, current_speed * delta * 10)

	# Atualiza movimento
	move_and_slide()

	# Verifica aterrisagem
	_check_landing(prev_on_floor)

	# Atualiza sistemas
	_update_movement_systems()

	# Processar weapon input
	_process_weapon_input()


func _check_landing(prev_on_floor: bool) -> void:
	"""Verifica e processa aterrisagem"""
	if camera_effects:
		camera_effects.check_landing(is_on_floor(), velocity.y)

	# Shake de landing
	if is_on_floor() and not prev_on_floor:
		if camera_effects:
			camera_effects.shake_land(velocity.y)


func _update_movement_systems() -> void:
	"""Atualiza sistemas baseados no movimento"""
	# Atualiza camera effects
	if camera_effects:
		camera_effects.set_movement_state(is_moving, is_sprinting, velocity.length())
		camera_effects.set_in_air(not is_on_floor())

	# Atualiza weapon
	if current_weapon and current_weapon.has_method("set_movement_state"):
		current_weapon.set_movement_state(is_moving, is_sprinting)


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


func _on_health_changed(current_health: float, max_health: float) -> void:
	"""Callback quando vida muda"""
	var health_percent = (current_health / max_health) * 100.0
	if camera_effects:
		camera_effects.set_health(health_percent)


func _on_damage_taken(amount: float) -> void:
	"""Callback quando toma dano"""
	var damage_percent = amount / stats.max_health if stats else 0.1
	if camera_effects:
		camera_effects.on_damage(damage_percent)


func get_camera() -> Camera3D:
	"""Retorna a câmera do jogador"""
	return camera


func get_aim_assist() -> AimAssist:
	"""Retorna o sistema de aim assist"""
	return aim_assist


func set_aim_assist_enabled(enabled: bool) -> void:
	"""Ativa/desativa aim assist"""
	if aim_assist:
		aim_assist.set_enabled(enabled)
