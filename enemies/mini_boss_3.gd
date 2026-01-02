extends MiniBoss

# Mini Boss 3 - "Destroyer"
# Muito forte e resistente
# HP: 700, Ataques devastadores

func _ready() -> void:
	# Configuração do Boss 3
	boss_number = 3
	boss_name = "The Destroyer"

	# Stats
	base_health = 200.0  # Será calculado para 700
	base_damage = 20.0

	# Comportamento - brutal
	speed = 4.5
	charge_attack_enabled = true
	charge_speed = 15.0
	charge_cooldown = 3.5
	charge_range = 18.0
	charge_damage_multiplier = 3.0

	# Attack range maior
	attack_range = 3.5
	attack_cooldown = 1.0

	# Visual
	boss_scale = 1.9
	glow_color = Color(0.2, 0.8, 0.2, 1.0)  # Verde tóxico
	glow_intensity = 2.5

	# Mesh adjustments
	mesh_scale = 0.019
	mesh_y_offset = 8.0

	super._ready()
