extends Area3D

# XP Orb - Orbs que inimigos dropam ao morrer
# São atraídos magneticamente pelo jogador

class_name XPOrb

# === CONFIGURAÇÃO ===
@export var xp_value: int = 10
@export var attraction_speed: float = 15.0
@export var attraction_range: float = 5.0
@export var max_speed: float = 30.0

# Visual
@export var orb_color: Color = Color(0.2, 0.8, 1.0, 1.0)  # Cyan
@export var orb_size: float = 0.15

# Estado interno
var is_attracted: bool = false
var target: Node3D = null
var mesh_instance: MeshInstance3D = null
var float_offset: float = 0.0


func _ready() -> void:
	_setup_visual()
	_setup_collision()
	_spawn_animation()
	
	body_entered.connect(_on_body_entered)
	
	# Adiciona ao grupo para o upgrade Ímã de XP
	add_to_group("xp_orbs")
	
	# Aleatoriza offset da flutuação
	float_offset = randf() * TAU


func _setup_visual() -> void:
	"""Cria mesh do orb com material emissivo"""
	mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "OrbMesh"
	
	var sphere = SphereMesh.new()
	sphere.radius = orb_size
	sphere.height = orb_size * 2
	sphere.radial_segments = 16
	sphere.rings = 8
	mesh_instance.mesh = sphere
	
	var material = StandardMaterial3D.new()
	material.albedo_color = orb_color
	material.emission_enabled = true
	material.emission = orb_color
	material.emission_energy_multiplier = 3.0
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color.a = 0.9
	mesh_instance.material_override = material
	
	add_child(mesh_instance)


func _setup_collision() -> void:
	"""Configura collision shape se não existir"""
	if not get_node_or_null("CollisionShape3D"):
		var collision = CollisionShape3D.new()
		collision.name = "CollisionShape3D"
		var shape = SphereShape3D.new()
		shape.radius = orb_size * 2  # Área maior para facilitar coleta
		collision.shape = shape
		add_child(collision)
	
	# Configura layers
	collision_layer = 0
	collision_mask = 1  # Só colide com player


func _spawn_animation() -> void:
	"""Animação de pop ao spawnar"""
	scale = Vector3.ZERO
	
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.tween_property(self, "scale", Vector3.ONE, 0.4)
	
	# Pula um pouco ao spawnar
	var start_y = global_position.y
	var jump_tween = create_tween()
	jump_tween.tween_property(self, "global_position:y", start_y + 1.2, 0.15).set_ease(Tween.EASE_OUT)
	jump_tween.tween_property(self, "global_position:y", start_y + 0.3, 0.25).set_ease(Tween.EASE_IN)


func _physics_process(delta: float) -> void:
	# Flutuação suave
	if mesh_instance:
		mesh_instance.position.y = sin(Time.get_ticks_msec() * 0.004 + float_offset) * 0.1
		mesh_instance.rotation.y += delta * 2.0  # Rotação lenta
	
	# Atração magnética
	_check_and_attract(delta)


func _check_and_attract(delta: float) -> void:
	"""Verifica distância do player e atrai o orb"""
	if not target:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			target = players[0]
	
	if not target:
		return
	
	var distance = global_position.distance_to(target.global_position)
	
	var current_range = attraction_range
	if ShopManager:
		current_range *= ShopManager.get_magnetism_multiplier()
	
	# Inicia atração quando entra no range
	if distance < current_range:
		is_attracted = true
	
	if is_attracted:
		var direction = (target.global_position - global_position).normalized()
		
		# Velocidade aumenta conforme fica mais perto
		var speed_factor = 1.0 + (current_range - distance) / current_range
		var speed = min(attraction_speed * speed_factor, max_speed)
		
		global_position += direction * speed * delta
		
		# Coleta automática quando muito perto
		if distance < 0.5:
			_collect()


func _on_body_entered(body: Node3D) -> void:
	"""Callback quando colide com algo"""
	if body.is_in_group("player"):
		_collect()


func _collect() -> void:
	"""Coleta o orb e dá XP ao jogador"""
	# Previne coleta dupla
	set_physics_process(false)
	
	# Adiciona XP
	if XPManager:
		XPManager.add_xp(xp_value)
	
	# Efeito de coleta
	_collect_effect()


func _collect_effect() -> void:
	"""Efeito visual de coleta"""
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Escala para cima e desaparece
	tween.tween_property(self, "scale", Vector3.ONE * 1.5, 0.1)
	
	if mesh_instance and mesh_instance.material_override:
		var mat = mesh_instance.material_override as StandardMaterial3D
		if mat:
			tween.tween_property(mat, "emission_energy_multiplier", 10.0, 0.1)
	
	await tween.finished
	
	# Flash final e remove
	var fade_tween = create_tween()
	fade_tween.tween_property(self, "scale", Vector3.ZERO, 0.1)
	await fade_tween.finished
	
	queue_free()


func set_xp_value(value: int) -> void:
	"""Define o valor de XP do orb"""
	xp_value = value
	
	# Ajusta tamanho visual baseado no valor
	var scale_factor = 1.0 + (value / 50.0) * 0.5  # Orbs maiores para mais XP
	scale_factor = clamp(scale_factor, 1.0, 2.0)
	
	if mesh_instance:
		mesh_instance.scale = Vector3.ONE * scale_factor


## Força atração instantânea (para upgrade Ímã de XP)
func force_attract() -> void:
	is_attracted = true
	attraction_speed = 50.0
	max_speed = 80.0
