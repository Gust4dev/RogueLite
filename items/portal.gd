extends Area3D

# Portal - Aparece após primeiro boss, requer key para entrar

class_name Portal

signal portal_entered()
signal portal_denied()  # Player tentou entrar sem key

# Config
@export var requires_key: bool = true
@export var portal_color: Color = Color(0.3, 0.5, 1.0, 1.0)  # Azul
@export var active_color: Color = Color(0.0, 1.0, 0.5, 1.0)  # Verde quando tem key
@export var rotation_speed: float = 1.0
@export var pulse_speed: float = 2.0

# Estado
var is_active: bool = false
var player_nearby: bool = false
var time_passed: float = 0.0

# Referências
var portal_mesh: MeshInstance3D = null
var portal_particles: GPUParticles3D = null
var interaction_label: Label3D = null


func _ready() -> void:
	# Configura collision
	collision_layer = 0
	collision_mask = 1  # Player

	# Conecta signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Cria visual do portal
	_create_portal_visual()

	# Cria label de interação
	_create_interaction_label()

	# Inicia desativado (ativado pelo SpawnManager após primeiro boss)
	deactivate()


func _process(delta: float) -> void:
	if not is_active:
		return

	time_passed += delta

	# Rotação do portal
	if portal_mesh:
		portal_mesh.rotation.y += rotation_speed * delta

	# Efeito de pulso
	if portal_mesh:
		var pulse = 1.0 + sin(time_passed * pulse_speed) * 0.1
		portal_mesh.scale = Vector3(pulse, pulse * 2, pulse)

	# Atualiza cor baseado em ter key ou não
	_update_portal_color()

	# Atualiza label
	_update_interaction_label()


func _create_portal_visual() -> void:
	"""Cria representação visual do portal"""
	portal_mesh = MeshInstance3D.new()
	portal_mesh.name = "PortalMesh"

	# Torus para visual de portal
	var torus = TorusMesh.new()
	torus.inner_radius = 1.5
	torus.outer_radius = 2.0
	torus.rings = 32
	torus.ring_segments = 16

	portal_mesh.mesh = torus
	portal_mesh.rotation.x = PI / 2  # Vertical
	portal_mesh.position.y = 2.0  # Eleva o portal acima do chão

	# Material com emissão
	var material = StandardMaterial3D.new()
	material.albedo_color = portal_color
	material.emission_enabled = true
	material.emission = portal_color
	material.emission_energy_multiplier = 2.0
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color.a = 0.8

	portal_mesh.set_surface_override_material(0, material)
	add_child(portal_mesh)

	# Centro do portal (efeito de vórtice)
	var center_mesh = MeshInstance3D.new()
	center_mesh.name = "PortalCenter"

	var plane = PlaneMesh.new()
	plane.size = Vector2(3, 3)
	center_mesh.mesh = plane
	center_mesh.rotation.x = PI / 2
	center_mesh.position.y = 2.0  # Mesmo Y do portal

	var center_material = StandardMaterial3D.new()
	center_material.albedo_color = Color(0.1, 0.2, 0.5, 0.5)
	center_material.emission_enabled = true
	center_material.emission = portal_color
	center_material.emission_energy_multiplier = 1.0
	center_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	center_mesh.set_surface_override_material(0, center_material)
	add_child(center_mesh)

	# Collision
	var collision = CollisionShape3D.new()
	var shape = CylinderShape3D.new()
	shape.radius = 2.0
	shape.height = 3.0
	collision.shape = shape
	collision.position.y = 2.0  # Mesma altura do visual
	add_child(collision)

	# Partículas
	_create_portal_particles()


func _create_portal_particles() -> void:
	"""Cria partículas do portal"""
	portal_particles = GPUParticles3D.new()
	portal_particles.name = "PortalParticles"

	var particle_mat = ParticleProcessMaterial.new()
	particle_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	particle_mat.emission_ring_radius = 2.0
	particle_mat.emission_ring_inner_radius = 1.5
	particle_mat.emission_ring_height = 0.1
	particle_mat.direction = Vector3(0, 1, 0)
	particle_mat.spread = 10.0
	particle_mat.initial_velocity_min = 1.0
	particle_mat.initial_velocity_max = 2.0
	particle_mat.gravity = Vector3.ZERO
	particle_mat.scale_min = 0.05
	particle_mat.scale_max = 0.15
	particle_mat.color = portal_color

	portal_particles.process_material = particle_mat
	portal_particles.amount = 50
	portal_particles.lifetime = 2.0
	portal_particles.emitting = true

	var quad = QuadMesh.new()
	quad.size = Vector2(0.2, 0.2)
	portal_particles.draw_pass_1 = quad

	add_child(portal_particles)


func _create_interaction_label() -> void:
	"""Cria label 3D para mostrar instruções"""
	interaction_label = Label3D.new()
	interaction_label.name = "InteractionLabel"
	interaction_label.text = ""
	interaction_label.font_size = 64
	interaction_label.position = Vector3(0, 4, 0)
	interaction_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	interaction_label.visible = false
	add_child(interaction_label)


func _update_portal_color() -> void:
	"""Atualiza cor do portal baseado em ter key"""
	if not portal_mesh:
		return

	var target_color = active_color if GameManager.has_boss_key else portal_color

	var material = portal_mesh.get_surface_override_material(0)
	if material is StandardMaterial3D:
		material.emission = target_color
		material.albedo_color = target_color
		material.albedo_color.a = 0.8


func _update_interaction_label() -> void:
	"""Atualiza texto do label de interação"""
	if not interaction_label:
		return

	if player_nearby and is_active:
		interaction_label.visible = true
		if GameManager.has_boss_key:
			interaction_label.text = "Press E to Enter"
			interaction_label.modulate = Color.GREEN
		else:
			interaction_label.text = "Find the Boss Key"
			interaction_label.modulate = Color.RED
	else:
		interaction_label.visible = false


func _on_body_entered(body: Node3D) -> void:
	"""Player entrou na área do portal"""
	if not is_active:
		return

	if body.is_in_group("player"):
		player_nearby = true


func _on_body_exited(body: Node3D) -> void:
	"""Player saiu da área do portal"""
	if body.is_in_group("player"):
		player_nearby = false


func _input(event: InputEvent) -> void:
	"""Processa input para interação com portal"""
	if not is_active or not player_nearby:
		return

	if event.is_action_pressed("interact"):  # Tecla E por padrão
		try_enter()


func try_enter() -> void:
	"""Tenta entrar no portal"""
	if not is_active:
		return

	if requires_key and not GameManager.has_boss_key:
		# Não tem key
		portal_denied.emit()
		_show_denial_effect()
		return

	# Pode entrar!
	portal_entered.emit()
	_enter_portal()


func _show_denial_effect() -> void:
	"""Efeito visual de negação"""
	if portal_mesh:
		var tween = create_tween()
		var material = portal_mesh.get_surface_override_material(0)
		if material is StandardMaterial3D:
			tween.tween_property(material, "emission", Color.RED, 0.1)
			tween.tween_property(material, "emission", portal_color, 0.3)


func _enter_portal() -> void:
	"""Processa entrada no portal"""
	# Pausa o jogo
	get_tree().paused = true

	# Efeito de transição
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	if portal_mesh:
		tween.tween_property(portal_mesh, "scale", Vector3(5, 5, 5), 0.5)

	await tween.finished

	# Aqui seria a transição para a próxima fase/boss final
	# Por enquanto, apenas mostra vitória
	GameManager.win_game()


func activate() -> void:
	"""Ativa o portal"""
	is_active = true
	visible = true

	if portal_particles:
		portal_particles.emitting = true


func deactivate() -> void:
	"""Desativa o portal"""
	is_active = false
	visible = false

	if portal_particles:
		portal_particles.emitting = false
