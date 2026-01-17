extends Node

func _ready() -> void:
	# Debugging Animation Paths from INSIDE the game
	print("\n=== RUNTIME ANIM INSPECTION (NEW MODEL) ===")
	var parent = get_parent()
	var anim_player = _find_anim_player_recursive(parent)
	
	if not anim_player:
		print("ERROR: Runtime Debugger could not find AnimationPlayer (Recursive search failed).")
		_print_tree_recursive(parent, "")
		return
		
	print("Found AnimationPlayer: ", anim_player.get_path())
	
	# List all animations
	var anim_list = anim_player.get_animation_list()
	print("Available Animations: ", anim_list)
	
	# Just inspect the first one found or specifically Shoot
	for anim_name in anim_list:
		var anim = anim_player.get_animation(anim_name)
		print("Tracks for ", anim_name, ":")
		for i in range(anim.get_track_count()):
			print("  - Track ", i, ": ", anim.track_get_path(i))
		break # Just first one is enough to see the path structure
		
	print("===============================\n")

func _find_anim_player_recursive(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	
	for child in node.get_children():
		var result = _find_anim_player_recursive(child)
		if result:
			return result
			
	return null

func _print_tree_recursive(node: Node, prefix: String) -> void:
	print(prefix + node.name + " (" + node.get_class() + ")")
	for child in node.get_children():
		_print_tree_recursive(child, prefix + "  |--")
