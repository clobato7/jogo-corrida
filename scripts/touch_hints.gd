extends Control
## Desenha as setas semitransparentes que indicam onde tocar.


func _ready() -> void:
	get_viewport().size_changed.connect(queue_redraw)


func _draw() -> void:
	var s := size
	var c := Color(1, 1, 1, 0.25)
	var y := s.y - 110.0
	draw_colored_polygon(PackedVector2Array([Vector2(60, y), Vector2(150, y - 60), Vector2(150, y + 60)]), c)
	draw_colored_polygon(PackedVector2Array([Vector2(s.x - 60, y), Vector2(s.x - 150, y - 60), Vector2(s.x - 150, y + 60)]), c)
