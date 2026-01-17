extends Node

func _ready() -> void:
	print("--- MODEL TREE INSPECTION ---")
	var model_path = "res://assets/weapons/modern-weapon/PumpySMGglb.glb"
	var scene = load(model_path).instantiate()
	add_child(scene)
	
	_print_tree_recursive(scene, "")
	
	print("\n--- FINDING ANIMATION PLAYER ---")
	var anim_player = scene.find_child("AnimationPlayer", true, false)
	if not anim_player:
		# Try iterating children manually if find_child fails
		for child in scene.get_children():
			if child is AnimationPlayer:
				anim_player = child
				break
				
	if not anim_player:
		print("ERROR: Still no AnimationPlayer found.")
		get_tree().quit()
		return
		
	print("FOUND AnimationPlayer: ", anim_player.get_path())
	
	var anim_name = "Armature|Shoot"
	if not anim_player.has_animation(anim_name):
		print("ERROR: Animation ", anim_name, " not found.")
		print("Available: ", anim_player.get_animation_list())
		get_tree().quit()
		return
		
	var anim = anim_player.get_animation(anim_name)
	print("Inspecting Animation: ", anim_name)
	print("Track Count: ", anim.get_track_count())
	
	for i in range(anim.get_track_count()):
		var path = anim.track_get_path(i)
		var type = anim.track_get_type(i)
		print("Track ", i, ": ", path, " (Type: ", type, ")")
		
	print("--- END INSPECTION ---")
	get_tree().quit()

func _print_tree_recursive(node: Node, prefix: String) -> void:
	print(prefix + node.name + " (" + node.get_class() + ")")
	for child in node.get_children():
		_print_tree_recursive(child, prefix + "  |--")
