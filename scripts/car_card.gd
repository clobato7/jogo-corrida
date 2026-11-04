extends Button
## Card da tela de escolha: um botão grande com o desenho do carro e o nome embaixo.

var model := "f1_laranja"
var art_scale := 2.6


func _ready() -> void:
	custom_minimum_size = Vector2(260, 230)
	focus_mode = Control.FOCUS_NONE
	add_theme_stylebox_override("normal", _style(Color(1, 1, 1, 0.35)))
	add_theme_stylebox_override("hover", _style(Color(1, 0.84, 0.2, 1)))
	add_theme_stylebox_override("pressed", _style(Color(1, 0.84, 0.2, 1), Color(0.25, 0.22, 0.1, 0.95)))
	resized.connect(queue_redraw)


func _style(border: Color, bg := Color(0.12, 0.14, 0.18, 0.95)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(6)
	s.set_corner_radius_all(24)
	s.shadow_color = Color(0, 0, 0, 0.4)
	s.shadow_size = 8
	return s


func _draw() -> void:
	draw_set_transform(Vector2(size.x / 2.0, size.y * 0.42), 0.0, Vector2(art_scale, art_scale))
	CarArt.draw(self, model)
	draw_set_transform(Vector2.ZERO)
	var font := get_theme_default_font()
	draw_string_outline(font, Vector2(0, size.y - 26), CarArt.NAMES[model], HORIZONTAL_ALIGNMENT_CENTER, size.x, 34, 8, Color.BLACK)
	draw_string(font, Vector2(0, size.y - 26), CarArt.NAMES[model], HORIZONTAL_ALIGNMENT_CENTER, size.x, 34, Color.WHITE)
