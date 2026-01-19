extends BaseWeapon

# Sniper Rifle - Long Range Precision
# Dano massivo, ritmo lento, requer precisão
# Scope zoom, critical hits, bullet travel
# Upgrade Interactions:
#   - Piercing: Atravessa múltiplos inimigos
#   - Explosive: Sniper explosivo (OP)

class_name SniperRifle

# Tipo de arma para upgrade interactions
var weapon_type: String = "sniper"

# === SISTEMA DE SCOPE ===
@export_group("Scope System")
@export var scope_fov: float = 20.0  # FOV quando usando scope
@export var normal_fov: float = 90.0  # FOV normal
@export var scope_zoom_speed: float = 8.0  # Velocidade de transição
@export var scope_sensitivity_multiplier: float = 0.3  # Reduz sensibilidade no scope

var is_scoped: bool = false
var current_fov: float = 90.0
var camera_ref: Camera3D = null

# === SISTEMA DE CRITICAL HIT ===
@export_group("Critical Hits")
@export var headshot_multiplier: float = 2.0
@export var critical_hit_chance: float = 0.0  # Só headshots são críticos por padrão

# === BULLET TRAVEL (opcional) ===
@export_group("Bullet Travel")
@export var use_bullet_travel: bool = false  # Desativado por padrão (hitscan)
@export var bullet_speed: float = 200.0  # Metros por segundo
@export var bullet_drop: float = 0.0  # Sem drop por enquanto

# Estado
var scoped_accuracy_bonus: float = 0.0  # Precisão extra quando scoped
var time_scoped: float = 0.0  # Tempo no scope


func _ready() -> void:
	# Define meshes que devem ir para o overlay (ignora Manny/braços)
	weapon_mesh_keywords = ["sniper", "scope", "barrel"]
	
	# === STATS BÁSICOS ===
	# 100 dmg / 1.5s = ~66.67 DPS (target)
	damage = 100.0
	fire_rate = 1.5  # Muito lento
	reload_time = 2.5  # Reload longo
	magazine_size = 5

	# === RECOIL DA ARMA (kickback visual) ===
	# Sniper tem recoil forte mas controlado
	kickback_position = Vector3(0.0, 0.03, 0.15)  # Kickback grande
	kickback_rotation = Vector3(-10.0, 2.0, 2.5)   # Rotação significativa
	position_randomness = Vector3(0.005, 0.005, 0.012)
	rotation_randomness = Vector3(1.0, 1.5, 0.8)
	kickback_speed = 18.0   # Kickback rápido
	return_speed = 4.0      # Retorno lento (bolt action)
	shooting_return_speed = 2.5

	# === RECOIL DA CÂMERA ===
	camera_recoil_horizontal = 0.5   # Pouco horizontal
	camera_recoil_vertical = 4.0     # Punch vertical massivo

	# === SWAY ===
	sway_enabled = true
	mouse_sway_amount = Vector2(0.0008, 0.0008)  # Menos sway (rifle com suporte)
	mouse_sway_max = Vector2(0.025, 0.018)
	movement_sway_amount = 0.008

	# Nomes das animações
	anim_shoot = "Shoot"
	anim_reload = "Reload"
	anim_draw = "Draw"
	anim_idle = "Idle"

	# Velocidade das animações
	anim_speed_shoot = 1.0  # Animação normal (bolt action)
	anim_speed_reload = 1.0

	# Chama o _ready() do pai
	super._ready()

	# Toca animação inicial
	_play_initial_sequence()


func _play_initial_sequence() -> void:
	"""Toca Draw e depois vai para Idle"""
	if not animation_player:
		return

	if animation_player.has_animation(anim_draw):
		animation_player.play(anim_draw)
		await animation_player.animation_finished

	if animation_player.has_animation(anim_idle):
		animation_player.play(anim_idle)


func _process(delta: float) -> void:
	# Chama process do pai
	super._process(delta)

	# Atualiza scope
	_update_scope(delta)

	# Atualiza precisão baseado no tempo scoped
	if is_scoped:
		time_scoped += delta
		scoped_accuracy_bonus = min(time_scoped * 0.5, 1.0)  # Max 100% bonus em 2s
	else:
		time_scoped = 0.0
		scoped_accuracy_bonus = 0.0


func _update_scope(delta: float) -> void:
	"""Atualiza transição de FOV do scope"""
	if not camera_ref:
		_find_camera()
		return

	var target_fov = scope_fov if is_scoped else normal_fov
	current_fov = lerp(current_fov, target_fov, scope_zoom_speed * delta)
	camera_ref.fov = current_fov


func _find_camera() -> void:
	"""Encontra a câmera do player"""
	var parent = get_parent()
	if parent is Camera3D:
		camera_ref = parent
		current_fov = parent.fov
		normal_fov = parent.fov


# === SCOPE CONTROLS ===

func toggle_scope() -> void:
	"""Alterna scope on/off"""
	is_scoped = not is_scoped
	_on_scope_changed()


func enter_scope() -> void:
	"""Entra no scope"""
	if not is_scoped:
		is_scoped = true
		_on_scope_changed()


func exit_scope() -> void:
	"""Sai do scope"""
	if is_scoped:
		is_scoped = false
		_on_scope_changed()


func _on_scope_changed() -> void:
	"""Chamado quando scope muda de estado"""
	if is_scoped:
		# Reduz sway no scope
		if weapon_sway:
			weapon_sway.mouse_sway_amount = mouse_sway_amount * 0.3
			weapon_sway.movement_sway_amount = movement_sway_amount * 0.2

		# Esconde modelo da arma (opcional)
		if mesh:
			mesh.visible = false
	else:
		# Restaura sway
		if weapon_sway:
			weapon_sway.mouse_sway_amount = mouse_sway_amount
			weapon_sway.movement_sway_amount = movement_sway_amount

		# Mostra modelo
		if mesh:
			mesh.visible = true


# === OVERRIDE DO MÉTODO SHOOT ===

func shoot() -> void:
	"""Override: Dispara com possibilidade de critical hit"""
	# Verifica se pode atirar
	if not can_shoot or is_reloading:
		return

	# Verifica ammo
	if current_ammo <= 0:
		weapon_empty.emit()
		reload()
		return

	# Sai do scope ao atirar (para ver o impacto)
	var was_scoped = is_scoped
	if is_scoped:
		exit_scope()

	# Decrementa ammo
	current_ammo -= 1
	ammo_changed.emit(current_ammo, magazine_size)

	# Cooldown de disparo
	can_shoot = false
	fire_timer = fire_rate
	is_shooting = true

	# Raycast com critical hit check
	_process_sniper_raycast(was_scoped)

	# Toca animação
	_play_animation(anim_shoot)

	# Muzzle flash
	_trigger_sniper_muzzle_flash()

	# Aplica recoil
	_apply_weapon_recoil()

	# Aplica recoil da câmera (mais forte sem scope)
	_apply_camera_recoil()

	# Efeitos visuais
	_apply_shooting_effects()

	# Emite signal
	weapon_fired.emit()


func _process_sniper_raycast(was_scoped: bool) -> void:
	"""Processa raycast com sistema de critical hits"""
	if not raycast:
		return

	raycast.force_raycast_update()

	if raycast.is_colliding():
		var collider = raycast.get_collider()
		var hit_point = raycast.get_collision_point()
		var hit_normal = raycast.get_collision_normal()

		# Calcula dano
		var final_damage = damage

		# Bonus de precisão por estar scoped
		if was_scoped:
			final_damage *= (1.0 + scoped_accuracy_bonus * 0.2)  # Até +20% dano

		# Verifica critical hit (headshot)
		var is_critical = _check_critical_hit(collider, hit_point)
		if is_critical:
			final_damage *= headshot_multiplier
			_spawn_critical_effect(hit_point)

		if collider.has_method("take_damage"):
			var was_alive = true
			if collider.has_method("is_alive"):
				was_alive = collider.is_alive()

			collider.take_damage(final_damage)

			var is_kill = false
			if collider.has_method("is_alive"):
				is_kill = was_alive and not collider.is_alive()

			hit_enemy.emit(collider, final_damage, is_kill)

			if camera_effects:
				camera_effects.on_hit(is_kill)

		# Impact particles
		_spawn_sniper_impact(hit_point, is_critical)


func _check_critical_hit(enemy: Node3D, hit_point: Vector3) -> bool:
	"""Verifica se foi um headshot (critical hit)"""
	if not enemy:
		return false

	# Tenta encontrar a posição da cabeça do inimigo
	var head_node = enemy.get_node_or_null("Head")
	if head_node:
		var head_distance = hit_point.distance_to(head_node.global_position)
		return head_distance < 0.5  # Margem de 0.5m para headshot

	# Fallback: verifica altura relativa
	var enemy_height = 2.0  # Altura estimada
	if enemy.has_method("get_height"):
		enemy_height = enemy.get_height()

	var relative_height = hit_point.y - enemy.global_position.y
	var head_zone = enemy_height * 0.85  # Top 15% é a cabeça

	return relative_height >= head_zone


func _spawn_critical_effect(position: Vector3) -> void:
	"""Spawna efeito visual de critical hit"""
	# Cria efeito de "CRITICAL" ou flash especial
	var effect = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.3
	sphere.height = 0.6
	effect.mesh = sphere

	var material = StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.2, 0.2, 0.9)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.2, 0.2)
	material.emission_energy_multiplier = 5.0
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	effect.material_override = material
	effect.global_position = position

	get_tree().current_scene.add_child(effect)

	var tween = effect.create_tween()
	tween.parallel().tween_property(effect, "scale", Vector3(2.0, 2.0, 2.0), 0.2)
	tween.parallel().tween_property(material, "albedo_color:a", 0.0, 0.2)

	await tween.finished
	if is_instance_valid(effect):
		effect.queue_free()


func _spawn_sniper_impact(position: Vector3, is_critical: bool) -> void:
	"""Spawna partículas de impacto do sniper"""
	_spawn_impact_particles(position)

	# Efeito adicional para critical
	if is_critical:
		_spawn_critical_effect(position)


func _trigger_sniper_muzzle_flash() -> void:
	"""Muzzle flash intenso para sniper"""
	if muzzle_flash:
		if muzzle_flash.has_method("trigger"):
			muzzle_flash.trigger()
		else:
			muzzle_flash.visible = true

			for child in muzzle_flash.get_children():
				if child is GPUParticles3D:
					child.restart()
					child.emitting = true

			await get_tree().create_timer(0.12).timeout
			if muzzle_flash:
				muzzle_flash.visible = false


# === SNIPER SPECIFIC METHODS ===

func get_weapon_type() -> String:
	"""Retorna o tipo de arma para upgrade interactions"""
	return weapon_type


func is_using_scope() -> bool:
	"""Retorna se está usando scope"""
	return is_scoped


func get_scope_zoom_level() -> float:
	"""Retorna nível de zoom atual (0.0 a 1.0)"""
	if not is_scoped:
		return 0.0
	var zoom_range = normal_fov - scope_fov
	return (normal_fov - current_fov) / zoom_range


func get_sensitivity_multiplier() -> float:
	"""Retorna multiplicador de sensibilidade (para player controller)"""
	if is_scoped:
		return scope_sensitivity_multiplier
	return 1.0
