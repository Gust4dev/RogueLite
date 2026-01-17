extends Area3D

# Coin - Moedas que inimigos dropam ao morrer
# São atraídas magneticamente pelo jogador

class_name Coin

# === CONFIGURAÇÃO ===
@export var coin_value: int = 2
@export var attraction_speed: float = 18.0
@export var attraction_range: float = 6.0
@export var max_speed: float = 35.0

# Visual
@export var coin_color: Color = Color(1.0, 0.85, 0.2, 1.0)  # Dourado
@export var coin_size: float = 0.12

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
	
	# Aleatoriza offset da flutuação
	float_offset = randf() * TAU


func _setup_visual() -> void:
	"""Cria mesh da moeda (cilindro achatado)"""
	mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "CoinMesh"
	
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = coin_size
	cylinder.bottom_radius = coin_size
	cylinder.height = coin_size * 0.3
	cylinder.radial_segments = 16
	mesh_instance.mesh = cylinder
	
	var material = StandardMaterial3D.new()
	material.albedo_color = coin_color
	material.metallic = 0.8
	material.roughness = 0.2
	material.emission_enabled = true
	material.emission = coin_color
	material.emission_energy_multiplier = 1.5
	mesh_instance.material_override = material
	
	add_child(mesh_instance)


func _setup_collision() -> void:
	"""Configura collision shape se não existir"""
	if not get_node_or_null("CollisionShape3D"):
		var collision = CollisionShape3D.new()
		collision.name = "CollisionShape3D"
		var shape = SphereShape3D.new()
		shape.radius = coin_size * 2.5
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
	tween.tween_property(self, "scale", Vector3.ONE, 0.3)
	
	# Pula um pouco ao spawnar
	var start_y = global_position.y
	var jump_tween = create_tween()
	jump_tween.tween_property(self, "global_position:y", start_y + 0.8, 0.12).set_ease(Tween.EASE_OUT)
	jump_tween.tween_property(self, "global_position:y", start_y + 0.25, 0.2).set_ease(Tween.EASE_IN)


func _physics_process(delta: float) -> void:
	# Flutuação e rotação
	if mesh_instance:
		mesh_instance.position.y = sin(Time.get_ticks_msec() * 0.003 + float_offset) * 0.08
		mesh_instance.rotation.y += delta * 3.0  # Rotação
		mesh_instance.rotation.x = 0.3  # Inclinação para parecer 3D
	
	# Atração magnética
	_check_and_attract(delta)


func _check_and_attract(delta: float) -> void:
	"""Verifica distância do player e atrai a moeda"""
	if not target:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			target = players[0]
	
	if not target:
		return
	
	var distance = global_position.distance_to(target.global_position)
	
	# Inicia atração quando entra no range
	if distance < attraction_range:
		is_attracted = true
	
	if is_attracted:
		var direction = (target.global_position - global_position).normalized()
		
		# Velocidade aumenta conforme fica mais perto
		var speed_factor = 1.0 + (attraction_range - distance) / attraction_range
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
	"""Coleta a moeda e dá dinheiro ao jogador"""
	# Previne coleta dupla
	set_physics_process(false)
	
	# Adiciona dinheiro
	if MoneyManager:
		MoneyManager.add_money(coin_value)
	
	# Efeito de coleta
	_collect_effect()


func _collect_effect() -> void:
	"""Efeito visual de coleta"""
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Escala para cima e desaparece
	tween.tween_property(self, "scale", Vector3.ONE * 1.3, 0.08)
	
	if mesh_instance and mesh_instance.material_override:
		var mat = mesh_instance.material_override as StandardMaterial3D
		if mat:
			tween.tween_property(mat, "emission_energy_multiplier", 8.0, 0.08)
	
	await tween.finished
	
	# Flash final e remove
	var fade_tween = create_tween()
	fade_tween.tween_property(self, "scale", Vector3.ZERO, 0.08)
	await fade_tween.finished
	
	queue_free()


func set_coin_value(value: int) -> void:
	"""Define o valor da moeda"""
	coin_value = value
	
	# Ajusta tamanho visual baseado no valor
	var scale_factor = 1.0 + (value / 20.0) * 0.3
	scale_factor = clamp(scale_factor, 1.0, 1.8)
	
	if mesh_instance:
		mesh_instance.scale = Vector3.ONE * scale_factor


## Força atração instantânea (para upgrade Ímã)
func force_attract() -> void:
	is_attracted = true
	attraction_speed = 50.0
	max_speed = 80.0
