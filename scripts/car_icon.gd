extends Control
## Miniatura do carro, usada nas linhas do ranking.

var model := "hiper_laranja"
var art_scale := 0.6


func _ready() -> void:
	custom_minimum_size = Vector2(52, 28)


func _draw() -> void:
	draw_set_transform(size / 2.0, 0.0, Vector2(art_scale, art_scale))
	CarArt.draw(self, model)
