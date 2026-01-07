extends Node3D

# Base Weapon - Classe base para todas as armas
# Sistema avançado de recoil, sway e feedback visual

class_name BaseWeapon

# Signals
signal weapon_fired()
signal ammo_changed(current_ammo: int, magazine_size: int)
signal reload_started()
signal reload_finished()
signal weapon_empty()
signal hit_enemy(enemy: Node3D, damage: float, is_kill: bool)

# === STATS BÁSICOS ===
@export_group("Stats")
@export var damage: float = 10.0
@export var fire_rate: float = 0.2
@export var reload_time: float = 1.5
@export var magazine_size: int = 12

# === CONFIGURAÇÃO DE RECOIL DA ARMA (kickback visual) ===
@export_group("Weapon Recoil")
@export var kickback_position: Vector3 = Vector3(0.0, 0.02, 0.08)
@export var kickback_rotation: Vector3 = Vector3(-3.0, 1.5, 2.0)
@export var position_randomness: Vector3 = Vector3(0.005, 0.005, 0.01)
@export var rotation_randomness: Vector3 = Vector3(0.5, 1.0, 0.5)
@export var kickback_speed: float = 15.0
@export var return_speed: float = 8.0
@export var shooting_return_speed: float = 4.0

# === CONFIGURAÇÃO DE RECOIL DA CÂMERA ===
@export_group("Camera Recoil")
@export var camera_recoil_horizontal: float = 0.5
@export var camera_recoil_vertical: float = 1.5

# === CONFIGURAÇÃO DE SWAY ===
@export_group("Weapon Sway")
@export var sway_enabled: bool = true
@export var mouse_sway_amount: Vector2 = Vector2(0.002, 0.002)
@export var mouse_sway_max: Vector2 = Vector2(0.05, 0.03)
@export var movement_sway_amount: float = 0.02

# === DEBUG / SETUP ===
@export_group("Debug")
@export var use_auto_calibration: bool = false # Default false para não quebrar setups manuais

# Ammo
var current_ammo: int = 12

# Controle de disparo
var can_shoot: bool = true
var is_reloading: bool = false
var fire_timer: float = 0.0
var is_shooting: bool = false  # Para detectar tiro contínuo

# Melee
@export var melee_damage: float = 25.0
@export var melee_range: float = 2.0
@export var melee_cooldown: float = 0.8
var can_melee: bool = true
var melee_timer: float = 0.0

# Nomes das animações (podem ser sobrescritos pelas classes filhas)
var anim_shoot: String = "Shoot"
var anim_reload: String = "Reload"
var anim_draw: String = "Draw"
var anim_hide: String = "Hide"
var anim_idle: String = ""  # Deixar vazio se não houver idle

# Velocidade das animações (1.0 = normal, 2.0 = dobro)
var anim_speed_shoot: float = 2.0  # Acelera animação de tiro
var anim_speed_reload: float = 1.5  # Acelera reload

# Referências
@onready var raycast: RayCast3D = $RayCast3D
@onready var muzzle_flash: Node3D = $MuzzleFlash

# Mesh e animação (buscados dinamicamente)
var mesh: Node3D = null
var animation_player: AnimationPlayer = null

# Camera do player
var player_camera: Camera3D = null
var camera_effects: CameraEffects = null

# Sub-sistemas
var weapon_recoil: WeaponRecoil = null
var weapon_sway: WeaponSway = null

# Posição original
var original_position: Vector3 = Vector3.ZERO
var original_rotation: Vector3 = Vector3.ZERO


func _ready() -> void:
	# Salva posição original
	original_position = position
	original_rotation = rotation

	# Inicializa ammo
	current_ammo = magazine_size

	# Adiciona ao grupo weapons
	add_to_group("weapons")

	# Buscar mesh dinamicamente
	# Tenta encontrar por nomes comuns primeiro
	var mesh_names = ["PistolMesh", "RevolverMesh", "SMGMesh", "ShotgunMesh", "SniperMesh", "LMGMesh", "WeaponMesh", "Mesh"]
	for m_name in mesh_names:
		mesh = get_node_or_null(m_name)
		if mesh: break
		
	if not mesh:
		for child in get_children():
			if child is Node3D and not (child is RayCast3D or "Muzzle" in child.name or "Recoil" in child.name or "Sway" in child.name):
				mesh = child
				break

	# Buscar AnimationPlayer dentro do mesh (GLBs importados geralmente têm um)
	if mesh:
		animation_player = mesh.find_child("AnimationPlayer", true, false)
		
		# Auto-calibra apenas se solicitado
		if use_auto_calibration:
			_auto_calibrate_mesh()
			
		# Debug: log mesh info para ajudar no posicionamento
		_log_mesh_debug_info()

	# Configura raycast
	if raycast:
		raycast.enabled = true
		raycast.target_position = Vector3(0, 0, -100)

	# Esconde muzzle flash inicialmente
	if muzzle_flash:
		muzzle_flash.visible = false

	# Obtém a câmera do player
	_find_player_camera()

	# Configura sub-sistemas
	_setup_subsystems()

	# Emite signal inicial de ammo
	ammo_changed.emit(current_ammo, magazine_size)

	# Notify UpgradeManager of this weapon (deferred to ensure all systems are ready)
	call_deferred("_notify_upgrade_manager")


func _setup_subsystems() -> void:
	"""Configura os sub-sistemas de recoil e sway"""

	# Weapon Recoil
	weapon_recoil = WeaponRecoil.new()
	weapon_recoil.name = "WeaponRecoil"
	add_child(weapon_recoil)

	# Configura parâmetros do recoil
	weapon_recoil.kickback_position = kickback_position
	weapon_recoil.kickback_rotation = kickback_rotation
	weapon_recoil.position_randomness = position_randomness
	weapon_recoil.rotation_randomness = rotation_randomness
	weapon_recoil.kickback_speed = kickback_speed
	weapon_recoil.return_speed = return_speed
	weapon_recoil.shooting_return_speed = shooting_return_speed

	# Weapon Sway
	if sway_enabled:
		weapon_sway = WeaponSway.new()
		weapon_sway.name = "WeaponSway"
		add_child(weapon_sway)
		weapon_sway.setup(self)

		# Configura parâmetros do sway
		weapon_sway.mouse_sway_amount = mouse_sway_amount
		weapon_sway.mouse_sway_max = mouse_sway_max
		weapon_sway.movement_sway_amount = movement_sway_amount


func _process(delta: float) -> void:
	# Atualiza fire timer
	if fire_timer > 0:
		fire_timer -= delta
		if fire_timer <= 0:
			can_shoot = true

	# Detecta se parou de atirar
	if is_shooting and can_shoot:
		is_shooting = false
		if weapon_recoil:
			weapon_recoil.set_shooting_state(false)

	# Atualiza melee timer
	if melee_timer > 0:
		melee_timer -= delta
		if melee_timer <= 0:
			can_melee = true

	# Aplica sway à posição (combinado com recoil)
	_apply_combined_transforms()


func _apply_combined_transforms() -> void:
	"""Aplica todas as transformações combinadas"""
	if not weapon_recoil:
		return

	# O recoil já é aplicado pelo próprio sistema WeaponRecoil
	# Aqui só adicionamos o sway se existir
	if weapon_sway and sway_enabled:
		var sway_offset = weapon_sway.get_total_offset()
		var sway_rotation = weapon_sway.get_total_rotation()

		# Adiciona sway à posição atual (já com recoil)
		position = weapon_recoil.current_position + sway_offset
		rotation = weapon_recoil.current_rotation + sway_rotation

func _find_player_camera() -> void:
	"""Encontra a câmera do player"""
	var parent = get_parent()
	if parent is Camera3D:
		player_camera = parent
		camera_effects = player_camera.get_node_or_null("CameraEffects")


func shoot() -> void:
	"""Dispara a arma"""
	# Verifica se pode atirar
	if not can_shoot or is_reloading:
		return

	# Verifica ammo
	if current_ammo <= 0:
		weapon_empty.emit()
		reload()
		return

	# Decrementa ammo
	current_ammo -= 1
	ammo_changed.emit(current_ammo, magazine_size)

	# Cooldown de disparo
	can_shoot = false
	fire_timer = fire_rate
	is_shooting = true

	# Raycast para detectar hit
	_process_raycast()

	# Toca animação de tiro IMEDIATAMENTE
	_play_animation(anim_shoot)

	# Trigger muzzle flash (tem await interno, por isso vem depois)
	_trigger_muzzle_flash()

	# Aplica recoil da arma (visual)
	_apply_weapon_recoil()

	# Aplica recoil da câmera
	_apply_camera_recoil()

	# Aplica efeitos visuais
	_apply_shooting_effects()

	# Emite signal
	weapon_fired.emit()


func _process_raycast() -> void:
	"""Processa o raycast e detecta hits"""
	if not raycast:
		return

	raycast.force_raycast_update()

	if raycast.is_colliding():
		var collider = raycast.get_collider()

		# Aplica dano se o objeto tem o método take_damage
		if collider.has_method("take_damage"):
			var was_alive = true
			if collider.has_method("is_alive"):
				was_alive = collider.is_alive()

			collider.take_damage(damage)

			# Verifica se matou
			var is_kill = false
			if collider.has_method("is_alive"):
				is_kill = was_alive and not collider.is_alive()

			# Emite signal de hit
			hit_enemy.emit(collider, damage, is_kill)

			# Feedback visual de hit
			if camera_effects:
				camera_effects.on_hit(is_kill)

		# Cria impact particles
		var hit_point = raycast.get_collision_point()
		_spawn_impact_particles(hit_point)


func _apply_weapon_recoil() -> void:
	"""Aplica recoil visual à arma"""
	if weapon_recoil:
		weapon_recoil.set_shooting_state(true)
		weapon_recoil.apply_recoil()


func _apply_camera_recoil() -> void:
	"""Aplica recoil à câmera"""
	if camera_effects:
		camera_effects.apply_camera_recoil(camera_recoil_horizontal, camera_recoil_vertical)
		camera_effects.shake_shoot()


func _apply_shooting_effects() -> void:
	"""Aplica efeitos visuais de tiro"""
	if camera_effects:
		camera_effects.trigger_shooting_effects()


func reload() -> void:
	"""Recarrega a arma (reload infinito estilo Overwatch)"""
	if is_reloading:
		return

	if current_ammo >= magazine_size:
		return

	is_reloading = true
	can_shoot = false
	is_shooting = false

	if weapon_recoil:
		weapon_recoil.set_shooting_state(false)

	reload_started.emit()

	# Toca animação de reload
	_play_animation(anim_reload)

	# Timer para reload
	await get_tree().create_timer(reload_time).timeout

	# Reload infinito - sempre enche o magazine completamente
	current_ammo = magazine_size

	is_reloading = false
	can_shoot = true

	ammo_changed.emit(current_ammo, magazine_size)
	reload_finished.emit()


func add_ammo(amount: int) -> void:
	"""Adiciona munição diretamente ao magazine (reload infinito)"""
	current_ammo += amount
	current_ammo = min(current_ammo, magazine_size)
	ammo_changed.emit(current_ammo, magazine_size)


func instant_reload() -> void:
	"""Reload instantâneo (chamado pelo dash)"""
	if is_reloading:
		return

	if current_ammo >= magazine_size:
		return

	# Cancela reload em progresso
	is_reloading = false

	# Reload instantâneo
	current_ammo = magazine_size
	can_shoot = true

	ammo_changed.emit(current_ammo, magazine_size)

	# Feedback visual de reload rápido
	_play_quick_reload_effect()


func _play_quick_reload_effect() -> void:
	"""Efeito visual de reload instantâneo durante dash"""
	if not weapon_recoil:
		return

	# Pequeno kick visual
	var tween = create_tween()
	tween.tween_property(self, "rotation:x", rotation.x - 0.15, 0.08).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation:x", rotation.x, 0.12).set_ease(Tween.EASE_IN_OUT)


func _trigger_muzzle_flash() -> void:
	"""Ativa o muzzle flash"""
	if muzzle_flash:
		if muzzle_flash.has_method("trigger"):
			muzzle_flash.trigger()
		else:
			muzzle_flash.visible = true

			for child in muzzle_flash.get_children():
				if child is GPUParticles3D:
					child.restart()
					child.emitting = true

			await get_tree().create_timer(0.1).timeout
			if muzzle_flash:
				muzzle_flash.visible = false


func _spawn_impact_particles(hit_position: Vector3) -> void:
	"""Spawna partículas de impacto"""
	if not ResourceLoader.exists("res://vfx/impact_particles.tscn"):
		return

	var impact_scene = load("res://vfx/impact_particles.tscn")
	var impact = impact_scene.instantiate()

	get_tree().current_scene.add_child(impact)
	impact.global_position = hit_position

	for child in impact.get_children():
		if child is GPUParticles3D:
			child.emitting = true

	await get_tree().create_timer(1.0).timeout
	if impact:
		impact.queue_free()


# === API PARA SISTEMAS EXTERNOS ===

func add_mouse_sway(input: Vector2) -> void:
	"""Adiciona input de mouse para sway"""
	if weapon_sway:
		weapon_sway.add_mouse_input(input)


func set_movement_state(moving: bool, sprinting: bool) -> void:
	"""Define estado de movimento para sway"""
	if weapon_sway:
		weapon_sway.set_movement_state(moving, sprinting)


func reset_transforms() -> void:
	"""Reseta todas as transformações"""
	if weapon_recoil:
		weapon_recoil.reset()

	if weapon_sway:
		weapon_sway.reset()

	position = original_position
	rotation = original_rotation
func _play_animation(anim_name: String, custom_speed: float = -1.0) -> void:
	"""Toca uma animação pelo nome com velocidade opcional"""
	if not animation_player:
		return
	
	if anim_name.is_empty():
		return
	
	if animation_player.has_animation(anim_name):
		# Determina velocidade baseada na animação
		var speed = custom_speed
		if speed < 0:
			if anim_name == anim_shoot:
				speed = anim_speed_shoot
			elif anim_name == anim_reload:
				speed = anim_speed_reload
			else:
				speed = 1.0
		
		animation_player.speed_scale = speed
		animation_player.play(anim_name)


func _log_mesh_debug_info() -> void:
	"""Loga informações sobre o mesh para ajudar no posicionamento"""
	if not mesh:
		return
	
	print("\n=== [%s] WEAPON MESH DEBUG INFO ===" % name)
	print("  Mesh Node Name: ", mesh.name)
	print("  Mesh Transform:")
	print("    - Position: Vector3(%.4f, %.4f, %.4f)" % [mesh.position.x, mesh.position.y, mesh.position.z])
	print("    - Rotation (deg): Vector3(%.1f, %.1f, %.1f)" % [rad_to_deg(mesh.rotation.x), rad_to_deg(mesh.rotation.y), rad_to_deg(mesh.rotation.z)])
	print("    - Scale: Vector3(%.4f, %.4f, %.4f)" % [mesh.scale.x, mesh.scale.y, mesh.scale.z])
	print("  Mesh Global Transform:")
	print("    - Global Position: ", mesh.global_position)
	
	var mesh_node: MeshInstance3D = null
	
	# Procura por MeshInstance3D recursivamente
	if mesh is MeshInstance3D:
		mesh_node = mesh
	else:
		for child in mesh.find_children("", "MeshInstance3D", true, false):
			mesh_node = child
			break
			
	if mesh_node:
		var aabb: AABB = mesh_node.get_aabb()
		var size = aabb.size
		print("  First MeshInstance3D: ", mesh_node.name)
		print("    - AABB Size (unscaled): Vector3(%.2f, %.2f, %.2f)" % [size.x, size.y, size.z])
		print("    - AABB Center: ", aabb.get_center())
	
	# Busca AnimationPlayer
	if animation_player:
		var anims = animation_player.get_animation_list()
		print("  Animations (%d): %s" % [anims.size(), anims])
	
	print("=== END WEAPON DEBUG ===\n")


func _notify_upgrade_manager() -> void:
	"""Notify UpgradeManager that this weapon is ready"""
	if UpgradeManager:
		UpgradeManager.set_weapon(self)


func get_weapon_type() -> String:
	"""Returns the weapon type identifier - override in subclasses"""
	return "base"


func _auto_calibrate_mesh() -> void:
	"""Auto-calibra o mesh para posição FPS correta baseado no AABB"""
	if not mesh:
		return
	
	# Configurações alvo para armas FPS (baseado na Pistol que funciona)
	# A arma deve aparecer no canto inferior direito da tela
	const TARGET_WEAPON_HEIGHT: float = 0.15  # Altura visual da arma na tela
	const TARGET_POSITION: Vector3 = Vector3(0.35, -0.25, -0.5)  # Posição padrão FPS
	
	# Encontra o primeiro MeshInstance3D para calcular o AABB real
	var mesh_instance: MeshInstance3D = null
	if mesh is MeshInstance3D:
		mesh_instance = mesh
	else:
		for child in mesh.find_children("", "MeshInstance3D", true, false):
			mesh_instance = child
			break
	
	if not mesh_instance:
		print("[%s] Auto-calibração: MeshInstance3D não encontrada" % name)
		return
	
	# Obtém AABB do mesh
	var aabb: AABB = mesh_instance.get_aabb()
	var model_height = aabb.size.y
	var model_center_y = aabb.get_center().y
	
	if model_height <= 0:
		print("[%s] Auto-calibração: AABB inválida" % name)
		return
	
	# Calcula escala necessária para atingir altura alvo
	var current_scale = abs(mesh.scale.y)
	var apparent_height = model_height * current_scale
	var scale_needed = TARGET_WEAPON_HEIGHT / model_height
	
	# Calcula offset Y para compensar o centro do modelo
	var y_offset = -model_center_y * scale_needed
	
	# Aplica escala uniforme (mantém rotação 180° no Y e Z para orientação FPS)
	mesh.scale = Vector3(scale_needed, scale_needed, scale_needed)
	
	# Ajusta rotação para orientação FPS (apontando para frente)
	mesh.rotation_degrees = Vector3(0, 180, 0)
	
	# Define posição com compensação do centro do modelo
	mesh.position = Vector3(TARGET_POSITION.x, TARGET_POSITION.y + y_offset, TARGET_POSITION.z)
	
	print("[%s] Auto-calibrado: scale=%.4f, y_offset=%.4f" % [name, scale_needed, y_offset])
