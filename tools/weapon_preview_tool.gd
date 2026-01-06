@tool
extends Node3D

# ============================================
# WEAPON PREVIEW TOOL
# Ferramenta para visualizar e ajustar armas no editor
# sem precisar rodar o jogo
# ============================================
# 
# USO:
# 1. Adicione este nó à sua cena de arma (como filho root)
# 2. Arraste sua arma/mesh como filho deste nó
# 3. Ajuste os valores no Inspector em tempo real
# 4. Veja a preview diretamente no editor!

class_name WeaponPreviewTool

# === CONFIGURAÇÕES DE POSIÇÃO FPS ===
@export_group("FPS Position")
@export var weapon_position: Vector3 = Vector3(0.3, -0.3, -0.5):
	set(value):
		weapon_position = value
		_update_weapon_transform()

@export var weapon_rotation: Vector3 = Vector3(0, 180, 0):
	set(value):
		weapon_rotation = value
		_update_weapon_transform()

@export var weapon_scale: Vector3 = Vector3(1, 1, 1):
	set(value):
		weapon_scale = value
		_update_weapon_transform()

# === SELEÇÃO DE ARMA ===
@export_group("Weapon Selection")
@export_enum("Pistol", "Revolver", "SMG", "Shotgun", "Sniper", "LMG") var selected_weapon: String = "Pistol":
	set(value):
		selected_weapon = value
		if Engine.is_editor_hint():
			_load_selected_weapon()

@export var reload_weapon: bool = false:
	set(value):
		if value and Engine.is_editor_hint():
			_load_selected_weapon()

@export var export_to_console: bool = false:
	set(value):
		if value and Engine.is_editor_hint():
			print_transform_for_scene()

@export var save_to_current_weapon_file: bool = false:
	set(value):
		if value and Engine.is_editor_hint():
			_save_to_weapon_tscn()

# Mapeamento de nomes para caminhos de cena
var weapon_scenes = {
	"Pistol": "res://weapons/pistol/pistol.tscn",
	"Revolver": "res://weapons/revolver/revolver.tscn",
	"SMG": "res://weapons/smg/smg.tscn",
	"Shotgun": "res://weapons/shotgun/shotgun.tscn",
	"Sniper": "res://weapons/sniper/sniper.tscn",
	"LMG": "res://weapons/lmg/lmg.tscn"
}

# === PRESETS ===
@export_group("Quick Presets")
@export var apply_pistol_preset: bool = false:
	set(value):
		if value:
			weapon_position = Vector3(0.3, -0.3, -0.5)
			weapon_rotation = Vector3(0, 180, 0)
			weapon_scale = Vector3(1, 1, 1)
			_update_weapon_transform()

@export var apply_rifle_preset: bool = false:
	set(value):
		if value:
			weapon_position = Vector3(0.25, -0.35, -0.6)
			weapon_rotation = Vector3(0, 180, 0)
			weapon_scale = Vector3(1, 1, 1)
			_update_weapon_transform()

# === DEBUG ===
@export_group("Debug")
@export var show_camera_preview: bool = true:
	set(value):
		show_camera_preview = value
		_toggle_preview_camera()

@export var preview_fov: float = 90.0:
	set(value):
		preview_fov = value
		if _preview_camera:
			_preview_camera.fov = value

# Referências internas
var _weapon_mesh: Node3D = null
var _preview_camera: Camera3D = null


func _ready() -> void:
	if Engine.is_editor_hint():
		_setup_editor_preview()


func _setup_editor_preview() -> void:
	"""Configura a preview no editor"""
	_load_selected_weapon()
	
	# Cria câmera de preview
	if show_camera_preview:
		_create_preview_camera()
	
	_update_weapon_transform()


func _load_selected_weapon() -> void:
	"""Carrega o modelo da arma selecionada"""
	# Limpa filhos antigos (exceto a câmera)
	for child in get_children():
		if child is Node3D and not child is Camera3D:
			child.free()
	
	var path = ""
	match selected_weapon:
		"Pistol": path = "res://assets/weapons/Pistol/p9_manny_fps_animations.glb"
		"Revolver": path = "res://assets/weapons/Revolver/revolver_animated.glb"
		"SMG": path = "res://assets/weapons/SMG/animated_mp5.glb"
		"Shotgun": path = "res://assets/weapons/Shotgun/shotgun_animated.glb"
		"Sniper": path = "res://assets/weapons/Sniper/sniper_animated.glb"
		"LMG": path = "res://assets/weapons/LMG/minigun_animated.glb"
	
	if path == "" or not ResourceLoader.exists(path):
		printerr("[Preview] Erro: Modelo não encontrado em ", path)
		return
		
	var scene = load(path)
	if scene:
		_weapon_mesh = scene.instantiate()
		add_child(_weapon_mesh)
		_weapon_mesh.owner = self
		print("[Preview] Carregada: ", selected_weapon)
		_play_idle_animation()
		_update_weapon_transform()


func _play_idle_animation() -> void:
	"""Encontra e toca a animação idle do modelo"""
	if not _weapon_mesh:
		return
	
	# Busca AnimationPlayer
	var anim_player = _weapon_mesh.find_child("AnimationPlayer", true, false)
	if anim_player and anim_player is AnimationPlayer:
		var anims = anim_player.get_animation_list()
		print("[Preview] Animações disponíveis: ", anims)
		
		# Procura por idle (pode ser WEP_Idle, Idle, idle, etc)
		for anim_name in anims:
			if "idle" in anim_name.to_lower():
				anim_player.play(anim_name)
				print("[Preview] Tocando animação: ", anim_name)
				return
		
		# Se não encontrou idle, tenta a primeira animação que não seja T-pose
		if anims.size() > 0:
			anim_player.play(anims[0])
			print("[Preview] Tocando primeira animação: ", anims[0])


func _create_preview_camera() -> void:
	"""Cria uma câmera para simular a visão FPS"""
	if _preview_camera:
		return
		
	_preview_camera = Camera3D.new()
	_preview_camera.name = "WeaponPreviewCamera"
	_preview_camera.fov = preview_fov
	_preview_camera.near = 0.01
	_preview_camera.current = false  # Não ativa automaticamente
	add_child(_preview_camera)
	
	# Posiciona a câmera na origem (simula a cabeça do player)
	_preview_camera.position = Vector3.ZERO
	_preview_camera.rotation = Vector3.ZERO


func _toggle_preview_camera() -> void:
	"""Liga/desliga a câmera de preview"""
	if show_camera_preview and not _preview_camera:
		_create_preview_camera()
	elif not show_camera_preview and _preview_camera:
		_preview_camera.queue_free()
		_preview_camera = null


func _update_weapon_transform() -> void:
	"""Atualiza a transformação do mesh da arma"""
	if not Engine.is_editor_hint():
		return
	
	# Procura o mesh se não encontrou ainda
	if not _weapon_mesh:
		for child in get_children():
			if child is Node3D and not child is Camera3D:
				_weapon_mesh = child
				break
	
	if _weapon_mesh:
		_weapon_mesh.position = weapon_position
		_weapon_mesh.rotation_degrees = weapon_rotation
		_weapon_mesh.scale = weapon_scale
		
		# Força update visual no editor
		if Engine.is_editor_hint():
			_weapon_mesh.notify_property_list_changed()


# === GIZMOS PARA VISUALIZAÇÃO ===
func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	
	var has_mesh = false
	for child in get_children():
		if child is Node3D and not child is Camera3D:
			has_mesh = true
			break
	
	if not has_mesh:
		warnings.append("Adicione um mesh de arma como filho deste nó para visualizar")
	
	return warnings


# === EXPORTAR VALORES ===
func get_export_values() -> Dictionary:
	"""Retorna os valores atuais para copiar para a cena da arma"""
	return {
		"position": weapon_position,
		"rotation_degrees": weapon_rotation,
		"scale": weapon_scale
	}


func print_transform_for_scene() -> void:
	"""Imprime a transform para colar na cena .tscn"""
	var rot_rad = weapon_rotation * (PI / 180.0)
	var basis = Basis.from_euler(rot_rad)
	basis = basis.scaled(weapon_scale)
	
	print("=== COPIE ESTA LINHA PARA pistol.tscn ===")
	print("transform = Transform3D(", 
		basis.x.x, ", ", basis.x.y, ", ", basis.x.z, ", ",
		basis.y.x, ", ", basis.y.y, ", ", basis.y.z, ", ",
		basis.z.x, ", ", basis.z.y, ", ", basis.z.z, ", ",
		weapon_position.x, ", ", weapon_position.y, ", ", weapon_position.z, ")")
	print("==========================================")


func _save_to_weapon_tscn() -> void:
	"""Salva o transform atual no arquivo .tscn da arma selecionada"""
	var tscn_path = weapon_scenes.get(selected_weapon, "")
	if tscn_path == "":
		printerr("[Preview] Erro: Arma não mapeada: ", selected_weapon)
		return
	
	# Converte res:// para caminho absoluto
	var absolute_path = ProjectSettings.globalize_path(tscn_path)
	
	if not FileAccess.file_exists(absolute_path):
		printerr("[Preview] Erro: Arquivo não encontrado: ", absolute_path)
		return
	
	# Lê o arquivo linha por linha
	var file = FileAccess.open(absolute_path, FileAccess.READ)
	var lines = []
	while not file.eof_reached():
		lines.append(file.get_line())
	file.close()
	
	# Gera a nova linha de transform
	var rot_rad = weapon_rotation * (PI / 180.0)
	var basis = Basis.from_euler(rot_rad)
	basis = basis.scaled(weapon_scale)
	
	var transform_str = "transform = Transform3D(%.8g, %.8g, %.8g, %.8g, %.8g, %.8g, %.8g, %.8g, %.8g, %.8g, %.8g, %.8g)" % [
		basis.x.x, basis.x.y, basis.x.z,
		basis.y.x, basis.y.y, basis.y.z,
		basis.z.x, basis.z.y, basis.z.z,
		weapon_position.x, weapon_position.y, weapon_position.z
	]
	
	# Procura o nó do mesh e a linha de transform logo abaixo
	var mesh_node_name = selected_weapon + "Mesh"
	var found_node = false
	var modified = false
	
	for i in range(lines.size()):
		var line = lines[i]
		
		# Encontrou a declaração do nó do mesh?
		if '[node name="' + mesh_node_name + '"' in line:
			found_node = true
			print("[Preview] Encontrado nó: ", mesh_node_name, " na linha ", i + 1)
			continue
		
		# Se encontrou o nó, a próxima linha com 'transform =' é a que precisamos modificar
		if found_node and line.strip_edges().begins_with("transform = "):
			lines[i] = transform_str
			modified = true
			print("[Preview] Transform modificado na linha ", i + 1)
			break
		
		# Se encontrou outro nó antes de achar transform, o mesh não tinha transform definido
		if found_node and line.begins_with("[node") or line.begins_with("[sub_resource"):
			printerr("[Preview] Erro: Nó encontrado mas não tinha linha de transform.")
			break
	
	if not found_node:
		printerr("[Preview] Erro: Nó '", mesh_node_name, "' não encontrado no arquivo.")
		return
	
	if not modified:
		printerr("[Preview] Erro: Linha de transform não encontrada para o nó.")
		return
	
	# Salva o arquivo de volta
	var write_file = FileAccess.open(absolute_path, FileAccess.WRITE)
	for line in lines:
		write_file.store_line(line)
	write_file.close()
	
	print("==========================================")
	print("[Preview] SUCESSO! Arquivo salvo: ", tscn_path)
	print("  -> ", transform_str)
	print("==========================================")
	print("[Preview] IMPORTANTE: Recarregue a cena no editor (Ctrl+R ou feche/abra) para ver as mudanças.")
