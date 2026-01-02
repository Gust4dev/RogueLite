extends BaseEnemy

# Mini Boss Base - Classe base para todos os mini-bosses
# Estende BaseEnemy com mecânicas específicas de boss

class_name MiniBoss

# Signals específicos de boss
signal boss_died(boss_number: int, dropped_key: bool)
signal boss_health_changed(current: float, maximum: float)
signal boss_intro_started()
signal boss_intro_finished()

# === BOSS CONFIG ===
@export_group("Boss Config")
@export var boss_number: int = 1
@export var boss_name: String = "Mini Boss"

# HP base que será multiplicado pelo boss_number
@export var base_health: float = 200.0
@export var base_damage: float = 20.0

# Scaling factors
@export var health_multiplier: float = 1.0  # Boss 1: 1x, Boss 2: 2x, etc
@export var damage_scaling: float = 0.3  # 30% extra por boss

# === BOSS BEHAVIOR ===
@export_group("Boss Behavior")
@export var is_aggressive: bool = true
@export var charge_attack_enabled: bool = true
@export var charge_speed: float = 12.0
@export var charge_cooldown: float = 5.0
@export var charge_range: float = 15.0  # Distância para iniciar charge
@export var charge_damage_multiplier: float = 2.0

# === BOSS VISUAL ===
@export_group("Boss Visual")
@export var boss_scale: float = 1.5  # Bosses são maiores
@export var glow_color: Color = Color(1.0, 0.3, 0.3, 1.0)  # Vermelho por padrão
@export var glow_intensity: float = 2.0
@export var mesh_scale: float = 0.01  # Escala do mesh (para modelos GLB)
@export var mesh_y_offset: float = 0.0  # Offset Y do mesh
@export var mesh_rotation_y: float = 180.0  # Rotação em graus

# === KEY DROP ===
@export_group("Key Drop")
@export var key_drop_chance: float = 0.25  # 25% chance
@export var is_last_boss: bool = false  # Último boss sempre dropa key

# Estado interno
var is_charging: bool = false
var charge_timer: float = 0.0
var charge_direction: Vector3 = Vector3.ZERO
var intro_playing: bool = false
var boss_active: bool = false

# Referência ao key scene
var key_scene: PackedScene = null


func _ready() -> void:
	# Calcula stats baseado no número do boss
	_calculate_boss_stats()

	# Chama _ready do BaseEnemy
	super._ready()

	# Adiciona ao grupo de bosses
	add_to_group("bosses")

	# Aplica customização visual ao mesh
	_apply_visual_customization()

	# Aplica glow visual
	_apply_boss_glow()

	# Carrega cena da key
	if ResourceLoader.exists("res://items/key_item.tscn"):
		key_scene = load("res://items/key_item.tscn")

	# Emite health inicial
	boss_health_changed.emit(current_health, max_health)

	# Inicia intro do boss
	call_deferred("_start_boss_intro")


func _apply_visual_customization() -> void:
	"""Aplica escala, offset Y e rotação ao mesh"""
	if mesh:
		mesh.scale = Vector3(mesh_scale, mesh_scale, mesh_scale) * boss_scale
		mesh.position.y = mesh_y_offset
		mesh.rotation_degrees.y = mesh_rotation_y


func _calculate_boss_stats() -> void:
	"""Calcula os stats finais do boss baseado no número"""
	# Health scaling: Boss 1 = 200, Boss 2 = 400, Boss 3 = 700, Boss 4 = 1000
	match boss_number:
		1:
			max_health = 200.0
			xp_reward = 100
		2:
			max_health = 400.0
			xp_reward = 150
		3:
			max_health = 700.0
			xp_reward = 200
		4:
			max_health = 1000.0
			xp_reward = 300
			is_last_boss = true
		_:
			max_health = base_health * boss_number
			xp_reward = 100 * boss_number

	# Damage scaling: +30% por boss
	damage = base_damage * (1.0 + (boss_number - 1) * damage_scaling)

	# Speed aumenta levemente
	speed = speed + (boss_number * 0.5)

	# Attack range maior para bosses
	attack_range = 3.0

	# Cooldown menor para bosses mais fortes
	attack_cooldown = max(0.8, attack_cooldown - (boss_number * 0.1))


func _start_boss_intro() -> void:
	"""Inicia a sequência de intro do boss"""
	intro_playing = true
	boss_intro_started.emit()

	# Pausa o boss durante intro
	set_physics_process(false)

	# Aguarda a intro terminar (será chamado pelo spawn_manager ou UI)
	await get_tree().create_timer(2.0).timeout

	# Ativa o boss
	intro_playing = false
	boss_active = true
	set_physics_process(true)
	boss_intro_finished.emit()


func _physics_process(delta: float) -> void:
	if not boss_active or intro_playing:
		return

	# Atualiza timer do charge
	if charge_timer > 0:
		charge_timer -= delta

	# Se está fazendo charge, processa
	if is_charging:
		_process_charge(delta)
		return

	# Verifica se pode iniciar um charge attack
	if charge_attack_enabled and charge_timer <= 0 and target:
		var distance = global_position.distance_to(target.global_position)
		if distance >= attack_range and distance <= charge_range:
			_start_charge()
			return

	# Processa movimento normal do BaseEnemy
	super._physics_process(delta)


func _start_charge() -> void:
	"""Inicia o charge attack"""
	if not target:
		return

	is_charging = true
	charge_timer = charge_cooldown

	# Calcula direção do charge
	charge_direction = (target.global_position - global_position).normalized()
	charge_direction.y = 0  # Mantém no plano horizontal

	# Visual feedback - flash antes do charge
	_charge_telegraph()


func _charge_telegraph() -> void:
	"""Feedback visual antes do charge"""
	if mesh:
		# Flash de aviso
		var tween = create_tween()
		tween.tween_property(mesh, "scale", mesh.scale * 1.2, 0.2)
		tween.tween_property(mesh, "scale", mesh.scale, 0.1)
		await tween.finished


func _process_charge(delta: float) -> void:
	"""Processa o movimento do charge"""
	# Move rapidamente na direção do charge
	velocity = charge_direction * charge_speed

	# Aplica gravidade
	if not is_on_floor():
		velocity.y -= gravity * delta

	move_and_slide()

	# Verifica colisão com player
	if target:
		var distance = global_position.distance_to(target.global_position)
		if distance <= attack_range:
			# Hit com dano aumentado
			_charge_hit()
			is_charging = false

	# Verifica colisão com parede
	if is_on_wall():
		is_charging = false
		# Stun breve após bater na parede
		await get_tree().create_timer(0.5).timeout


func _charge_hit() -> void:
	"""Aplica dano do charge attack"""
	if target and target.has_method("take_damage"):
		var charge_damage = damage * charge_damage_multiplier
		target.take_damage(charge_damage)


func take_damage(amount: float) -> void:
	"""Sobrescreve take_damage para emitir signal de boss health"""
	super.take_damage(amount)
	boss_health_changed.emit(current_health, max_health)


func die() -> void:
	"""Sobrescreve die para dropar key e emitir signals de boss"""
	if not _is_alive:
		return

	_is_alive = false
	current_health = 0.0
	boss_active = false

	# Determina se dropa key
	var drops_key = _should_drop_key()

	# Emite signals
	boss_died.emit(boss_number, drops_key)
	died.emit()

	# Dropa key se necessário
	if drops_key:
		_spawn_key()

	# Desabilita física
	set_physics_process(false)

	# Animação de morte do boss (mais dramática)
	await _boss_death_animation()

	# Remove da cena
	queue_free()


func _should_drop_key() -> bool:
	"""Determina se o boss deve dropar uma key"""
	if is_last_boss:
		return true
	return randf() <= key_drop_chance


func _spawn_key() -> void:
	"""Spawna a key no local do boss"""
	if not key_scene:
		push_warning("Key scene not found!")
		return

	var key = key_scene.instantiate()
	get_tree().current_scene.add_child(key)
	key.global_position = global_position + Vector3(0, 6, 0)


func _boss_death_animation() -> void:
	"""Animação de morte do boss (mais elaborada)"""
	if not mesh:
		return

	# Efeito de explosão/dissolve
	var tween = create_tween()
	tween.set_parallel(true)

	# Aumenta e depois diminui
	tween.tween_property(mesh, "scale", mesh.scale * 1.5, 0.3).set_ease(Tween.EASE_OUT)
	tween.tween_property(mesh, "rotation:y", mesh.rotation.y + PI * 2, 0.5)

	await get_tree().create_timer(0.3).timeout

	# Fade out
	var fade_tween = create_tween()
	# Tenta fazer fade se possível
	if mesh is MeshInstance3D:
		pass  # Implementar fade se necessário

	await get_tree().create_timer(0.5).timeout


func _apply_boss_glow() -> void:
	"""Aplica efeito de glow ao boss"""
	if not mesh:
		return

	# Busca MeshInstance3D
	var mesh_instance: MeshInstance3D = null
	if mesh is MeshInstance3D:
		mesh_instance = mesh
	else:
		mesh_instance = mesh.find_child("*", true, false) as MeshInstance3D
		if not mesh_instance:
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

	# Cria material com glow
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.emission_enabled = true
	material.emission = glow_color
	material.emission_energy_multiplier = glow_intensity

	mesh_instance.set_surface_override_material(0, material)


func get_boss_info() -> Dictionary:
	"""Retorna informações do boss para UI"""
	return {
		"number": boss_number,
		"name": boss_name,
		"health": current_health,
		"max_health": max_health,
		"health_percent": current_health / max_health if max_health > 0 else 0.0
	}
