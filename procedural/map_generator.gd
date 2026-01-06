extends Node3D
class_name MapGenerator

## MapGenerator - Sistema de geração procedural de arena
## Gera uma arena 100x100m com obstáculos, boss arenas, e navegação automática.
##
## O sistema usa um grid de 10x10 células, cada uma com 10m de tamanho.
## A geração é determinística baseada em seed para reprodutibilidade.

# === SIGNALS ===
signal generation_started()
signal generation_progress(step: String, progress: float)
signal generation_completed(seed_used: int)
signal navmesh_baked()

# === CONFIGURAÇÃO DO GRID ===
const GRID_SIZE: int = 10  # 10x10 grid
const CELL_SIZE: float = 10.0  # Cada célula = 10m
const ARENA_SIZE: float = GRID_SIZE * CELL_SIZE  # 100m total
const HALF_ARENA: float = ARENA_SIZE / 2.0  # 50m do centro até borda

# === ENUMS ===
enum CellType {
	EMPTY,
	OBSTACLE,
	BOSS_ARENA,
	PORTAL_ZONE,
	PLAYER_SPAWN,
	SPAWN_POINT,
	CORRIDOR  # Zona garantida de passagem
}

enum ObstacleType {
	BOX_SMALL,      # 2x2x2
	BOX_MEDIUM,     # 3x3x3
	BOX_LARGE,      # 4x3x4
	PILLAR,         # Coluna fina e alta
	WALL_LOW,       # Parede baixa para cover
	WALL_TALL,      # Parede alta bloqueando visão
	CRATE_CLUSTER,  # Grupo de caixas pequenas
	BARRIER         # Barricada angular
}

# === CONFIGURAÇÃO DE GERAÇÃO ===
@export_group("Generation Settings")
@export var obstacle_density: float = 0.35  # 35% de ocupação base
@export var min_obstacles: int = 25
@export var max_obstacles: int = 45
@export var boss_arena_radius: float = 12.0  # Raio das arenas de boss
@export var safe_spawn_radius: float = 8.0  # Área segura ao redor do spawn

@export_group("Biome Settings")
@export var current_biome: int = -1  # -1 = random

# === ESTADO DO GRID ===
var grid: Array[Array] = []  # Grid 2D de CellTypes
var cell_obstacles: Array[Array] = []  # Referências aos obstáculos em cada célula
var generated_obstacles: Array[Node3D] = []
var current_seed: int = 0

# === POSIÇÕES IMPORTANTES ===
var player_spawn_position: Vector3 = Vector3.ZERO
var portal_position: Vector3 = Vector3.ZERO
var boss_arena_centers: Array[Vector3] = []
var spawn_points: Array[Vector3] = []

# === REFERÊNCIAS ===
var floor_node: StaticBody3D = null
var walls_container: Node3D = null
var obstacles_container: Node3D = null
var navigation_region: NavigationRegion3D = null
var lighting_container: Node3D = null
var spawn_points_container: Node3D = null
var boss_arenas_container: Node3D = null

# === BIOME CONFIG ===
var biome_config: BiomeConfig = null

# === A* PARA VALIDAÇÃO ===
var astar: AStar3D = null


func _ready() -> void:
	# Inicializa o AStar para validação de paths
	astar = AStar3D.new()

	# Cria containers
	_create_containers()


func _create_containers() -> void:
	"""Cria os containers para organizar os nós gerados"""
	walls_container = Node3D.new()
	walls_container.name = "Walls"
	add_child(walls_container)

	obstacles_container = Node3D.new()
	obstacles_container.name = "Obstacles"
	add_child(obstacles_container)

	lighting_container = Node3D.new()
	lighting_container.name = "Lighting"
	add_child(lighting_container)

	spawn_points_container = Node3D.new()
	spawn_points_container.name = "SpawnPoints"
	add_child(spawn_points_container)

	boss_arenas_container = Node3D.new()
	boss_arenas_container.name = "BossArenas"
	add_child(boss_arenas_container)


## Gera o mapa completo com seed opcional
## Se seed_value = -1, gera um seed aleatório
func generate_map(seed_value: int = -1) -> void:
	generation_started.emit()

	# Limpa geração anterior
	_clear_previous_generation()

	# Define seed
	if seed_value == -1:
		seed_value = randi()
	current_seed = seed_value
	seed(current_seed)

	print("[MapGenerator] Gerando mapa com seed: ", current_seed)

	# Seleciona bioma
	_select_biome()
	generation_progress.emit("Bioma selecionado", 0.1)

	# Inicializa grid
	_initialize_grid()
	generation_progress.emit("Grid inicializado", 0.15)

	# Gera chão
	_generate_floor()
	generation_progress.emit("Chão gerado", 0.2)

	# Gera paredes externas
	_generate_outer_walls()
	generation_progress.emit("Paredes geradas", 0.3)

	# Define posição do player (borda)
	_define_player_spawn()
	generation_progress.emit("Spawn do player definido", 0.35)

	# Define arenas de boss (4 distribuídas)
	_define_boss_arenas()
	generation_progress.emit("Arenas de boss definidas", 0.4)

	# Define localização do portal (oposta ao player)
	_define_portal_location()
	generation_progress.emit("Portal definido", 0.45)

	# Marca corredores seguros (garantem conectividade)
	_mark_safe_corridors()
	generation_progress.emit("Corredores seguros marcados", 0.5)

	# Coloca obstáculos
	_place_obstacles()
	generation_progress.emit("Obstáculos colocados", 0.65)

	# Valida conectividade
	var valid = _validate_connectivity()
	if not valid:
		print("[MapGenerator] Mapa inválido, regenerando...")
		# Tenta novamente com outro seed
		generate_map(current_seed + 1)
		return
	generation_progress.emit("Conectividade validada", 0.75)

	# Cria spawn points para inimigos
	_create_spawn_points()
	generation_progress.emit("Spawn points criados", 0.8)

	# Configura iluminação do bioma
	_setup_lighting()
	generation_progress.emit("Iluminação configurada", 0.85)

	# Cria efeitos visuais das boss arenas
	_create_boss_arena_visuals()
	generation_progress.emit("Visuais das arenas criados", 0.9)

	# Cria navegação (NavMesh)
	_setup_navigation()
	generation_progress.emit("Navegação configurada", 0.95)

	# Faz bake do NavMesh
	await _bake_navmesh()
	generation_progress.emit("NavMesh baked", 1.0)

	print("[MapGenerator] Mapa gerado com sucesso!")
	print("  - Player spawn: ", player_spawn_position)
	print("  - Portal: ", portal_position)
	print("  - Boss arenas: ", boss_arena_centers.size())
	print("  - Obstáculos: ", generated_obstacles.size())
	print("  - Spawn points: ", spawn_points.size())

	generation_completed.emit(current_seed)


func _clear_previous_generation() -> void:
	"""Limpa toda a geração anterior"""
	# Limpa grid
	grid.clear()
	cell_obstacles.clear()

	# Remove obstáculos gerados
	for obstacle in generated_obstacles:
		if is_instance_valid(obstacle):
			obstacle.queue_free()
	generated_obstacles.clear()

	# Limpa posições
	boss_arena_centers.clear()
	spawn_points.clear()

	# Remove floor se existir
	if floor_node:
		floor_node.queue_free()
		floor_node = null

	# Limpa containers
	for container in [walls_container, obstacles_container, lighting_container,
					  spawn_points_container, boss_arenas_container]:
		if container:
			for child in container.get_children():
				child.queue_free()

	# Remove navigation region
	if navigation_region:
		navigation_region.queue_free()
		navigation_region = null


func _select_biome() -> void:
	"""Seleciona o bioma para esta geração"""
	if biome_config == null:
		biome_config = BiomeConfig.new()

	if current_biome == -1:
		biome_config.select_random_biome()
	else:
		biome_config.select_biome(current_biome)

	print("[MapGenerator] Bioma selecionado: ", biome_config.get_biome_name())


func _initialize_grid() -> void:
	"""Inicializa o grid com células vazias"""
	grid.clear()
	cell_obstacles.clear()

	for x in GRID_SIZE:
		var row: Array[CellType] = []
		var obs_row: Array[Node3D] = []
		for y in GRID_SIZE:
			row.append(CellType.EMPTY)
			obs_row.append(null)
		grid.append(row)
		cell_obstacles.append(obs_row)


func _generate_floor() -> void:
	"""Gera o chão da arena"""
	floor_node = StaticBody3D.new()
	floor_node.name = "Floor"
	floor_node.collision_layer = 4  # World layer
	floor_node.collision_mask = 0

	# Mesh do chão
	var mesh_instance = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(ARENA_SIZE + 2, 0.5, ARENA_SIZE + 2)  # +2 para margem
	mesh_instance.mesh = box_mesh

	# Material do bioma
	var material = biome_config.get_floor_material()
	mesh_instance.material_override = material

	floor_node.add_child(mesh_instance)

	# Collision
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(ARENA_SIZE + 2, 0.5, ARENA_SIZE + 2)
	collision.shape = shape
	floor_node.add_child(collision)

	add_child(floor_node)


func _generate_outer_walls() -> void:
	"""Gera as paredes externas da arena"""
	var wall_height = 5.0
	var wall_thickness = 1.0

	var wall_data = [
		# [nome, posição, tamanho]
		["WallNorth", Vector3(0, wall_height/2, -HALF_ARENA - wall_thickness/2),
		 Vector3(ARENA_SIZE + 2, wall_height, wall_thickness)],
		["WallSouth", Vector3(0, wall_height/2, HALF_ARENA + wall_thickness/2),
		 Vector3(ARENA_SIZE + 2, wall_height, wall_thickness)],
		["WallEast", Vector3(HALF_ARENA + wall_thickness/2, wall_height/2, 0),
		 Vector3(wall_thickness, wall_height, ARENA_SIZE + 2)],
		["WallWest", Vector3(-HALF_ARENA - wall_thickness/2, wall_height/2, 0),
		 Vector3(wall_thickness, wall_height, ARENA_SIZE + 2)]
	]

	var wall_material = biome_config.get_wall_material()

	for data in wall_data:
		var wall = _create_wall(data[0], data[1], data[2], wall_material)
		walls_container.add_child(wall)


func _create_wall(wall_name: String, pos: Vector3, size: Vector3, material: Material) -> StaticBody3D:
	"""Cria uma parede estática"""
	var wall = StaticBody3D.new()
	wall.name = wall_name
	wall.collision_layer = 4
	wall.collision_mask = 0
	wall.position = pos

	# Mesh
	var mesh = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = size
	mesh.mesh = box_mesh
	mesh.material_override = material
	wall.add_child(mesh)

	# Collision
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	wall.add_child(collision)

	return wall


func _define_player_spawn() -> void:
	"""Define a posição de spawn do player (sempre em uma borda)"""
	# Escolhe uma borda aleatória
	var edges = [
		Vector3(0, 1, -HALF_ARENA + 5),  # Norte
		Vector3(0, 1, HALF_ARENA - 5),    # Sul
		Vector3(-HALF_ARENA + 5, 1, 0),   # Oeste
		Vector3(HALF_ARENA - 5, 1, 0)     # Leste
	]

	player_spawn_position = edges[randi() % edges.size()]

	# Marca células ao redor do spawn como PLAYER_SPAWN (safe zone)
	var cell = _world_to_grid(player_spawn_position)
	_mark_safe_zone(cell.x, cell.y, 2)  # Raio de 2 células
	grid[cell.x][cell.y] = CellType.PLAYER_SPAWN


func _define_boss_arenas() -> void:
	"""Define as 4 arenas de boss distribuídas pelo mapa"""
	boss_arena_centers.clear()

	# Distribuição em quadrantes (evitando cantos extremos)
	var quadrants = [
		Vector2(-0.6, -0.6),  # Noroeste
		Vector2(0.6, -0.6),   # Nordeste
		Vector2(-0.6, 0.6),   # Sudoeste
		Vector2(0.6, 0.6)     # Sudeste
	]

	# Embaralha quadrantes para variedade
	quadrants.shuffle()

	for i in range(4):
		# Posição base do quadrante
		var base_x = quadrants[i].x * HALF_ARENA * 0.7
		var base_z = quadrants[i].y * HALF_ARENA * 0.7

		# Adiciona pequena variação
		var offset_x = randf_range(-5, 5)
		var offset_z = randf_range(-5, 5)

		var arena_pos = Vector3(
			clamp(base_x + offset_x, -HALF_ARENA + boss_arena_radius + 5, HALF_ARENA - boss_arena_radius - 5),
			0,
			clamp(base_z + offset_z, -HALF_ARENA + boss_arena_radius + 5, HALF_ARENA - boss_arena_radius - 5)
		)

		boss_arena_centers.append(arena_pos)

		# Marca células da arena no grid
		_mark_boss_arena(arena_pos, i)


func _mark_boss_arena(center: Vector3, arena_index: int) -> void:
	"""Marca as células de uma boss arena como zonas seguras"""
	var center_cell = _world_to_grid(center)
	var radius_cells = int(boss_arena_radius / CELL_SIZE) + 1

	for dx in range(-radius_cells, radius_cells + 1):
		for dy in range(-radius_cells, radius_cells + 1):
			var gx = center_cell.x + dx
			var gy = center_cell.y + dy

			if _is_valid_cell(gx, gy):
				# Verifica se está dentro do raio circular
				var cell_world = _grid_to_world(gx, gy)
				if center.distance_to(cell_world) <= boss_arena_radius:
					grid[gx][gy] = CellType.BOSS_ARENA


func _define_portal_location() -> void:
	"""Define a localização do portal (oposta ao spawn do player)"""
	# Portal fica no lado oposto ao player
	portal_position = -player_spawn_position
	portal_position.y = 0.5  # Altura do portal

	# Marca célula do portal
	var cell = _world_to_grid(portal_position)
	if _is_valid_cell(cell.x, cell.y):
		grid[cell.x][cell.y] = CellType.PORTAL_ZONE

	# Marca área ao redor como segura
	_mark_safe_zone(cell.x, cell.y, 2)


func _mark_safe_zone(center_x: int, center_y: int, radius: int) -> void:
	"""Marca uma zona circular como segura (sem obstáculos)"""
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			var gx = center_x + dx
			var gy = center_y + dy
			if _is_valid_cell(gx, gy):
				if grid[gx][gy] == CellType.EMPTY:
					grid[gx][gy] = CellType.CORRIDOR


func _mark_safe_corridors() -> void:
	"""Marca corredores seguros conectando áreas importantes"""
	# Lista de pontos importantes
	var important_points: Array[Vector2i] = []

	# Adiciona spawn do player
	var player_cell = _world_to_grid(player_spawn_position)
	important_points.append(Vector2i(player_cell.x, player_cell.y))

	# Adiciona portal
	var portal_cell = _world_to_grid(portal_position)
	important_points.append(Vector2i(portal_cell.x, portal_cell.y))

	# Adiciona centros das boss arenas
	for arena_center in boss_arena_centers:
		var cell = _world_to_grid(arena_center)
		important_points.append(Vector2i(cell.x, cell.y))

	# Cria corredores entre pontos adjacentes na lista
	for i in range(important_points.size() - 1):
		_create_corridor(important_points[i], important_points[i + 1])

	# Conecta último ponto ao primeiro para garantir ciclo
	_create_corridor(important_points[important_points.size() - 1], important_points[0])


func _create_corridor(from: Vector2i, to: Vector2i) -> void:
	"""Cria um corredor seguro entre dois pontos usando linha reta com desvios"""
	var current = Vector2(from.x, from.y)
	var target = Vector2(to.x, to.y)

	while current.distance_to(target) > 1.0:
		# Direção predominante
		var diff = target - current

		# Move na direção de maior diferença (L-shaped corridors)
		if abs(diff.x) > abs(diff.y):
			current.x += sign(diff.x)
		else:
			current.y += sign(diff.y)

		var gx = int(current.x)
		var gy = int(current.y)

		if _is_valid_cell(gx, gy):
			if grid[gx][gy] == CellType.EMPTY:
				grid[gx][gy] = CellType.CORRIDOR

			# Adiciona largura ao corredor (células adjacentes)
			for dx in [-1, 0, 1]:
				var adj_x = gx + dx
				if _is_valid_cell(adj_x, gy) and grid[adj_x][gy] == CellType.EMPTY:
					grid[adj_x][gy] = CellType.CORRIDOR


func _place_obstacles() -> void:
	"""Coloca obstáculos procedurais no grid"""
	var obstacle_count = randi_range(min_obstacles, max_obstacles)
	var placed = 0
	var attempts = 0
	var max_attempts = obstacle_count * 5

	while placed < obstacle_count and attempts < max_attempts:
		attempts += 1

		# Escolhe célula aleatória
		var x = randi_range(1, GRID_SIZE - 2)
		var y = randi_range(1, GRID_SIZE - 2)

		# Verifica se pode colocar obstáculo
		if not _can_place_obstacle(x, y):
			continue

		# Escolhe tipo de obstáculo
		var obs_type = _choose_obstacle_type()

		# Cria obstáculo
		var obstacle = _create_obstacle(x, y, obs_type)
		if obstacle:
			grid[x][y] = CellType.OBSTACLE
			cell_obstacles[x][y] = obstacle
			generated_obstacles.append(obstacle)
			obstacles_container.add_child(obstacle)
			placed += 1

	print("[MapGenerator] Colocados ", placed, " obstáculos em ", attempts, " tentativas")


func _can_place_obstacle(x: int, y: int) -> bool:
	"""Verifica se pode colocar um obstáculo na célula"""
	# Não coloca em células não-vazias
	if grid[x][y] != CellType.EMPTY:
		return false

	# Não coloca muito perto das bordas
	if x <= 0 or x >= GRID_SIZE - 1 or y <= 0 or y >= GRID_SIZE - 1:
		return false

	# Verifica vizinhos para evitar bloqueio total
	var empty_neighbors = 0
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var nx = x + dx
			var ny = y + dy
			if _is_valid_cell(nx, ny) and grid[nx][ny] != CellType.OBSTACLE:
				empty_neighbors += 1

	# Requer pelo menos 4 vizinhos não-obstáculo
	return empty_neighbors >= 4


func _choose_obstacle_type() -> ObstacleType:
	"""Escolhe um tipo de obstáculo baseado em pesos"""
	var weights = biome_config.get_obstacle_weights()
	var total = 0.0
	for w in weights.values():
		total += w

	var roll = randf() * total
	var cumulative = 0.0

	for type in weights:
		cumulative += weights[type]
		if roll <= cumulative:
			return type

	return ObstacleType.BOX_MEDIUM


func _create_obstacle(grid_x: int, grid_y: int, obs_type: ObstacleType) -> StaticBody3D:
	"""Cria um obstáculo físico na posição do grid"""
	var world_pos = _grid_to_world(grid_x, grid_y)

	# Adiciona pequena variação na posição dentro da célula
	world_pos.x += randf_range(-2, 2)
	world_pos.z += randf_range(-2, 2)

	var obstacle = StaticBody3D.new()
	obstacle.collision_layer = 4
	obstacle.collision_mask = 0

	# Define tamanho baseado no tipo
	var size = _get_obstacle_size(obs_type)
	world_pos.y = size.y / 2  # Ajusta altura
	obstacle.position = world_pos

	# Adiciona rotação aleatória para alguns tipos
	if obs_type in [ObstacleType.BOX_SMALL, ObstacleType.BOX_MEDIUM, ObstacleType.CRATE_CLUSTER]:
		obstacle.rotation.y = randf() * TAU
	elif obs_type == ObstacleType.BARRIER:
		obstacle.rotation.y = randf_range(-0.5, 0.5)

	# Mesh
	var mesh_instance = MeshInstance3D.new()
	var mesh = _create_obstacle_mesh(obs_type, size)
	mesh_instance.mesh = mesh
	mesh_instance.material_override = biome_config.get_obstacle_material(obs_type)
	obstacle.add_child(mesh_instance)

	# Collision
	var collision = CollisionShape3D.new()
	collision.shape = _create_obstacle_collision(obs_type, size)
	obstacle.add_child(collision)

	return obstacle


func _get_obstacle_size(obs_type: ObstacleType) -> Vector3:
	"""Retorna o tamanho base do obstáculo"""
	match obs_type:
		ObstacleType.BOX_SMALL:
			return Vector3(2, 2, 2)
		ObstacleType.BOX_MEDIUM:
			return Vector3(3, 3, 3)
		ObstacleType.BOX_LARGE:
			return Vector3(4, 3, 4)
		ObstacleType.PILLAR:
			return Vector3(1.5, 5, 1.5)
		ObstacleType.WALL_LOW:
			return Vector3(6, 1.5, 1)
		ObstacleType.WALL_TALL:
			return Vector3(5, 4, 1)
		ObstacleType.CRATE_CLUSTER:
			return Vector3(4, 2.5, 4)
		ObstacleType.BARRIER:
			return Vector3(4, 2, 2)
		_:
			return Vector3(2, 2, 2)


func _create_obstacle_mesh(obs_type: ObstacleType, size: Vector3) -> Mesh:
	"""Cria a mesh apropriada para o tipo de obstáculo"""
	match obs_type:
		ObstacleType.PILLAR:
			var cylinder = CylinderMesh.new()
			cylinder.top_radius = size.x / 2
			cylinder.bottom_radius = size.x / 2
			cylinder.height = size.y
			return cylinder
		ObstacleType.CRATE_CLUSTER:
			# Box básico, poderia ser mais complexo
			var box = BoxMesh.new()
			box.size = size
			return box
		_:
			var box = BoxMesh.new()
			box.size = size
			return box


func _create_obstacle_collision(obs_type: ObstacleType, size: Vector3) -> Shape3D:
	"""Cria a collision shape apropriada"""
	match obs_type:
		ObstacleType.PILLAR:
			var cylinder = CylinderShape3D.new()
			cylinder.radius = size.x / 2
			cylinder.height = size.y
			return cylinder
		_:
			var box = BoxShape3D.new()
			box.size = size
			return box


func _validate_connectivity() -> bool:
	"""Valida se todas as áreas importantes estão conectadas usando A*"""
	astar.clear()

	# Adiciona pontos navegáveis ao A*
	var point_id = 0
	var point_ids: Dictionary = {}  # Vector2i -> int

	for x in GRID_SIZE:
		for y in GRID_SIZE:
			if grid[x][y] != CellType.OBSTACLE:
				astar.add_point(point_id, Vector3(x, 0, y))
				point_ids[Vector2i(x, y)] = point_id
				point_id += 1

	# Conecta pontos adjacentes
	for x in GRID_SIZE:
		for y in GRID_SIZE:
			var cell = Vector2i(x, y)
			if cell not in point_ids:
				continue

			var current_id = point_ids[cell]

			# Conecta com vizinhos cardinais
			for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var neighbor = cell + offset
				if neighbor in point_ids:
					var neighbor_id = point_ids[neighbor]
					if not astar.are_points_connected(current_id, neighbor_id):
						astar.connect_points(current_id, neighbor_id)

	# Verifica conectividade entre todos os pontos importantes
	var player_cell = Vector2i(_world_to_grid(player_spawn_position).x, _world_to_grid(player_spawn_position).y)
	var portal_cell = Vector2i(_world_to_grid(portal_position).x, _world_to_grid(portal_position).y)

	if player_cell not in point_ids or portal_cell not in point_ids:
		print("[MapGenerator] Spawn ou portal em célula inválida!")
		return false

	var player_id = point_ids[player_cell]
	var portal_id = point_ids[portal_cell]

	# Verifica path player -> portal
	var path = astar.get_point_path(player_id, portal_id)
	if path.is_empty():
		print("[MapGenerator] Sem caminho player -> portal!")
		return false

	# Verifica path para cada boss arena
	for arena_center in boss_arena_centers:
		var arena_cell = Vector2i(_world_to_grid(arena_center).x, _world_to_grid(arena_center).y)
		if arena_cell not in point_ids:
			continue

		var arena_id = point_ids[arena_cell]
		var arena_path = astar.get_point_path(player_id, arena_id)
		if arena_path.is_empty():
			print("[MapGenerator] Sem caminho para boss arena!")
			return false

	return true


func _create_spawn_points() -> void:
	"""Cria pontos de spawn para inimigos distribuídos pelo mapa"""
	spawn_points.clear()

	# Cria spawn points em células vazias distantes do player
	var player_cell = _world_to_grid(player_spawn_position)
	var min_distance = 3  # Mínimo 3 células de distância do player spawn

	var potential_spawns: Array[Vector3] = []

	for x in GRID_SIZE:
		for y in GRID_SIZE:
			# Apenas células vazias ou corredores (não boss arenas)
			if grid[x][y] in [CellType.EMPTY, CellType.CORRIDOR]:
				var cell_dist = abs(x - player_cell.x) + abs(y - player_cell.y)
				if cell_dist >= min_distance:
					potential_spawns.append(_grid_to_world(x, y) + Vector3(0, 0.5, 0))

	# Seleciona spawn points bem distribuídos
	var target_count = 12  # 12 spawn points
	potential_spawns.shuffle()

	for pos in potential_spawns:
		if spawn_points.size() >= target_count:
			break

		# Verifica distância mínima de outros spawn points
		var too_close = false
		for existing in spawn_points:
			if pos.distance_to(existing) < 15:
				too_close = true
				break

		if not too_close:
			spawn_points.append(pos)
			_create_spawn_point_node(pos)

	# Se não conseguiu o suficiente, adiciona mais sem restrição de distância
	if spawn_points.size() < 6:
		for pos in potential_spawns:
			if spawn_points.size() >= 6:
				break
			if pos not in spawn_points:
				spawn_points.append(pos)
				_create_spawn_point_node(pos)


func _create_spawn_point_node(pos: Vector3) -> void:
	"""Cria um nó de spawn point para registro no SpawnManager"""
	var spawn_point = Node3D.new()
	spawn_point.name = "SpawnPoint_" + str(spawn_points.size())
	spawn_point.position = pos
	spawn_point.add_to_group("spawn_points")
	spawn_points_container.add_child(spawn_point)


func _setup_lighting() -> void:
	"""Configura iluminação baseada no bioma"""
	# Luz direcional
	var sun = DirectionalLight3D.new()
	sun.name = "Sun"
	var sun_config = biome_config.get_sun_config()
	sun.light_color = sun_config.color
	sun.light_energy = sun_config.energy
	sun.shadow_enabled = true
	sun.rotation = sun_config.rotation
	lighting_container.add_child(sun)

	# Ambiente
	var env = WorldEnvironment.new()
	env.name = "Environment"
	var environment = Environment.new()

	var env_config = biome_config.get_environment_config()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = env_config.background_color
	environment.ambient_light_color = env_config.ambient_color
	environment.ambient_light_energy = env_config.ambient_energy

	# Fog opcional
	if env_config.has("fog_enabled") and env_config.fog_enabled:
		environment.fog_enabled = true
		environment.fog_light_color = env_config.fog_color
		environment.fog_density = env_config.fog_density

	env.environment = environment
	lighting_container.add_child(env)


func _create_boss_arena_visuals() -> void:
	"""Cria marcadores visuais para as boss arenas"""
	for i in range(boss_arena_centers.size()):
		var center = boss_arena_centers[i]
		var arena_visual = _create_arena_marker(center, i)
		boss_arenas_container.add_child(arena_visual)

		# Cria spawn point para boss nesta arena
		var boss_spawn = Node3D.new()
		boss_spawn.name = "BossSpawnPoint_" + str(i + 1)
		boss_spawn.position = center + Vector3(0, 1, 0)
		boss_spawn.add_to_group("boss_spawn_point")
		boss_arenas_container.add_child(boss_spawn)


func _create_arena_marker(center: Vector3, index: int) -> Node3D:
	"""Cria um marcador visual para uma boss arena"""
	var marker = Node3D.new()
	marker.name = "BossArena_" + str(index + 1)
	marker.position = center

	# Círculo no chão (usando um disco/cilindro fino)
	var circle = MeshInstance3D.new()
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = boss_arena_radius
	cylinder.bottom_radius = boss_arena_radius
	cylinder.height = 0.1
	circle.mesh = cylinder
	circle.position.y = 0.05

	# Material semi-transparente
	var material = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1, 0.3, 0.3, 0.15)  # Vermelho semi-transparente
	material.emission_enabled = true
	material.emission = Color(1, 0.3, 0.3)
	material.emission_energy_multiplier = 0.5
	circle.material_override = material

	marker.add_child(circle)

	# Partículas opcionais
	var particles = GPUParticles3D.new()
	particles.name = "ArenaParticles"
	particles.amount = 20
	particles.lifetime = 2.0
	particles.emitting = true

	var particle_material = ParticleProcessMaterial.new()
	particle_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	particle_material.emission_ring_radius = boss_arena_radius
	particle_material.emission_ring_inner_radius = boss_arena_radius - 0.5
	particle_material.emission_ring_height = 0.1
	particle_material.direction = Vector3(0, 1, 0)
	particle_material.spread = 0
	particle_material.initial_velocity_min = 2.0
	particle_material.initial_velocity_max = 3.0
	particle_material.gravity = Vector3.ZERO
	particle_material.color = Color(1, 0.5, 0.2, 0.6)
	particles.process_material = particle_material

	var particle_mesh = SphereMesh.new()
	particle_mesh.radius = 0.1
	particle_mesh.height = 0.2
	particles.draw_pass_1 = particle_mesh

	marker.add_child(particles)

	return marker


func _setup_navigation() -> void:
	"""Configura o NavigationRegion3D para pathfinding"""
	navigation_region = NavigationRegion3D.new()
	navigation_region.name = "NavigationRegion3D"

	var nav_mesh = NavigationMesh.new()

	# Configurações do NavMesh
	nav_mesh.agent_radius = 0.5
	nav_mesh.agent_height = 2.0
	nav_mesh.agent_max_climb = 0.5
	nav_mesh.agent_max_slope = 45.0
	nav_mesh.cell_size = 0.25
	nav_mesh.cell_height = 0.25

	# Geometria fonte (todo o container de obstáculos + chão + paredes)
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS

	navigation_region.navigation_mesh = nav_mesh
	add_child(navigation_region)


func _bake_navmesh() -> void:
	"""Faz o bake do NavMesh"""
	if not navigation_region:
		push_error("[MapGenerator] NavigationRegion não encontrado!")
		return

	print("[MapGenerator] Iniciando bake do NavMesh...")

	# Bake
	navigation_region.bake_navigation_mesh()

	# Aguarda alguns frames para o bake completar
	await get_tree().create_timer(0.5).timeout

	print("[MapGenerator] NavMesh baked!")
	navmesh_baked.emit()


# === UTILITÁRIOS ===

func _world_to_grid(world_pos: Vector3) -> Vector2:
	"""Converte posição world para coordenadas do grid"""
	var gx = int((world_pos.x + HALF_ARENA) / CELL_SIZE)
	var gy = int((world_pos.z + HALF_ARENA) / CELL_SIZE)
	return Vector2(clamp(gx, 0, GRID_SIZE - 1), clamp(gy, 0, GRID_SIZE - 1))


func _grid_to_world(grid_x: int, grid_y: int) -> Vector3:
	"""Converte coordenadas do grid para posição world"""
	var world_x = (grid_x * CELL_SIZE) - HALF_ARENA + (CELL_SIZE / 2)
	var world_z = (grid_y * CELL_SIZE) - HALF_ARENA + (CELL_SIZE / 2)
	return Vector3(world_x, 0, world_z)


func _is_valid_cell(x: int, y: int) -> bool:
	"""Verifica se a célula é válida"""
	return x >= 0 and x < GRID_SIZE and y >= 0 and y < GRID_SIZE


## Retorna informações do mapa gerado
func get_map_info() -> Dictionary:
	return {
		"seed": current_seed,
		"biome": biome_config.get_biome_name() if biome_config else "Unknown",
		"player_spawn": player_spawn_position,
		"portal_position": portal_position,
		"boss_arenas": boss_arena_centers.duplicate(),
		"spawn_points_count": spawn_points.size(),
		"obstacles_count": generated_obstacles.size(),
		"grid_size": GRID_SIZE,
		"cell_size": CELL_SIZE,
		"arena_size": ARENA_SIZE
	}


## Retorna o spawn point mais próximo de uma posição
func get_nearest_spawn_point(from: Vector3) -> Vector3:
	var nearest = Vector3.ZERO
	var min_dist = INF

	for sp in spawn_points:
		var dist = from.distance_to(sp)
		if dist < min_dist:
			min_dist = dist
			nearest = sp

	return nearest


## Retorna a arena de boss mais próxima
func get_nearest_boss_arena(from: Vector3) -> Vector3:
	var nearest = Vector3.ZERO
	var min_dist = INF

	for arena in boss_arena_centers:
		var dist = from.distance_to(arena)
		if dist < min_dist:
			min_dist = dist
			nearest = arena

	return nearest


## Verifica se uma posição está dentro de uma boss arena
func is_in_boss_arena(pos: Vector3) -> bool:
	for arena_center in boss_arena_centers:
		var dist = Vector2(pos.x, pos.z).distance_to(Vector2(arena_center.x, arena_center.z))
		if dist <= boss_arena_radius:
			return true
	return false


## Retorna uma posição válida para spawn fora do campo de visão do player
func get_spawn_position_away_from_player(player_pos: Vector3, min_distance: float = 30.0) -> Vector3:
	var valid_spawns: Array[Vector3] = []

	for sp in spawn_points:
		if player_pos.distance_to(sp) >= min_distance:
			valid_spawns.append(sp)

	if valid_spawns.is_empty():
		# Fallback: usa spawn point mais distante
		return get_farthest_spawn_point(player_pos)

	return valid_spawns[randi() % valid_spawns.size()]


## Retorna o spawn point mais distante de uma posição
func get_farthest_spawn_point(from: Vector3) -> Vector3:
	var farthest = Vector3.ZERO
	var max_dist = 0.0

	for sp in spawn_points:
		var dist = from.distance_to(sp)
		if dist > max_dist:
			max_dist = dist
			farthest = sp

	return farthest


## Debug: visualiza o grid no console
func debug_print_grid() -> void:
	print("\n=== GRID MAP (Seed: ", current_seed, ") ===")
	var symbols = {
		CellType.EMPTY: ".",
		CellType.OBSTACLE: "#",
		CellType.BOSS_ARENA: "B",
		CellType.PORTAL_ZONE: "P",
		CellType.PLAYER_SPAWN: "S",
		CellType.SPAWN_POINT: "x",
		CellType.CORRIDOR: " "
	}

	for y in GRID_SIZE:
		var line = ""
		for x in GRID_SIZE:
			line += symbols.get(grid[x][y], "?") + " "
		print(line)
	print("=============================\n")
