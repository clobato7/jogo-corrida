extends Control
## Desenha as setas semitransparentes que indicam onde tocar.

@export var arrow_width := 140.0     ## largura de cada seta
@export var arrow_height := 190.0    ## altura de cada seta
@export var side_margin := 50.0      ## distância da seta até a lateral da tela
@export var bottom_offset := 340.0   ## distância do centro da seta até a parte de baixo da tela


func _ready() -> void:
	get_viewport().size_changed.connect(queue_redraw)


func _draw() -> void:
	var s := size
	var c := Color(1, 1, 1, 0.3)
	var y := s.y - bottom_offset
	var h := arrow_height / 2.0
	var left_tip := side_margin
	var right_tip := s.x - side_margin
	draw_colored_polygon(PackedVector2Array([
		Vector2(left_tip, y), Vector2(left_tip + arrow_width, y - h), Vector2(left_tip + arrow_width, y + h)]), c)
	draw_colored_polygon(PackedVector2Array([
		Vector2(right_tip, y), Vector2(right_tip - arrow_width, y - h), Vector2(right_tip - arrow_width, y + h)]), c)
