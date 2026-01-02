extends MiniBoss

# Mini Boss 4 - "Overlord"
# O boss final, extremamente poderoso
# HP: 1000, Sempre dropa key

func _ready() -> void:
	# Configuração do Boss 4 - FINAL
	boss_number = 4
	boss_name = "The Overlord"
	is_last_boss = true  # Sempre dropa key

	# Stats
	base_health = 200.0  # Será calculado para 1000
	base_damage = 20.0

	# Comportamento - o mais perigoso
	speed = 5.5
	charge_attack_enabled = true
	charge_speed = 18.0
	charge_cooldown = 3.0
	charge_range = 20.0
	charge_damage_multiplier = 3.5

	# Attack muito forte
	attack_range = 4.0
	attack_cooldown = 0.8

	# Visual - vermelho intenso
	boss_scale = 2.2
	glow_color = Color(1.0, 0.1, 0.1, 1.0)  # Vermelho sangue
	glow_intensity = 3.0

	# Mesh adjustments
	mesh_scale = 0.022
	mesh_y_offset = 9.0

	super._ready()
