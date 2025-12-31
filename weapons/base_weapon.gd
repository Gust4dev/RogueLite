extends Node3D

# Base Weapon - Classe abstrata para todas as armas
# Implementa sistema de tiro com raycast, ammo e reload

class_name BaseWeapon

# Signals
signal weapon_fired()
signal ammo_changed(current_ammo: int, magazine_size: int, reserve_ammo: int)
signal reload_started()
signal reload_finished()
signal weapon_empty()

# Stats da arma (para serem sobrescritos pelas classes filhas)
@export var damage: float = 10.0
@export var fire_rate: float = 0.2
@export var reload_time: float = 1.5
@export var magazine_size: int = 12
@export var max_ammo: int = 120
@export var recoil_amount: Vector2 = Vector2(0.01, 0.02)

# Ammo
var current_ammo: int = 12
var reserve_ammo: int = 120

# Controle de disparo
var can_shoot: bool = true
var is_reloading: bool = false
var fire_timer: float = 0.0

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

# Camera do player (será definida quando equipada)
var player_camera: Camera3D = null

func _ready() -> void:
	# Inicializa ammo
	current_ammo = magazine_size
	reserve_ammo = max_ammo

	# Adiciona ao grupo weapons
	add_to_group("weapons")

	# Buscar mesh dinamicamente (pode ser PistolMesh, EnemyMesh, etc.)
	mesh = get_node_or_null("PistolMesh")
	if not mesh:
		for child in get_children():
			if child is Node3D and not child is RayCast3D:
				mesh = child
				break

	# Buscar AnimationPlayer dentro do mesh (GLBs importados geralmente têm um)
	if mesh:
		animation_player = mesh.find_child("AnimationPlayer", true, false)
		if animation_player:
			print("[Weapon] AnimationPlayer encontrado: ", animation_player.get_animation_list())
		else:
			print("[Weapon] AnimationPlayer NÃO encontrado no mesh")

	# Configura raycast
	if raycast:
		raycast.enabled = true
		raycast.target_position = Vector3(0, 0, -100)  # 100 metros à frente

	# Esconde muzzle flash inicialmente
	if muzzle_flash:
		muzzle_flash.visible = false

	# Obtém a câmera do player
	_find_player_camera()

	# Emite signal inicial de ammo
	ammo_changed.emit(current_ammo, magazine_size, reserve_ammo)

func _process(delta: float) -> void:
	# Atualiza fire timer
	if fire_timer > 0:
		fire_timer -= delta
		if fire_timer <= 0:
			can_shoot = true

	# Atualiza melee timer
	if melee_timer > 0:
		melee_timer -= delta
		if melee_timer <= 0:
			can_melee = true

func _find_player_camera() -> void:
	"""Encontra a câmera do player"""
	var parent = get_parent()
	if parent is Camera3D:
		player_camera = parent

func shoot() -> void:
	"""Dispara a arma"""
	# Verifica se pode atirar
	if not can_shoot or is_reloading:
		return

	# Verifica ammo
	if current_ammo <= 0:
		weapon_empty.emit()
		# Auto reload se tiver ammo reserva
		if reserve_ammo > 0:
			reload()
		return

	# Decrementa ammo
	current_ammo -= 1
	ammo_changed.emit(current_ammo, magazine_size, reserve_ammo)

	# Cooldown de disparo
	can_shoot = false
	fire_timer = fire_rate

	# Raycast para detectar hit
	if raycast:
		raycast.force_raycast_update()

		if raycast.is_colliding():
			var collider = raycast.get_collider()

			# Aplica dano se o objeto tem o método take_damage
			if collider.has_method("take_damage"):
				collider.take_damage(damage)

			# Cria impact particles na posição do hit
			var hit_point = raycast.get_collision_point()
			_spawn_impact_particles(hit_point)

	# Toca animação de tiro IMEDIATAMENTE
	_play_animation(anim_shoot)

	# Trigger muzzle flash (tem await interno, por isso vem depois)
	_trigger_muzzle_flash()

	# Aplica recoil
	_apply_recoil()

	# Emite signal
	weapon_fired.emit()

func reload() -> void:
	"""Recarrega a arma"""
	if is_reloading:
		return

	# Verifica se precisa recarregar
	if current_ammo >= magazine_size:
		return

	# Verifica se tem ammo reserva
	if reserve_ammo <= 0:
		return

	is_reloading = true
	can_shoot = false
	reload_started.emit()

	# Toca animação de reload
	if current_ammo == 0:
		_play_animation(anim_reload)
	else:
		_play_animation(anim_reload)

	# Timer para reload
	await get_tree().create_timer(reload_time).timeout

	# Calcula ammo a recarregar
	var ammo_needed = magazine_size - current_ammo
	var ammo_to_reload = min(ammo_needed, reserve_ammo)

	current_ammo += ammo_to_reload
	reserve_ammo -= ammo_to_reload

	is_reloading = false
	can_shoot = true

	ammo_changed.emit(current_ammo, magazine_size, reserve_ammo)
	reload_finished.emit()

func add_ammo(amount: int) -> void:
	"""Adiciona munição reserva"""
	reserve_ammo += amount
	reserve_ammo = min(reserve_ammo, max_ammo)
	ammo_changed.emit(current_ammo, magazine_size, reserve_ammo)

func melee() -> void:
	"""Ataque corpo a corpo"""
	if not can_melee or is_reloading:
		return

	can_melee = false
	melee_timer = melee_cooldown

	# Toca animação de melee
	_play_animation("melee")

	# Aguarda um pouco para o hit (metade da animação)
	await get_tree().create_timer(0.2).timeout

	# Detecta inimigos em range usando raycast curto
	if raycast:
		var original_target = raycast.target_position
		raycast.target_position = Vector3(0, 0, -melee_range)
		raycast.force_raycast_update()

		if raycast.is_colliding():
			var collider = raycast.get_collider()
			if collider.has_method("take_damage"):
				collider.take_damage(melee_damage)

		# Restaura raycast original
		raycast.target_position = original_target

func _trigger_muzzle_flash() -> void:
	"""Ativa o muzzle flash"""
	if muzzle_flash:
		if muzzle_flash.has_method("trigger"):
			muzzle_flash.trigger()
		else:
			muzzle_flash.visible = true

			# Emite partículas se existir GPUParticles3D
			for child in muzzle_flash.get_children():
				if child is GPUParticles3D:
					child.restart()
					child.emitting = true

			# Esconde depois de 0.1 segundos
			await get_tree().create_timer(0.1).timeout
			if muzzle_flash:
				muzzle_flash.visible = false

func _apply_recoil() -> void:
	"""Aplica recoil à câmera"""
	if player_camera:
		var camera_effects = player_camera.get_node_or_null("CameraEffects")
		if camera_effects and camera_effects.has_method("apply_recoil"):
			camera_effects.apply_recoil(
				randf_range(-recoil_amount.x, recoil_amount.x),
				-recoil_amount.y
			)

func _spawn_impact_particles(position: Vector3) -> void:
	"""Spawna partículas de impacto na posição do hit"""
	# Verifica se a cena existe
	if not ResourceLoader.exists("res://vfx/impact_particles.tscn"):
		return

	var impact_scene = load("res://vfx/impact_particles.tscn")
	var impact = impact_scene.instantiate()

	# Adiciona à cena
	get_tree().current_scene.add_child(impact)
	impact.global_position = position

	# Emite partículas
	for child in impact.get_children():
		if child is GPUParticles3D:
			child.emitting = true

	# Remove depois de 1 segundo
	await get_tree().create_timer(1.0).timeout
	if impact:
		impact.queue_free()

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
