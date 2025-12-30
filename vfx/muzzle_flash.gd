extends Node3D

# Muzzle Flash - Efeito visual de disparo
# Combina partículas e luz para criar flash realista

@onready var particles: GPUParticles3D = $GPUParticles3D
@onready var light: OmniLight3D = $OmniLight3D

func _ready() -> void:
	# Inicialmente invisível
	visible = false

	# Configura partículas
	if particles:
		particles.emitting = false
		particles.one_shot = true

func trigger() -> void:
	"""Ativa o muzzle flash"""
	visible = true

	# Emite partículas
	if particles:
		particles.restart()
		particles.emitting = true

	# Fade out da luz
	if light:
		light.light_energy = 2.0
		var tween = create_tween()
		tween.tween_property(light, "light_energy", 0.0, 0.1)

	# Esconde após 0.1 segundos
	await get_tree().create_timer(0.1).timeout
	visible = false
