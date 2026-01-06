extends RefCounted
class_name BiomeConfig

## BiomeConfig - Configuração de biomas para geração procedural
## Define materiais, cores, iluminação e estética de cada bioma

# === BIOMAS DISPONÍVEIS ===
enum BiomeType {
	INDUSTRIAL,  # Fábrica abandonada, metal, concreto
	FOREST,      # Floresta sombria, terra, madeira
	DESERT,      # Deserto árido, areia, ruínas de pedra
	DUNGEON,     # Masmorra escura, pedra antiga
	TECH_LAB     # Laboratório futurista, metal brilhante
}

# Bioma atual selecionado
var current_biome: BiomeType = BiomeType.INDUSTRIAL

# Nomes dos biomas
const BIOME_NAMES = {
	BiomeType.INDUSTRIAL: "Industrial",
	BiomeType.FOREST: "Dark Forest",
	BiomeType.DESERT: "Desert Ruins",
	BiomeType.DUNGEON: "Ancient Dungeon",
	BiomeType.TECH_LAB: "Tech Laboratory"
}

# === CORES DOS BIOMAS ===
const BIOME_COLORS = {
	BiomeType.INDUSTRIAL: {
		"floor": Color(0.25, 0.25, 0.28),        # Concreto escuro
		"wall": Color(0.35, 0.33, 0.3),           # Metal enferrujado
		"obstacle_primary": Color(0.4, 0.35, 0.25),  # Caixas de metal
		"obstacle_secondary": Color(0.5, 0.3, 0.2),  # Ferrugem
		"accent": Color(0.9, 0.5, 0.1),            # Laranja de alerta
		"ambient": Color(0.4, 0.35, 0.3),
		"background": Color(0.15, 0.12, 0.1),
		"sun": Color(0.9, 0.85, 0.75)
	},
	BiomeType.FOREST: {
		"floor": Color(0.2, 0.15, 0.1),           # Terra escura
		"wall": Color(0.15, 0.2, 0.1),            # Vegetação densa
		"obstacle_primary": Color(0.35, 0.25, 0.15),  # Madeira
		"obstacle_secondary": Color(0.2, 0.3, 0.15),  # Musgo
		"accent": Color(0.4, 0.8, 0.3),            # Verde brilhante
		"ambient": Color(0.2, 0.35, 0.2),
		"background": Color(0.1, 0.15, 0.1),
		"sun": Color(0.7, 0.85, 0.6)
	},
	BiomeType.DESERT: {
		"floor": Color(0.75, 0.6, 0.4),           # Areia
		"wall": Color(0.6, 0.5, 0.35),            # Arenito
		"obstacle_primary": Color(0.7, 0.55, 0.4),   # Pedra clara
		"obstacle_secondary": Color(0.5, 0.4, 0.3),  # Pedra escura
		"accent": Color(0.95, 0.8, 0.4),           # Dourado
		"ambient": Color(0.8, 0.7, 0.5),
		"background": Color(0.85, 0.75, 0.6),
		"sun": Color(1.0, 0.95, 0.8)
	},
	BiomeType.DUNGEON: {
		"floor": Color(0.2, 0.18, 0.22),          # Pedra escura
		"wall": Color(0.25, 0.22, 0.28),          # Pedra antiga
		"obstacle_primary": Color(0.3, 0.28, 0.32),  # Pedra
		"obstacle_secondary": Color(0.18, 0.15, 0.2),  # Sombra
		"accent": Color(0.6, 0.4, 0.9),            # Púrpura mágico
		"ambient": Color(0.3, 0.25, 0.4),
		"background": Color(0.08, 0.06, 0.1),
		"sun": Color(0.6, 0.5, 0.8)
	},
	BiomeType.TECH_LAB: {
		"floor": Color(0.15, 0.15, 0.2),          # Metal escuro
		"wall": Color(0.2, 0.2, 0.25),            # Painéis metálicos
		"obstacle_primary": Color(0.25, 0.25, 0.3),  # Metal
		"obstacle_secondary": Color(0.3, 0.35, 0.4),  # Metal claro
		"accent": Color(0.2, 0.8, 1.0),            # Ciano tech
		"ambient": Color(0.3, 0.4, 0.5),
		"background": Color(0.05, 0.08, 0.12),
		"sun": Color(0.8, 0.9, 1.0)
	}
}

# === CONFIGURAÇÕES DE ILUMINAÇÃO ===
const LIGHTING_CONFIGS = {
	BiomeType.INDUSTRIAL: {
		"sun_energy": 0.8,
		"sun_rotation": Vector3(-45, 30, 0),
		"ambient_energy": 0.3,
		"fog_enabled": true,
		"fog_density": 0.01,
		"fog_color": Color(0.3, 0.25, 0.2)
	},
	BiomeType.FOREST: {
		"sun_energy": 0.5,
		"sun_rotation": Vector3(-60, 45, 0),
		"ambient_energy": 0.4,
		"fog_enabled": true,
		"fog_density": 0.02,
		"fog_color": Color(0.2, 0.3, 0.2)
	},
	BiomeType.DESERT: {
		"sun_energy": 1.2,
		"sun_rotation": Vector3(-35, 20, 0),
		"ambient_energy": 0.5,
		"fog_enabled": true,
		"fog_density": 0.005,
		"fog_color": Color(0.8, 0.7, 0.5)
	},
	BiomeType.DUNGEON: {
		"sun_energy": 0.3,
		"sun_rotation": Vector3(-70, 60, 0),
		"ambient_energy": 0.2,
		"fog_enabled": true,
		"fog_density": 0.03,
		"fog_color": Color(0.15, 0.1, 0.2)
	},
	BiomeType.TECH_LAB: {
		"sun_energy": 0.6,
		"sun_rotation": Vector3(-50, 0, 0),
		"ambient_energy": 0.5,
		"fog_enabled": false,
		"fog_density": 0.0,
		"fog_color": Color.WHITE
	}
}

# === PESOS DE OBSTÁCULOS POR BIOMA ===
# Quais tipos de obstáculos são mais comuns em cada bioma
const OBSTACLE_WEIGHTS_BY_BIOME = {
	BiomeType.INDUSTRIAL: {
		# MapGenerator.ObstacleType values
		0: 0.2,  # BOX_SMALL - caixas de metal pequenas
		1: 0.25, # BOX_MEDIUM - containers
		2: 0.15, # BOX_LARGE - grandes containers
		3: 0.1,  # PILLAR - pilares de suporte
		4: 0.15, # WALL_LOW - barricadas
		5: 0.05, # WALL_TALL - paredes de metal
		6: 0.05, # CRATE_CLUSTER - pilhas de caixas
		7: 0.05  # BARRIER - barreiras
	},
	BiomeType.FOREST: {
		0: 0.15, # Pedras pequenas
		1: 0.1,  # Pedras médias
		2: 0.05, # Rochas grandes
		3: 0.25, # Troncos de árvore
		4: 0.2,  # Troncos caídos
		5: 0.1,  # Árvores densas
		6: 0.1,  # Arbustos
		7: 0.05  # Raízes
	},
	BiomeType.DESERT: {
		0: 0.2,  # Pedras pequenas
		1: 0.2,  # Rochas médias
		2: 0.15, # Formações rochosas
		3: 0.1,  # Pilares de pedra
		4: 0.15, # Ruínas baixas
		5: 0.1,  # Paredes de ruínas
		6: 0.05, # Escombros
		7: 0.05  # Barricadas de pedra
	},
	BiomeType.DUNGEON: {
		0: 0.1,  # Pedras caídas
		1: 0.15, # Blocos de pedra
		2: 0.1,  # Sarcófagos
		3: 0.2,  # Colunas antigas
		4: 0.15, # Paredes quebradas
		5: 0.15, # Muros antigos
		6: 0.1,  # Escombros
		7: 0.05  # Altares
	},
	BiomeType.TECH_LAB: {
		0: 0.15, # Terminais pequenos
		1: 0.2,  # Consoles médios
		2: 0.15, # Servidores grandes
		3: 0.15, # Pilares de energia
		4: 0.15, # Painéis de controle
		5: 0.1,  # Portas de segurança
		6: 0.05, # Equipamentos
		7: 0.05  # Barreiras de laser (desativadas)
	}
}

# === MATERIAIS ESPECIAIS ===
# Propriedades adicionais de materiais por bioma
const MATERIAL_PROPERTIES = {
	BiomeType.INDUSTRIAL: {
		"metallic": 0.6,
		"roughness": 0.7,
		"emission_floor": false,
		"emission_obstacles": false
	},
	BiomeType.FOREST: {
		"metallic": 0.0,
		"roughness": 0.9,
		"emission_floor": false,
		"emission_obstacles": false
	},
	BiomeType.DESERT: {
		"metallic": 0.1,
		"roughness": 0.8,
		"emission_floor": false,
		"emission_obstacles": false
	},
	BiomeType.DUNGEON: {
		"metallic": 0.2,
		"roughness": 0.85,
		"emission_floor": false,
		"emission_obstacles": true,
		"emission_color": Color(0.3, 0.2, 0.5),
		"emission_energy": 0.2
	},
	BiomeType.TECH_LAB: {
		"metallic": 0.8,
		"roughness": 0.3,
		"emission_floor": true,
		"emission_floor_color": Color(0.1, 0.3, 0.4),
		"emission_floor_energy": 0.1,
		"emission_obstacles": true,
		"emission_color": Color(0.1, 0.5, 0.8),
		"emission_energy": 0.3
	}
}


func _init() -> void:
	# Seed inicial para consistência
	pass


## Seleciona um bioma aleatório
func select_random_biome() -> void:
	var biomes = BiomeType.values()
	current_biome = biomes[randi() % biomes.size()]
	print("[BiomeConfig] Bioma aleatório selecionado: ", get_biome_name())


## Seleciona um bioma específico
func select_biome(biome_index: int) -> void:
	var biomes = BiomeType.values()
	if biome_index >= 0 and biome_index < biomes.size():
		current_biome = biomes[biome_index]
	else:
		push_warning("[BiomeConfig] Índice de bioma inválido: " + str(biome_index))
		current_biome = BiomeType.INDUSTRIAL


## Retorna o nome do bioma atual
func get_biome_name() -> String:
	return BIOME_NAMES.get(current_biome, "Unknown")


## Retorna o tipo do bioma atual
func get_biome_type() -> BiomeType:
	return current_biome


## Cria e retorna o material do chão
func get_floor_material() -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	var colors = BIOME_COLORS[current_biome]
	var props = MATERIAL_PROPERTIES[current_biome]

	material.albedo_color = colors.floor
	material.metallic = props.metallic
	material.roughness = props.roughness

	# Emissão do chão (para Tech Lab)
	if props.get("emission_floor", false):
		material.emission_enabled = true
		material.emission = props.get("emission_floor_color", Color.WHITE)
		material.emission_energy_multiplier = props.get("emission_floor_energy", 0.1)

	# Adiciona textura procedural sutil
	_add_subtle_texture(material, colors.floor)

	return material


## Cria e retorna o material das paredes
func get_wall_material() -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	var colors = BIOME_COLORS[current_biome]
	var props = MATERIAL_PROPERTIES[current_biome]

	material.albedo_color = colors.wall
	material.metallic = props.metallic
	material.roughness = props.roughness

	return material


## Cria e retorna material para um tipo de obstáculo
func get_obstacle_material(obs_type: int) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	var colors = BIOME_COLORS[current_biome]
	var props = MATERIAL_PROPERTIES[current_biome]

	# Alterna entre cores primária e secundária
	if obs_type % 2 == 0:
		material.albedo_color = colors.obstacle_primary
	else:
		material.albedo_color = colors.obstacle_secondary

	material.metallic = props.metallic
	material.roughness = props.roughness

	# Emissão para alguns biomas
	if props.get("emission_obstacles", false):
		# Apenas alguns obstáculos têm emissão
		if randf() < 0.3:
			material.emission_enabled = true
			material.emission = props.get("emission_color", colors.accent)
			material.emission_energy_multiplier = props.get("emission_energy", 0.2)

	return material


## Retorna pesos de obstáculos para o bioma atual
func get_obstacle_weights() -> Dictionary:
	return OBSTACLE_WEIGHTS_BY_BIOME.get(current_biome, OBSTACLE_WEIGHTS_BY_BIOME[BiomeType.INDUSTRIAL])


## Retorna configuração do sol
func get_sun_config() -> Dictionary:
	var lighting = LIGHTING_CONFIGS[current_biome]
	var colors = BIOME_COLORS[current_biome]

	return {
		"color": colors.sun,
		"energy": lighting.sun_energy,
		"rotation": Vector3(
			deg_to_rad(lighting.sun_rotation.x),
			deg_to_rad(lighting.sun_rotation.y),
			deg_to_rad(lighting.sun_rotation.z)
		)
	}


## Retorna configuração do ambiente
func get_environment_config() -> Dictionary:
	var lighting = LIGHTING_CONFIGS[current_biome]
	var colors = BIOME_COLORS[current_biome]

	var config = {
		"background_color": colors.background,
		"ambient_color": colors.ambient,
		"ambient_energy": lighting.ambient_energy,
		"fog_enabled": lighting.fog_enabled
	}

	if lighting.fog_enabled:
		config["fog_color"] = lighting.fog_color
		config["fog_density"] = lighting.fog_density

	return config


## Retorna cor de destaque do bioma
func get_accent_color() -> Color:
	return BIOME_COLORS[current_biome].accent


## Retorna todas as cores do bioma
func get_all_colors() -> Dictionary:
	return BIOME_COLORS[current_biome].duplicate()


## Adiciona textura procedural sutil ao material
func _add_subtle_texture(material: StandardMaterial3D, base_color: Color) -> void:
	# Cria uma textura de ruído procedural simples
	var noise_texture = NoiseTexture2D.new()
	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.02
	noise_texture.noise = noise
	noise_texture.width = 256
	noise_texture.height = 256

	# Usa como detail texture para adicionar variação sutil
	# Nota: Em produção, seria melhor usar texturas pré-feitas
	# material.detail_enabled = true
	# material.detail_albedo = noise_texture


## Retorna dados completos do bioma para debug/UI
func get_biome_data() -> Dictionary:
	return {
		"type": current_biome,
		"name": get_biome_name(),
		"colors": BIOME_COLORS[current_biome].duplicate(),
		"lighting": LIGHTING_CONFIGS[current_biome].duplicate(),
		"obstacle_weights": get_obstacle_weights().duplicate()
	}


## Retorna lista de todos os biomas disponíveis
static func get_available_biomes() -> Array[Dictionary]:
	var biomes: Array[Dictionary] = []
	for biome_type in BiomeType.values():
		biomes.append({
			"type": biome_type,
			"name": BIOME_NAMES[biome_type]
		})
	return biomes


## Cria material especial para marcadores de boss arena
func get_boss_arena_material() -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	var colors = BIOME_COLORS[current_biome]

	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(colors.accent.r, colors.accent.g, colors.accent.b, 0.2)
	material.emission_enabled = true
	material.emission = colors.accent
	material.emission_energy_multiplier = 0.5

	return material


## Cria material para spawn points (debug visual)
func get_spawn_point_material() -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	var colors = BIOME_COLORS[current_biome]

	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.2, 0.8, 0.3, 0.5)
	material.emission_enabled = true
	material.emission = Color(0.2, 0.8, 0.3)
	material.emission_energy_multiplier = 0.3

	return material


## Cria material para zona do portal
func get_portal_zone_material() -> StandardMaterial3D:
	var material = StandardMaterial3D.new()

	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.2, 0.5, 1.0, 0.3)
	material.emission_enabled = true
	material.emission = Color(0.2, 0.5, 1.0)
	material.emission_energy_multiplier = 0.8

	return material
