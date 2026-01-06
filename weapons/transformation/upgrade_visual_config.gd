extends Resource

# Upgrade Visual Config - Resource class for defining upgrade visual properties
# Each upgrade has specific colors, shaders, particles, and part modifications

class_name UpgradeVisualConfig

# === UPGRADE VISUAL DEFINITIONS ===
# Static dictionary of all upgrade visual configurations

static var UPGRADE_VISUALS: Dictionary = {
	"chain_lightning": {
		"name": "Chain Lightning",
		"primary_color": Color(0.0, 0.8, 1.0),      # Cyan electric
		"secondary_color": Color(0.3, 0.5, 1.0),    # Blue
		"emission_color": Color(0.2, 0.9, 1.0),
		"emission_strength": 2.5,
		"pulse_speed": 4.0,
		"shader": "emissive_glow",
		"dominant_part": "barrel",
		"part_modifications": {
			"barrel": {
				"emission_strength": 3.0,
				"scale": Vector3(1.0, 1.0, 1.1)
			}
		},
		"particles": {
			"type": "electric_arcs",
			"color": Color(0.3, 0.8, 1.0),
			"intensity": 1.5
		},
		"trail_type": "lightning"
	},

	"explosive_rounds": {
		"name": "Explosive Rounds",
		"primary_color": Color(1.0, 0.4, 0.1),      # Orange
		"secondary_color": Color(1.0, 0.2, 0.0),    # Red-orange
		"emission_color": Color(1.0, 0.5, 0.1),
		"emission_strength": 2.0,
		"pulse_speed": 2.5,
		"shader": "emissive_glow",
		"dominant_part": "magazine",
		"part_modifications": {
			"barrel": {
				"emission_strength": 1.5,
				"add_ring": true
			},
			"magazine": {
				"color": Color(1.0, 0.3, 0.1),
				"emission_strength": 1.0
			}
		},
		"particles": {
			"type": "embers",
			"color": Color(1.0, 0.6, 0.2),
			"intensity": 1.0
		},
		"trail_type": "fire"
	},

	"freeze_bullets": {
		"name": "Freeze Bullets",
		"primary_color": Color(0.6, 0.85, 0.95),    # Ice blue
		"secondary_color": Color(0.2, 0.5, 0.8),    # Deep ice
		"emission_color": Color(0.4, 0.8, 1.0),
		"emission_strength": 1.5,
		"pulse_speed": 1.5,
		"shader": "ice_frost",
		"dominant_part": "barrel",
		"part_modifications": {
			"barrel": {
				"shader": "ice_frost",
				"frost_coverage": 0.8
			}
		},
		"particles": {
			"type": "snowflakes",
			"color": Color(0.9, 0.95, 1.0),
			"intensity": 1.2
		},
		"trail_type": "frost"
	},

	"ricochet": {
		"name": "Ricochet",
		"primary_color": Color(0.9, 0.9, 0.95),     # Silver
		"secondary_color": Color(0.8, 0.85, 0.7),   # Gold tint
		"emission_color": Color(1.0, 1.0, 0.8),
		"emission_strength": 1.0,
		"pulse_speed": 0.0,
		"shader": "metallic_reflection",
		"dominant_part": "barrel",
		"part_modifications": {
			"barrel": {
				"shader": "metallic_reflection",
				"scale": Vector3(0.9, 0.9, 1.0),  # More angular
				"faceted": true
			}
		},
		"particles": {
			"type": "sparks",
			"color": Color(1.0, 0.9, 0.5),
			"intensity": 0.8
		},
		"trail_type": "spark"
	},

	"piercing_bullets": {
		"name": "Piercing Bullets",
		"primary_color": Color(0.9, 0.75, 0.3),     # Gold
		"secondary_color": Color(0.7, 0.5, 0.1),    # Dark gold
		"emission_color": Color(1.0, 0.8, 0.3),
		"emission_strength": 2.0,
		"pulse_speed": 0.5,
		"shader": "fresnel_edge",
		"dominant_part": "barrel",
		"part_modifications": {
			"barrel": {
				"scale": Vector3(0.8, 0.8, 1.3),  # Longer, thinner
				"emission_strength": 2.5
			},
			"sight": {
				"laser_sight": true,
				"laser_color": Color(1.0, 0.2, 0.2)
			}
		},
		"particles": {
			"type": "laser_glow",
			"color": Color(1.0, 0.8, 0.2),
			"intensity": 0.5
		},
		"trail_type": "beam"
	},

	"fast_reload": {
		"name": "Fast Reload",
		"primary_color": Color(0.0, 1.0, 0.5),      # Green tech
		"secondary_color": Color(0.0, 0.5, 1.0),    # Blue tech
		"emission_color": Color(0.0, 1.0, 0.6),
		"emission_strength": 1.5,
		"pulse_speed": 3.0,
		"shader": "holographic",
		"dominant_part": "magazine",
		"part_modifications": {
			"magazine": {
				"shader": "holographic",
				"transparency": 0.4
			}
		},
		"particles": {
			"type": "tech_bits",
			"color": Color(0.0, 1.0, 0.8),
			"intensity": 0.6
		},
		"trail_type": "none"
	},

	"burst_fire": {
		"name": "Burst Fire",
		"primary_color": Color(0.8, 0.1, 0.1),      # Dark red
		"secondary_color": Color(0.5, 0.05, 0.05),  # Deeper red
		"emission_color": Color(1.0, 0.2, 0.1),
		"emission_strength": 2.0,
		"pulse_speed": 6.0,                          # Fast pulse for burst effect
		"shader": "emissive_glow",
		"dominant_part": "barrel",
		"part_modifications": {
			"barrel": {
				"multi_port": true,
				"emission_strength": 2.5
			}
		},
		"particles": {
			"type": "muzzle_burst",
			"color": Color(1.0, 0.5, 0.2),
			"intensity": 2.0
		},
		"trail_type": "multi"
	},

	"lifesteal": {
		"name": "Lifesteal",
		"primary_color": Color(0.15, 0.1, 0.2),     # Dark purple base
		"secondary_color": Color(0.4, 0.8, 0.3),    # Green veins
		"emission_color": Color(0.6, 0.1, 0.8),
		"emission_strength": 1.8,
		"pulse_speed": 1.2,                          # Heartbeat-like
		"shader": "organic_lifesteal",
		"dominant_part": "grip",
		"part_modifications": {
			"grip": {
				"shader": "organic_lifesteal"
			},
			"magazine": {
				"shader": "organic_lifesteal"
			}
		},
		"particles": {
			"type": "soul_absorption",
			"color": Color(0.3, 0.8, 0.3),
			"intensity": 1.0
		},
		"trail_type": "souls"
	}
}

# === COMBINATION PRIORITY ===
# When multiple upgrades are active, which one dominates each part
static var PART_PRIORITY: Dictionary = {
	"barrel": ["chain_lightning", "explosive_rounds", "freeze_bullets", "piercing_bullets", "burst_fire", "ricochet"],
	"magazine": ["fast_reload", "explosive_rounds", "lifesteal", "burst_fire"],
	"grip": ["lifesteal", "fast_reload"],
	"sight": ["piercing_bullets", "ricochet"]
}

# === STATIC METHODS ===

static func get_visual_config(upgrade_id: String) -> Dictionary:
	"""Get visual configuration for an upgrade"""
	if upgrade_id in UPGRADE_VISUALS:
		return UPGRADE_VISUALS[upgrade_id]
	return {}


static func get_dominant_upgrade_for_part(part_type: String, active_upgrades: Array) -> String:
	"""Determine which upgrade should dominate a specific part"""
	if not part_type in PART_PRIORITY:
		return ""

	var priority_list = PART_PRIORITY[part_type]

	for upgrade_id in priority_list:
		if upgrade_id in active_upgrades:
			return upgrade_id

	return ""


static func get_all_upgrade_ids() -> Array:
	"""Get list of all upgrade IDs"""
	return UPGRADE_VISUALS.keys()


static func get_shader_path(shader_name: String) -> String:
	"""Get full path to shader file"""
	return "res://shaders/" + shader_name + ".gdshader"


static func get_particle_scene_path(particle_type: String) -> String:
	"""Get full path to particle scene"""
	return "res://vfx/upgrade_particles/" + particle_type + ".tscn"


# === LEVEL SCALING ===

static func get_scaled_emission(upgrade_id: String, level: int) -> float:
	"""Get emission strength scaled by upgrade level"""
	var config = get_visual_config(upgrade_id)
	if config.is_empty():
		return 1.0

	var base = config.get("emission_strength", 1.0)
	return base * (0.7 + level * 0.3)  # Level 1: 100%, Level 2: 130%, Level 3: 160%


static func get_scaled_particle_intensity(upgrade_id: String, level: int) -> float:
	"""Get particle intensity scaled by upgrade level"""
	var config = get_visual_config(upgrade_id)
	if config.is_empty():
		return 1.0

	var particles = config.get("particles", {})
	var base = particles.get("intensity", 1.0)
	return base * (0.6 + level * 0.4)  # Level 1: 100%, Level 2: 140%, Level 3: 180%


static func get_scaled_pulse_speed(upgrade_id: String, level: int) -> float:
	"""Get pulse speed scaled by upgrade level"""
	var config = get_visual_config(upgrade_id)
	if config.is_empty():
		return 2.0

	var base = config.get("pulse_speed", 2.0)
	return base * (0.8 + level * 0.2)  # Slightly faster at higher levels
