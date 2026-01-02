extends MiniBoss

# Mini Boss 2 - "Ravager"
# Mais rápido e agressivo que o primeiro
# HP: 400, Charges mais frequentes

func _ready() -> void:
	# Configuração do Boss 2
	boss_number = 2
	boss_name = "The Ravager"

	# Stats
	base_health = 200.0  # Será multiplicado para 400
	base_damage = 20.0

	# Comportamento - mais agressivo
	speed = 5.0
	charge_attack_enabled = true
	charge_speed = 13.0
	charge_cooldown = 4.0  # Charge mais frequente
	charge_range = 15.0
	charge_damage_multiplier = 2.5

	# Visual
	boss_scale = 1.7
	glow_color = Color(0.8, 0.2, 0.8, 1.0)  # Roxo
	glow_intensity = 2.0

	# Mesh adjustments
	mesh_scale = 0.017
	mesh_y_offset = 7.0

	super._ready()
