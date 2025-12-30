extends Node3D

# Impact Particles - Partículas de impacto de balas

@onready var particles: GPUParticles3D = $GPUParticles3D

func _ready() -> void:
	# Emite automaticamente ao spawnar
	if particles:
		particles.emitting = true

	# Auto-destroi após 1 segundo
	await get_tree().create_timer(1.0).timeout
	queue_free()
