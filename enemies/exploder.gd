extends BaseEnemy

# Exploder - Inimigo suicida que explode ao chegar perto ou morrer
# Corre pro player e causa dano massivo em área

class_name Exploder

# Configuração do Exploder
@export_group("Exploder Config")
@export var explosion_damage: float = 50.0
@export var explosion_radius: float = 4.0
@export var explosion_trigger_range: float = 2.0
@export var fuse_time: float = 0.5  # Tempo entre trigger e explosão
@export var pulse_speed: float = 2.0  # Velocidade do pulso visual

# Customização Visual
@export_group("Visual")
@export var mesh_scale: float = 0.8
@export var mesh_y_offset: float = 0.0
@export var mesh_rotation_y: float = 180.0
@export var glow_color: Color = Color(1.0, 0.3, 0.0)  # Laranja brilhante

# Estado interno
var is_triggered: bool = false
var pulse_timer: float = 0.0
var pulse_material: StandardMaterial3D = null

func _ready() -> void:
	# Stats específicas do Exploder
	max_health = 30.0
	speed = 4.5  # Mais rápido que zombie
	damage = 10.0  # Dano de contato baixo
	attack_range = explosion_trigger_range
	attack_cooldown = 999.0  # Não ataca normalmente
	xp_reward = 25

	# Chama o _ready() do pai
	super._ready()

	# Aplica customização visual
	_apply_visual_customization()


func _apply_visual_customization() -> void:
	"""Aplica escala, offset Y e rotação ao mesh"""
	if mesh:
		mesh.scale = Vector3(mesh_scale, mesh_scale, mesh_scale) * 0.01
		mesh.position.y = mesh_y_offset
		mesh.rotation_degrees.y = mesh_rotation_y

	# Aplica visual de glow pulsante
	_setup_glow_material()


func _setup_glow_material() -> void:
	"""Configura material com glow para efeito visual de bomba"""
	var mesh_instance = _find_mesh_instance()
	if mesh_instance:
		pulse_material = StandardMaterial3D.new()
		pulse_material.albedo_color = glow_color
		pulse_material.emission_enabled = true
		pulse_material.emission = glow_color
		pulse_material.emission_energy_multiplier = 1.0
		mesh_instance.set_surface_override_material(0, pulse_material)


func _physics_process(delta: float) -> void:
	if not _is_alive:
		return

	# Efeito de pulso visual (sempre ativo)
	_update_pulse(delta)

	# Aplica gravidade
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	# Se já foi triggered, não faz mais nada
	if is_triggered:
		velocity.x = 0
		velocity.z = 0
		move_and_slide()
		return

	# Atualiza cache de inimigos próximos
	nearby_update_timer -= delta
	if nearby_update_timer <= 0:
		_update_nearby_enemies()
		nearby_update_timer = NEARBY_UPDATE_INTERVAL

	if not target:
		move_and_slide()
		return

	var distance_to_target = global_position.distance_to(target.global_position)

	# Verifica se está perto o suficiente para explodir
	if distance_to_target <= explosion_trigger_range:
		_trigger_explosion()
		return

	# Corre em direção ao player
	_navigate_to_target()

	# Olha para onde está indo
	if velocity.length() > 0.1:
		var look_target = global_position + velocity.normalized()
		look_target.y = global_position.y
		if global_position.distance_to(look_target) > 0.1:
			look_at(look_target)

	_apply_separation_force()
	move_and_slide()


func _update_pulse(delta: float) -> void:
	"""Atualiza efeito de pulso visual"""
	if not pulse_material:
		return

	pulse_timer += delta * pulse_speed

	# Pulso mais rápido quando triggered
	var current_speed = pulse_speed
	if is_triggered:
		current_speed = pulse_speed * 4.0

	# Calcula intensidade do pulso
	var pulse = (sin(pulse_timer * current_speed * PI) + 1.0) / 2.0
	var intensity = 1.0 + pulse * 3.0

	if is_triggered:
		intensity = 2.0 + pulse * 5.0
		pulse_material.albedo_color = Color(1.0, 0.1, 0.0)  # Mais vermelho quando triggered
		pulse_material.emission = Color(1.0, 0.1, 0.0)

	pulse_material.emission_energy_multiplier = intensity


func _trigger_explosion() -> void:
	"""Inicia sequência de explosão"""
	if is_triggered:
		return

	is_triggered = true

	# Para de se mover
	velocity = Vector3.ZERO

	# Efeito visual de countdown
	await _explosion_countdown()

	# Explode!
	_explode()


func _explosion_countdown() -> void:
	"""Countdown visual antes da explosão"""
	if mesh:
		# Cresce antes de explodir
		var tween = create_tween()
		tween.tween_property(mesh, "scale", mesh.scale * 1.5, fuse_time)
		await tween.finished


func _explode() -> void:
	"""Executa a explosão"""
	if not _is_alive:
		return

	# Aplica dano em área
	_apply_explosion_damage()

	# Efeito visual de explosão
	_spawn_explosion_effect()

	# Morre sem dropar XP/coins normalmente (já causou dano suficiente)
	_is_alive = false
	died.emit()

	# Remove imediatamente
	queue_free()


func _apply_explosion_damage() -> void:
	"""Aplica dano da explosão a todos os alvos na área"""
	var actual_damage = explosion_damage
	if GameManager:
		actual_damage = explosion_damage * GameManager.get_damage_multiplier()

	# Verifica player
	if target:
		var distance = global_position.distance_to(target.global_position)
		if distance <= explosion_radius:
			# Dano diminui com distância
			var damage_falloff = 1.0 - (distance / explosion_radius)
			var final_damage = actual_damage * damage_falloff

			if target.has_method("take_damage"):
				target.take_damage(final_damage)

	# Também pode danificar outros inimigos (friendly fire)
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy == self:
			continue
		if not is_instance_valid(enemy):
			continue

		var distance = global_position.distance_to(enemy.global_position)
		if distance <= explosion_radius:
			var damage_falloff = 1.0 - (distance / explosion_radius)
			var friendly_fire_damage = actual_damage * damage_falloff * 0.5  # 50% do dano em outros inimigos

			if enemy.has_method("take_damage"):
				enemy.take_damage(friendly_fire_damage)


func _spawn_explosion_effect() -> void:
	"""Cria efeito visual de explosão"""
	# Esfera de explosão
	var explosion = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	explosion.mesh = sphere

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.5, 0.0, 0.8)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.3, 0.0)
	mat.emission_energy_multiplier = 5.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	explosion.set_surface_override_material(0, mat)

	get_tree().current_scene.add_child(explosion)
	explosion.global_position = global_position

	# Expande e fade out
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(explosion, "scale", Vector3.ONE * explosion_radius * 2, 0.3)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.3)

	await tween.finished
	explosion.queue_free()


func die() -> void:
	"""Override: Explode ao morrer"""
	if is_triggered:
		# Já está explodindo
		return

	# Explode mesmo ao ser morto
	_trigger_explosion()


func take_damage(amount: float) -> void:
	"""Override: Verifica se morte causa explosão"""
	if not _is_alive:
		return

	current_health -= amount
	damage_received.emit(amount)

	_damage_flash()

	# Se morreu, explode
	if current_health <= 0 and not is_triggered:
		die()
