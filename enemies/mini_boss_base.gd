extends BaseEnemy

# Mini Boss Base - Classe base para todos os mini-bosses
# Estende BaseEnemy com mecânicas específicas de boss
# Inclui sistema de AI Patterns (CHASE, SHOOT, SUMMON, RAGE)

class_name MiniBoss

# Signals específicos de boss
signal boss_died(boss_number: int, dropped_key: bool)
signal boss_health_changed(current: float, maximum: float)
signal boss_intro_started()
signal boss_intro_finished()
signal pattern_changed(new_pattern: int)

# === AI PATTERNS ===
enum Pattern {
	CHASE,      # Persegue e ataca melee
	SHOOT,      # Atira projéteis
	SUMMON,     # Invoca minions
	RAGE        # Modo fúria (abaixo de 25% HP)
}

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

# === PATTERN CONFIG ===
@export_group("Pattern Config")
@export var patterns_enabled: bool = true
@export var chase_duration: float = 5.0
@export var shoot_duration: float = 3.0
@export var summon_duration: float = 2.0
@export var projectile_speed: float = 10.0
@export var projectiles_per_burst: int = 3
@export var summon_count: int = 2
@export var rage_threshold: float = 0.25  # 25% HP

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

# Pattern state
var current_pattern: Pattern = Pattern.CHASE
var pattern_timer: float = 0.0
var is_in_rage: bool = false
var is_shooting: bool = false
var is_summoning: bool = false

# Referências
var key_scene: PackedScene = null
var projectile_scene: PackedScene = null
var zombie_scene: PackedScene = null


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

	# Carrega cena do projétil para pattern SHOOT
	if ResourceLoader.exists("res://enemies/projectiles/enemy_projectile.tscn"):
		projectile_scene = load("res://enemies/projectiles/enemy_projectile.tscn")

	# Carrega cena do zombie para pattern SUMMON
	if ResourceLoader.exists("res://enemies/zombie.tscn"):
		zombie_scene = load("res://enemies/zombie.tscn")

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

	# Sistema de Patterns
	if patterns_enabled:
		_process_patterns(delta)
		return

	# Verifica se pode iniciar um charge attack (legacy behavior)
	if charge_attack_enabled and charge_timer <= 0 and target:
		var distance = global_position.distance_to(target.global_position)
		if distance >= attack_range and distance <= charge_range:
			_start_charge()
			return

	# Processa movimento normal do BaseEnemy
	super._physics_process(delta)


func _process_patterns(delta: float) -> void:
	"""Processa o sistema de AI patterns"""
	pattern_timer += delta

	# Verifica se deve entrar em RAGE (abaixo de 25% HP)
	if not is_in_rage and current_health / max_health <= rage_threshold:
		_enter_rage_mode()

	match current_pattern:
		Pattern.CHASE:
			_pattern_chase(delta)
			if pattern_timer > chase_duration:
				_switch_pattern(Pattern.SHOOT)

		Pattern.SHOOT:
			_pattern_shoot(delta)
			if pattern_timer > shoot_duration:
				_switch_pattern(Pattern.SUMMON)

		Pattern.SUMMON:
			_pattern_summon(delta)
			if pattern_timer > summon_duration:
				_switch_pattern(Pattern.CHASE)

		Pattern.RAGE:
			_pattern_rage(delta)


func _switch_pattern(new_pattern: Pattern) -> void:
	"""Muda para um novo pattern"""
	if is_in_rage:
		return  # Em rage não muda de pattern

	current_pattern = new_pattern
	pattern_timer = 0.0
	is_shooting = false
	is_summoning = false
	pattern_changed.emit(new_pattern)

	# Visual feedback de mudança de pattern
	_pattern_change_visual()


func _pattern_change_visual() -> void:
	"""Efeito visual ao mudar de pattern"""
	if mesh:
		var tween = create_tween()
		tween.tween_property(mesh, "scale", mesh.scale * 1.1, 0.1)
		tween.tween_property(mesh, "scale", mesh.scale, 0.1)


func _enter_rage_mode() -> void:
	"""Entra no modo RAGE (abaixo de 25% HP)"""
	is_in_rage = true
	current_pattern = Pattern.RAGE
	pattern_timer = 0.0
	pattern_changed.emit(Pattern.RAGE)

	# Buffs de rage
	speed *= 1.5
	attack_cooldown *= 0.5

	# Visual de rage
	_apply_rage_visual()


func _apply_rage_visual() -> void:
	"""Aplica visual de modo rage"""
	var mesh_instance = _find_mesh_instance()
	if mesh_instance:
		var mat = mesh_instance.get_surface_override_material(0)
		if mat is StandardMaterial3D:
			mat.emission = Color.RED
			mat.emission_energy_multiplier = 4.0


func _pattern_chase(delta: float) -> void:
	"""Pattern CHASE - persegue e ataca melee"""
	if not target:
		return

	var distance = global_position.distance_to(target.global_position)

	# Verifica se pode fazer charge durante chase
	if charge_attack_enabled and charge_timer <= 0:
		if distance >= attack_range and distance <= charge_range:
			_start_charge()
			return

	# Comportamento normal de chase/ataque
	super._physics_process(delta)


func _pattern_shoot(delta: float) -> void:
	"""Pattern SHOOT - atira projéteis"""
	if not target:
		return

	# Para e atira
	velocity.x = 0
	velocity.z = 0

	# Olha para o player
	var look_target = Vector3(target.global_position.x, global_position.y, target.global_position.z)
	if global_position.distance_to(look_target) > 0.1:
		look_at(look_target)

	# Atira projéteis
	if not is_shooting and can_attack:
		_shoot_projectiles()

	# Aplica gravidade
	if not is_on_floor():
		velocity.y -= gravity * delta

	move_and_slide()


func _shoot_projectiles() -> void:
	"""Dispara uma rajada de projéteis"""
	if not projectile_scene:
		return

	is_shooting = true
	can_attack = false
	attack_timer = attack_cooldown

	# Telegraph visual
	_shoot_telegraph()

	await get_tree().create_timer(0.3).timeout

	if not _is_alive or not target:
		is_shooting = false
		return

	# Dispara múltiplos projéteis
	for i in range(projectiles_per_burst):
		_fire_single_projectile(i)
		await get_tree().create_timer(0.15).timeout

	is_shooting = false


func _shoot_telegraph() -> void:
	"""Aviso visual antes de atirar"""
	if mesh:
		var mesh_instance = _find_mesh_instance()
		if mesh_instance:
			var mat = mesh_instance.get_surface_override_material(0)
			if mat is StandardMaterial3D:
				var orig = mat.emission_energy_multiplier
				mat.emission_energy_multiplier = 5.0
				await get_tree().create_timer(0.2).timeout
				if is_instance_valid(mat):
					mat.emission_energy_multiplier = orig


func _fire_single_projectile(index: int) -> void:
	"""Dispara um único projétil"""
	if not projectile_scene or not target:
		return

	var projectile = projectile_scene.instantiate()
	get_tree().current_scene.add_child(projectile)

	var spawn_pos = global_position + Vector3(0, 1.5, 0)
	projectile.global_position = spawn_pos

	# Direção com spread baseado no índice
	var base_dir = (target.global_position - spawn_pos).normalized()
	var spread_angle = (index - projectiles_per_burst / 2.0) * 0.2
	var spread_dir = base_dir.rotated(Vector3.UP, spread_angle)

	var actual_damage = damage * 0.5  # Projéteis causam menos dano
	if GameManager:
		actual_damage *= GameManager.get_damage_multiplier()

	if projectile.has_method("setup"):
		projectile.setup(spread_dir, projectile_speed, actual_damage)
		projectile.projectile_color = glow_color


func _pattern_summon(delta: float) -> void:
	"""Pattern SUMMON - invoca minions"""
	if not target:
		return

	# Para durante summon
	velocity.x = 0
	velocity.z = 0

	# Invoca minions
	if not is_summoning:
		_summon_minions()

	# Aplica gravidade
	if not is_on_floor():
		velocity.y -= gravity * delta

	move_and_slide()


func _summon_minions() -> void:
	"""Invoca minions zombies"""
	if not zombie_scene:
		return

	is_summoning = true

	# Telegraph visual
	_summon_telegraph()

	await get_tree().create_timer(0.5).timeout

	if not _is_alive:
		is_summoning = false
		return

	# Spawna minions em círculo
	for i in range(summon_count):
		var angle = (TAU / summon_count) * i
		var spawn_offset = Vector3(cos(angle) * 3.0, 0.5, sin(angle) * 3.0)
		var spawn_pos = global_position + spawn_offset

		var minion = zombie_scene.instantiate()
		get_tree().current_scene.add_child(minion)
		minion.global_position = spawn_pos

		# Efeito de spawn
		_spawn_minion_effect(spawn_pos)

	is_summoning = false


func _summon_telegraph() -> void:
	"""Efeito visual antes de invocar"""
	if mesh:
		var tween = create_tween()
		tween.tween_property(mesh, "position:y", mesh.position.y + 0.3, 0.2)
		tween.tween_property(mesh, "position:y", mesh_y_offset, 0.3)


func _spawn_minion_effect(pos: Vector3) -> void:
	"""Efeito visual no local do spawn do minion"""
	var effect = MeshInstance3D.new()
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = 0.8
	cylinder.bottom_radius = 0.8
	cylinder.height = 0.1
	effect.mesh = cylinder

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(glow_color.r, glow_color.g, glow_color.b, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = glow_color
	mat.emission_energy_multiplier = 2.0
	effect.set_surface_override_material(0, mat)

	get_tree().current_scene.add_child(effect)
	effect.global_position = pos

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(effect, "scale", Vector3.ONE * 2.0, 0.5)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.5)
	await tween.finished
	effect.queue_free()


func _pattern_rage(delta: float) -> void:
	"""Pattern RAGE - modo fúria agressivo"""
	if not target:
		return

	var distance = global_position.distance_to(target.global_position)

	# Charge frequente em rage
	if charge_attack_enabled and charge_timer <= 0:
		if distance >= attack_range * 0.5 and distance <= charge_range * 1.5:
			_start_charge()
			return

	# Atira enquanto persegue
	if can_attack and projectile_scene:
		_fire_rage_projectile()

	# Persegue agressivamente
	super._physics_process(delta)


func _fire_rage_projectile() -> void:
	"""Dispara projétil durante rage mode"""
	if not projectile_scene or not target:
		return

	can_attack = false
	attack_timer = attack_cooldown * 0.5  # Atira mais rápido em rage

	var projectile = projectile_scene.instantiate()
	get_tree().current_scene.add_child(projectile)

	var spawn_pos = global_position + Vector3(0, 1.5, 0)
	projectile.global_position = spawn_pos

	var direction = (target.global_position - spawn_pos).normalized()

	var actual_damage = damage * 0.3
	if GameManager:
		actual_damage *= GameManager.get_damage_multiplier()

	if projectile.has_method("setup"):
		projectile.setup(direction, projectile_speed * 1.5, actual_damage)
		projectile.projectile_color = Color.RED


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
