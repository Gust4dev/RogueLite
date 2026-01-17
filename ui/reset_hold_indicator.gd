extends Control

# Reset Hold Indicator - Círculo de progresso para reset via hold R
# Centralizado na retícula (centro da tela)

class_name ResetHoldIndicator

signal reset_completed()

# === CONFIG ===
const HOLD_DURATION: float = 1.5
const CIRCLE_RADIUS: float = 50.0
const CIRCLE_THICKNESS: float = 5.0
const INNER_RADIUS: float = 35.0

# === STATE ===
var progress: float = 0.0
var is_active: bool = false

# === COLORS ===
var color_bg: Color = Color(0.2, 0.2, 0.2, 0.6)
var color_progress: Color = Color(1.0, 0.5, 0.2)
var color_complete: Color = Color(1.0, 0.2, 0.1)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	
	# Ocupa a tela toda para desenhar no centro
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _draw() -> void:
	if not is_active:
		return
	
	# Centro da tela (onde fica a retícula)
	var center = get_viewport_rect().size / 2.0
	
	# Background circle (mais transparente)
	draw_arc(center, CIRCLE_RADIUS, 0, TAU, 64, color_bg, CIRCLE_THICKNESS + 2, true)
	
	# Inner ring (decorativo)
	draw_arc(center, INNER_RADIUS, 0, TAU, 32, Color(color_bg, 0.3), 2, true)
	
	# Progress arc
	var current_color = color_complete if progress >= 1.0 else color_progress
	var end_angle = -PI/2 + (progress * TAU)
	draw_arc(center, CIRCLE_RADIUS, -PI/2, end_angle, 64, current_color, CIRCLE_THICKNESS, true)
	
	# Glow effect when near complete
	if progress > 0.7:
		var glow_alpha = (progress - 0.7) / 0.3 * 0.3
		draw_arc(center, CIRCLE_RADIUS + 3, -PI/2, end_angle, 64, Color(current_color, glow_alpha), 2, true)
	
	# Center fill when complete
	if progress >= 1.0:
		draw_circle(center, INNER_RADIUS - 5, Color(color_complete, 0.4))
	
	# Text abaixo do círculo
	var font = ThemeDB.fallback_font
	var font_size = 14
	var text = "HOLD [R] TO RESTART"
	if progress >= 1.0:
		text = "RESTARTING..."
	
	var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var text_pos = Vector2(center.x - text_size.x / 2, center.y + CIRCLE_RADIUS + 25)
	
	# Background do texto
	var text_bg = Rect2(text_pos.x - 5, text_pos.y - font_size, text_size.x + 10, font_size + 6)
	draw_rect(text_bg, Color(0, 0, 0, 0.6))
	
	draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
	
	# Percentage text no centro
	var pct_text = "%d%%" % int(progress * 100)
	var pct_size = font.get_string_size(pct_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 16)
	var pct_pos = Vector2(center.x - pct_size.x / 2, center.y + 6)
	draw_string(font, pct_pos, pct_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)


func show_indicator() -> void:
	"""Mostra o indicador"""
	is_active = true
	progress = 0.0
	visible = true
	queue_redraw()


func hide_indicator() -> void:
	"""Esconde o indicador"""
	is_active = false
	progress = 0.0
	visible = false
	queue_redraw()


func update_progress(delta: float) -> bool:
	"""Atualiza o progresso. Retorna true se completou."""
	if not is_active:
		return false
	
	progress += delta / HOLD_DURATION
	progress = clamp(progress, 0.0, 1.0)
	queue_redraw()
	
	if progress >= 1.0:
		reset_completed.emit()
		return true
	
	return false


func get_progress() -> float:
	return progress
