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
var dash_system: DashSystem = null

# Weapon slot
var current_weapon: BaseWeapon = null

# Controle de rotação
var camera_rotation: float = 0.0

# Estado de movimento
var is_moving: bool = false
var is_sprinting: bool = false
var is_dashing: bool = false
var was_on_floor: bool = true
var initialization_frames: int = 0

# Modificadores de velocidade (para LMG, etc.)
var speed_multiplier: float = 1.0

# Estado de arma especial
var is_scoped: bool = false  # Para sniper
var is_holding_trigger: bool = false  # Para full auto (SMG/LMG)

# === PAUSE MENU SYSTEM ===
var pause_menu: PauseMenu = null
var reset_indicator: ResetHoldIndicator = null
var game_over_screen: GameOverScreen = null
var reset_hold_time: float = 0.0
const RESET_HOLD_DURATION: float = 1.5
const RESET_HOLD_THRESHOLD: float = 0.2  # Tempo antes de mostrar indicador (para não conflitar com reload)


# Viewmodel Overlay System
var viewmodel_viewport: SubViewport = null
var viewmodel_camera: Camera3D = null

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
	if camera:
		if not camera_effects:
			camera_effects = CameraEffects.new()
			camera.add_child(camera_effects)
		
		# EXCLUI a layer 2 (armas) da câmera principal
		camera.cull_mask &= ~(1 << 1)
		
		# Setup do ViewModel Overlay (sempre no topo)
		_setup_viewmodel_overlay()

	# Configura aim assist
	_setup_aim_assist()

	# Configura dash system
	_setup_dash_system()

	# Conecta signals de stats
	if stats:
		stats.health_changed.connect(_on_health_changed)
		stats.damage_taken.connect(_on_damage_taken)

func _setup_viewmodel_overlay() -> void:
	"""Cria uma viewport transparente por cima da tela para as armas"""
	# Primeiro remove se já existir (para evitar duplicatas em re-equips ou hot-reload)
	var old = get_node_or_null("ViewModelLayer")
	if old: old.queue_free()

	# CanvasLayer para o ViewModel (Desenha por cima do mundo)
	var canvas = CanvasLayer.new()
	canvas.name = "ViewModelLayer"
	canvas.layer = 1 # Foreground das armas
	add_child(canvas)
	
	# Container que estica na tela toda
	var container = SubViewportContainer.new()
	container.name = "ViewModelContainer"
	container.stretch = true
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(container)
	
	# Viewport transparente
	viewmodel_viewport = SubViewport.new()
	viewmodel_viewport.name = "ViewModelViewport"
	viewmodel_viewport.transparent_bg = true
	viewmodel_viewport.handle_input_locally = false
	viewmodel_viewport.gui_disable_input = true
	viewmodel_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	
	# Garante que a viewport tenha o tamanho da tela atual e responda a mudanças
	viewmodel_viewport.size = DisplayServer.window_get_size()
	
	# COMPARTILHA O MUNDO
	# Isso é vital para iluminação
	viewmodel_viewport.own_world_3d = false
	viewmodel_viewport.world_3d = camera.get_world_3d()
	container.add_child(viewmodel_viewport)
	
	# Câmera secundária que só vê Layer 2
	viewmodel_camera = Camera3D.new()
	viewmodel_camera.name = "ViewModelCamera"
	viewmodel_camera.cull_mask = (1 << 1) # Só Layer 2
	viewmodel_camera.near = 0.05
	viewmodel_camera.far = 100.0
	viewmodel_camera.fov = camera.fov
	
	# === ENVIRONMENT DEDICADO PARA ARMAS ===
	# Criamos um ambiente que ignora o fog do mundo e garante luz ambiente
	var weapon_env = Environment.new()
	weapon_env.background_mode = Environment.BG_CANVAS
	weapon_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	weapon_env.ambient_light_color = Color.WHITE
	weapon_env.ambient_light_energy = 0.5 # Luz de preenchimento constante
	weapon_env.fog_enabled = false # JAMAIS usar fog nas armas
	weapon_env.volumetric_fog_enabled = false
	viewmodel_camera.environment = weapon_env
	
	viewmodel_viewport.add_child(viewmodel_camera)
	
	# === VIEWMODEL LIGHTING RIG (Studio Lighting) ===
	# Como as armas estão na Layer 2, elas não recebem luz do mundo real.
	# Criamos um rig de 3 pontos para garantir volume e visibilidade.
	
	# 1. Key Light (Principal - Lateral Superior)
	var key_light = OmniLight3D.new()
	key_light.name = "KeyLight"
	key_light.light_cull_mask = (1 << 1)
	key_light.light_energy = 3.0 # Aumentada para garantir brilho
	key_light.omni_range = 5.0
	key_light.position = Vector3(1.0, 1.0, 0.5)
	viewmodel_camera.add_child(key_light)
	
	# 2. Front Light (Luz frontal direta)
	var front_light = OmniLight3D.new()
	front_light.name = "FrontLight"
	front_light.light_cull_mask = (1 << 1)
	front_light.light_energy = 2.0
	front_light.omni_range = 5.0
	front_light.position = Vector3(0, 0, 1.0)
	viewmodel_camera.add_child(front_light)
	
	# 3. Rim Light (Luz de contorno traseira)
	var rim_light = OmniLight3D.new()
	rim_light.name = "RimLight"
	rim_light.light_cull_mask = (1 << 1)
	rim_light.light_energy = 4.0 # Força o 'brilho' nas bordas
	rim_light.omni_range = 10.0
	rim_light.position = Vector3(0, 0, -2.0)
	viewmodel_camera.add_child(rim_light)
	
	print("[Player] ViewModel Lighting Rig (3-Point) configurado.")


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


func _setup_dash_system() -> void:
	"""Configura o sistema de dash"""
	dash_system = DashSystem.new()
	dash_system.name = "DashSystem"
	add_child(dash_system)
	dash_system.setup(self, camera_effects)

	# Conecta signals do dash
	dash_system.dash_started.connect(_on_dash_started)
	dash_system.dash_ended.connect(_on_dash_ended)

	# Setup pause menu
	_setup_pause_menu()

	# Setup reset hold indicator
	_setup_reset_indicator()
	
	# Setup game over screen
	_setup_game_over_screen()


func _input(event: InputEvent) -> void:
	# Mouse look
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mouse_input = event.relative

		# Aplica aim assist ao input
		if aim_assist:
			mouse_input = aim_assist.apply_to_mouse_input(mouse_input)

		# Modificador de sensibilidade (para sniper scope)
		var sens_multiplier = 1.0
		if current_weapon and current_weapon.has_method("get_sensitivity_multiplier"):
			sens_multiplier = current_weapon.get_sensitivity_multiplier()

		var effective_sensitivity = mouse_sensitivity * sens_multiplier

		# Rotação horizontal (yaw)
		rotate_y(-mouse_input.x * effective_sensitivity)

		# Rotação vertical (pitch)
		camera_rotation -= mouse_input.y * effective_sensitivity
		camera_rotation = clamp(camera_rotation, -PI/2, PI/2)

		if camera:
			camera.rotation.x = camera_rotation

		# Envia input para weapon sway
		if current_weapon and current_weapon.has_method("add_mouse_sway"):
			current_weapon.add_mouse_sway(event.relative)

	# ESC para pause menu
	if event.is_action_pressed("ui_cancel"):
		if GameManager.current_state == GameManager.GameState.PLAYING:
			_open_pause_menu()
		elif GameManager.current_state == GameManager.GameState.PAUSED:
			_close_pause_menu()


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
	var base_speed = sprint_speed if is_sprinting else walk_speed
	var current_speed = base_speed * speed_multiplier  # Aplica modificador (LMG, etc.)

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

	# Processar dash input
	_process_dash_input()
	
	# === SINCRONIZA VIEWMODEL CAMERA ===
	# A câmera do overlay deve sempre seguir a câmera principal
	if viewmodel_camera and camera:
		viewmodel_camera.global_transform = camera.global_transform


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

	# Não pode atirar durante dash
	if is_dashing:
		return

	# === SCOPE (Right Click) ===
	if Input.is_action_just_pressed("aim"):
		if current_weapon.has_method("toggle_scope"):
			current_weapon.toggle_scope()
			is_scoped = current_weapon.is_using_scope() if current_weapon.has_method("is_using_scope") else false

	# === SHOOT ===
	# Verifica se é arma que precisa de spinup (LMG)
	var is_lmg = current_weapon.has_method("start_firing")

	if is_lmg:
		# LMG: Start/Stop firing
		if Input.is_action_just_pressed("shoot"):
			current_weapon.start_firing()
			is_holding_trigger = true

		if Input.is_action_just_released("shoot"):
			current_weapon.stop_firing()
			is_holding_trigger = false

		# LMG dispara continuamente quando ready
		if is_holding_trigger and current_weapon.has_method("is_ready_to_fire"):
			if current_weapon.is_ready_to_fire():
				current_weapon.shoot()
		elif is_holding_trigger and current_weapon.has_method("shoot"):
			current_weapon.shoot()
	else:
		# Armas normais
		if Input.is_action_pressed("shoot"):
			if current_weapon.has_method("shoot"):
				current_weapon.shoot()

	# Reload - só dispara se não estiver em modo de hold para reset
	if Input.is_action_just_pressed("reload") and reset_hold_time < RESET_HOLD_THRESHOLD:
		if current_weapon.has_method("reload"):
			current_weapon.reload()


func _process_dash_input() -> void:
	"""Processa input de dash (Ctrl)"""
	if not dash_system:
		return

	# Ctrl para dash
	if Input.is_action_just_pressed("dash"):
		_perform_dash()


func _perform_dash() -> void:
	"""Executa o dash na direção do movimento"""
	if not dash_system or not dash_system.can_dash():
		return

	# Calcula direção do dash baseada no input
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction: Vector3

	if input_dir.length() > 0.1:
		# Dash na direção do movimento
		direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	else:
		# Dash para frente se não tiver input
		direction = -transform.basis.z

	dash_system.execute_dash(direction)


func _on_dash_started(_direction: Vector3) -> void:
	"""Callback quando dash inicia"""
	is_dashing = true


func _on_dash_ended() -> void:
	"""Callback quando dash termina"""
	is_dashing = false


func equip_weapon(weapon: Node3D) -> void:
	"""Equipa uma arma - agora corretamente vinculada à câmera"""
	# Remove arma atual imediatamente do cenário
	if current_weapon:
		if current_weapon.get_parent():
			current_weapon.get_parent().remove_child(current_weapon)
		current_weapon.queue_free()

	current_weapon = weapon

	# Adiciona como filho da CÂMERA para que a arma siga o olhar do player
	if weapon.get_parent() != camera:
		if weapon.get_parent():
			weapon.get_parent().remove_child(weapon)
		camera.add_child(weapon)
	
	# Coloca a arma na Layer 2 (Viewmodel) recursivamente
	print("[Player] --- TREE DUMP: ", weapon.name, " ---")
	weapon.print_tree()
	_set_layer_recursive(weapon, 2)
	
	# Verificação final: imprime o estado de TODAS as meshes
	print("[Player] --- FINAL STATE CHECK ---")
	_verify_layer_state(weapon)
	
	print("[Player] Arma equipada (Layer 2)")


func _set_layer_recursive(node: Node, layer: int, parent_hidden: bool = false) -> void:
	"""Define a layer de visualização e DESATIVA braços/corpo da hierarquia com Whitelist"""
	var n = node.name.to_lower()
	
	# Log de TODOS os nós para diagnóstico
	# printerr("[NODE] ", node.name, " (", node.get_class(), ") parent_hidden=", parent_hidden)
	
	# Pega keywords da arma atual para whitelist
	var weapon_keywords = []
	if current_weapon and "weapon_mesh_keywords" in current_weapon:
		weapon_keywords = current_weapon.weapon_mesh_keywords
	
	# Verifica se é uma parte proibida (Blacklist) - ATUALIZADO com mais palavras
	var is_blacklist = "body" in n or "head" in n or "arm" in n or "hand" in n or "finger" in n or "man" in n or "skeleton" in n or "mensch" in n or "fullbody" in n or "pole" in n
	
	# Verifica se é a arma (Whitelist - se houver keywords)
	var is_whitelist = false
	if weapon_keywords.size() > 0:
		for kw in weapon_keywords:
			if kw.to_lower() in n:
				is_whitelist = true
				break
	else:
		# Se não tem keywords, fallback para lógica antiga (assume que tudo visível que não é blacklist é arma)
		is_whitelist = not is_blacklist
	
	# Nodes que devem ser escondidos: se forem blacklist ou se o pai estiver escondido
	var should_hide = parent_hidden or is_blacklist or (weapon_keywords.size() > 0 and not is_whitelist and node is VisualInstance3D and node.get_parent() is Skeleton3D)
	
	# Trata QUALQUER Node3D (não só VisualInstance3D) para esconder braços
	if node is Node3D:
		if should_hide:
			printerr("[LAYER] HIDE Node3D: ", node.name, " (", node.get_class(), ")")
			node.visible = false
		elif node is VisualInstance3D:
			if is_whitelist:
				printerr("[LAYER] SHOW: ", node.name, " -> Layer 2")
				node.layers = (1 << (layer - 1)) # Move para Overlay (Layer 2)
			else:
				printerr("[LAYER] SKIP: ", node.name, " (stays Layer 1)")
				node.layers = 1  # Garante Layer 1
	
	# Propaga o estado de 'escondido'
	for child in node.get_children():
		_set_layer_recursive(child, layer, should_hide)


func _verify_layer_state(node: Node) -> void:
	"""Verifica e imprime o estado final de todas as meshes"""
	if node is VisualInstance3D:
		var mesh = node as VisualInstance3D
		printerr("[VERIFY] ", mesh.name, " visible=", mesh.visible, " layer=", mesh.layers)
	
	for child in node.get_children():
		_verify_layer_state(child)


func take_damage(amount: float) -> void:
	"""Aplica dano ao jogador"""
	# Invulnerável durante dash
	if dash_system and dash_system.is_player_invulnerable():
		return

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


# === MÉTODOS PARA ARMAS ESPECIAIS ===

func set_speed_multiplier(multiplier: float) -> void:
	"""Define multiplicador de velocidade (usado por LMG, etc.)"""
	speed_multiplier = clamp(multiplier, 0.1, 2.0)


func reset_speed_multiplier() -> void:
	"""Reseta multiplicador de velocidade para 1.0"""
	speed_multiplier = 1.0


func get_speed_multiplier() -> float:
	"""Retorna multiplicador atual"""
	return speed_multiplier


func is_player_scoped() -> bool:
	"""Retorna se jogador está usando scope"""
	return is_scoped


# === PAUSE MENU SYSTEM ===

func _setup_pause_menu() -> void:
	"""Configura o pause menu"""
	pause_menu = PauseMenu.new()
	pause_menu.name = "PauseMenu"
	get_tree().root.add_child.call_deferred(pause_menu)
	
	# Conecta signals
	pause_menu.resume_requested.connect(_on_pause_resume)
	pause_menu.reset_requested.connect(_on_pause_reset)
	pause_menu.main_menu_requested.connect(_on_pause_main_menu)


func _setup_reset_indicator() -> void:
	"""Configura o indicador de hold R para reset"""
	reset_indicator = ResetHoldIndicator.new()
	reset_indicator.name = "ResetHoldIndicator"
	get_tree().root.add_child.call_deferred(reset_indicator)
	
	# Conecta signal
	reset_indicator.reset_completed.connect(_on_reset_hold_completed)


func _setup_game_over_screen() -> void:
	"""Configura a tela de game over"""
	game_over_screen = GameOverScreen.new()
	game_over_screen.name = "GameOverScreen"
	get_tree().root.add_child.call_deferred(game_over_screen)


func _open_pause_menu() -> void:
	"""Abre o pause menu"""
	if not pause_menu:
		return
	
	GameManager.pause_game()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	pause_menu.show_pause_menu()


func _close_pause_menu() -> void:
	"""Fecha o pause menu"""
	if not pause_menu:
		return
	
	pause_menu.hide_pause_menu()
	GameManager.resume_game()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_pause_resume() -> void:
	"""Callback quando Resume é pressionado"""
	_close_pause_menu()


func _on_pause_reset() -> void:
	"""Callback quando Reset é confirmado no pause menu"""
	pause_menu.hide_pause_menu()
	GameManager.reset_run()


func _on_pause_main_menu() -> void:
	"""Callback quando Main Menu é pressionado"""
	pause_menu.hide_pause_menu()
	GameManager.reset_game()
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")


func _process(delta: float) -> void:
	# Sincroniza a câmera do Viewmodel com a câmera principal
	if viewmodel_camera and camera:
		viewmodel_camera.global_transform = camera.global_transform
		viewmodel_camera.fov = camera.fov

	# Processa input de hold R para reset
	_process_reset_hold_input(delta)


func _process_reset_hold_input(delta: float) -> void:
	"""Processa o hold R para reset da run"""
	# Não processa em telas especiais ou pausado
	if _is_in_special_screen():
		if reset_hold_time > 0:
			reset_hold_time = 0.0
			if reset_indicator:
				reset_indicator.hide_indicator()
		return
	
	# Só processa se estiver jogando
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	
	# Verifica se R está pressionado (mesma tecla do reload)
	if Input.is_action_pressed("reload"):
		var was_below_threshold = reset_hold_time < RESET_HOLD_THRESHOLD
		reset_hold_time += delta
		
		# Só mostra indicador após threshold (para não conflitar com reload)
		if was_below_threshold and reset_hold_time >= RESET_HOLD_THRESHOLD and reset_indicator:
			reset_indicator.show_indicator()
		
		# Atualiza progresso (considerando que o tempo efetivo começa após threshold)
		if reset_hold_time >= RESET_HOLD_THRESHOLD and reset_indicator:
			var effective_time = reset_hold_time - RESET_HOLD_THRESHOLD
			var progress = effective_time / (RESET_HOLD_DURATION - RESET_HOLD_THRESHOLD)
			reset_indicator.progress = clamp(progress, 0.0, 1.0)
			reset_indicator.queue_redraw()
			
			if progress >= 1.0:
				_on_reset_hold_completed()
	else:
		# Soltou a tecla
		if reset_hold_time > 0:
			reset_hold_time = 0.0
			if reset_indicator:
				reset_indicator.hide_indicator()


func _on_reset_hold_completed() -> void:
	"""Callback quando o hold R completa"""
	reset_hold_time = 0.0
	if reset_indicator:
		reset_indicator.hide_indicator()
	GameManager.reset_run()


func _is_in_special_screen() -> bool:
	"""Verifica se está em uma tela especial (upgrade, level up, etc.)"""
	# Verifica se tela de upgrade está aberta
	if UpgradeManager and UpgradeManager.upgrade_ui and UpgradeManager.upgrade_ui.visible:
		return true
	
	# Verifica se level up screen está aberta
	var level_up = get_tree().root.get_node_or_null("LevelUpScreen")
	if level_up and level_up.visible:
		return true
	

	
	return false


func _exit_tree() -> void:
	"""Limpa elementos de UI adicionados ao root"""
	if pause_menu:
		pause_menu.queue_free()
	if game_over_screen:
		game_over_screen.queue_free()
	if reset_indicator:
		reset_indicator.queue_free()
