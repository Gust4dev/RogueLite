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
	# Encontra o primeiro filho Node3D (o mesh da arma)
	for child in get_children():
		if child is Node3D and not child is Camera3D:
			_weapon_mesh = child
			break
	
	# Cria câmera de preview
	if show_camera_preview:
		_create_preview_camera()
	
	_update_weapon_transform()
	
	# Toca animação idle
	_play_idle_animation()


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
