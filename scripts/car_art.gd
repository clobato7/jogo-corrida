class_name CarArt
## Desenho dos carros. Todos apontam para a direita (a frente) com o centro em (0, 0).
## Usado pelo carro na pista e pelos cards da tela de escolha.

const ORDER := ["f1_laranja", "f1_vermelho", "super_dourado", "caminhao_azul"]

const NAMES := {
	"f1_laranja": "Laranja",
	"f1_vermelho": "Vermelho",
	"super_dourado": "Dourado",
	"caminhao_azul": "Caminhão",
}

## Tamanho da área de colisão de cada carro.
const SIZES := {
	"f1_laranja": Vector2(66, 30),
	"f1_vermelho": Vector2(66, 30),
	"super_dourado": Vector2(62, 32),
	"caminhao_azul": Vector2(76, 36),
}

const TIRE := Color("1b1b1b")
const TIRE_RIM := Color("555555")


static func draw(ci: CanvasItem, model: String) -> void:
	match model:
		"f1_laranja":
			_draw_f1(ci, Color("ff8000"), Color("12263f"), Color("47c7fc"), Color("ffffff"))
		"f1_vermelho":
			_draw_f1(ci, Color("dc0000"), Color("1a1a1a"), Color("ffffff"), Color("ffeb3b"))
		"super_dourado":
			_draw_supercar(ci, Color("e0a800"))
		"caminhao_azul":
			_draw_truck(ci, Color("14286b"))
		_:
			_draw_f1(ci, Color("ff8000"), Color("12263f"), Color("47c7fc"), Color("ffffff"))


static func _tire(ci: CanvasItem, rect: Rect2) -> void:
	ci.draw_rect(rect, TIRE)
	ci.draw_rect(Rect2(rect.position + Vector2(2, rect.size.y * 0.35), Vector2(rect.size.x - 4, rect.size.y * 0.3)), TIRE_RIM)


static func _poly(ci: CanvasItem, pts: Array, color: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array(pts), color)


## Monoposto de F1: rodas expostas, bico fino, asas na frente e atrás.
static func _draw_f1(ci: CanvasItem, body: Color, accent: Color, stripe: Color, helmet: Color) -> void:
	# Rodas (traseiras maiores)
	_tire(ci, Rect2(-30, -18, 15, 9))
	_tire(ci, Rect2(-30, 9, 15, 9))
	_tire(ci, Rect2(14, -17, 12, 8))
	_tire(ci, Rect2(14, 9, 12, 8))
	# Braços da suspensão
	ci.draw_line(Vector2(-22, -10), Vector2(-18, -5), accent, 2)
	ci.draw_line(Vector2(-22, 10), Vector2(-18, 5), accent, 2)
	ci.draw_line(Vector2(20, -10), Vector2(16, -3), accent, 2)
	ci.draw_line(Vector2(20, 10), Vector2(16, 3), accent, 2)
	# Asa traseira
	ci.draw_rect(Rect2(-37, -14, 6, 28), accent)
	ci.draw_rect(Rect2(-36, -12, 4, 24), body)
	# Corpo: assoalho, sidepods e bico
	_poly(ci, [Vector2(-31, -5), Vector2(-20, -7), Vector2(-14, -12), Vector2(2, -12), Vector2(8, -6),
		Vector2(26, -3), Vector2(33, -2), Vector2(33, 2), Vector2(26, 3), Vector2(8, 6),
		Vector2(2, 12), Vector2(-14, 12), Vector2(-20, 7), Vector2(-31, 5)], body)
	# Faixa de decoração e entrada de ar
	_poly(ci, [Vector2(-28, -2), Vector2(26, -1), Vector2(26, 1), Vector2(-28, 2)], stripe)
	ci.draw_rect(Rect2(-12, -12, 10, 3), accent)
	ci.draw_rect(Rect2(-12, 9, 10, 3), accent)
	# Asa dianteira
	ci.draw_rect(Rect2(29, -16, 6, 32), accent)
	ci.draw_rect(Rect2(30, -14, 4, 28), body)
	# Cockpit, piloto e halo
	ci.draw_circle(Vector2(-2, 0), 7.0, accent)
	ci.draw_circle(Vector2(-3, 0), 5.0, helmet)
	ci.draw_rect(Rect2(-1, -2.5, 3, 5), Color("222222"))
	ci.draw_arc(Vector2(-2, 0), 8.0, -PI / 2.0, PI / 2.0, 10, Color("333333"), 2.0)
	ci.draw_line(Vector2(6, 0), Vector2(11, 0), Color("333333"), 2.0)


## Superesportivo: carroceria em cunha, baixa e larga.
static func _draw_supercar(ci: CanvasItem, body: Color) -> void:
	var dark := body.darkened(0.35)
	_tire(ci, Rect2(-24, -18, 14, 5))
	_tire(ci, Rect2(-24, 13, 14, 5))
	_tire(ci, Rect2(13, -18, 13, 5))
	_tire(ci, Rect2(13, 13, 13, 5))
	var shape := [Vector2(-31, -14), Vector2(8, -16), Vector2(24, -12), Vector2(32, -6),
		Vector2(32, 6), Vector2(24, 12), Vector2(8, 16), Vector2(-31, 14)]
	_poly(ci, shape, body)
	var outline := PackedVector2Array(shape)
	outline.append(shape[0])
	ci.draw_polyline(outline, dark, 2.0)
	# Entradas de ar laterais
	_poly(ci, [Vector2(-14, -14), Vector2(-4, -15), Vector2(-8, -10)], Color("111111"))
	_poly(ci, [Vector2(-14, 14), Vector2(-4, 15), Vector2(-8, 10)], Color("111111"))
	# Teto e vidros
	_poly(ci, [Vector2(-14, -10), Vector2(4, -11), Vector2(16, -8), Vector2(16, 8), Vector2(4, 11), Vector2(-14, 10)], Color("1c2733"))
	_poly(ci, [Vector2(-10, -8), Vector2(4, -9), Vector2(4, 9), Vector2(-10, 8)], dark)
	# Grade do motor
	for i in 4:
		var x := -28.0 + i * 3.5
		ci.draw_line(Vector2(x, -7), Vector2(x, 7), dark, 1.5)
	# Faróis e lanternas
	_poly(ci, [Vector2(27, -10), Vector2(31, -6), Vector2(28, -5)], Color("fffde7"))
	_poly(ci, [Vector2(27, 10), Vector2(31, 6), Vector2(28, 5)], Color("fffde7"))
	ci.draw_rect(Rect2(-31, -12, 2, 7), Color("ff1744"))
	ci.draw_rect(Rect2(-31, 5, 2, 7), Color("ff1744"))


## Caminhão: cabine na frente e baú atrás.
static func _draw_truck(ci: CanvasItem, body: Color) -> void:
	var light := body.lightened(0.3)
	# Rodas (duplas atrás)
	for x in [-32.0, -19.0]:
		_tire(ci, Rect2(x, -20, 11, 5))
		_tire(ci, Rect2(x, 15, 11, 5))
	_tire(ci, Rect2(20, -20, 11, 5))
	_tire(ci, Rect2(20, 15, 11, 5))
	# Baú com nervuras
	ci.draw_rect(Rect2(-38, -17, 48, 34), light)
	for i in 6:
		var x := -34.0 + i * 7.5
		ci.draw_line(Vector2(x, -16), Vector2(x, 16), body, 1.5)
	ci.draw_rect(Rect2(-38, -17, 48, 34), body, false, 2.0)
	# Engate entre baú e cabine
	ci.draw_rect(Rect2(10, -10, 4, 20), Color("222222"))
	# Cabine
	ci.draw_rect(Rect2(14, -16, 22, 32), body)
	ci.draw_rect(Rect2(16, -13, 10, 26), light)
	ci.draw_rect(Rect2(31, -14, 4, 28), Color("8fd3ff"))   # para-brisa
	# Retrovisores e luzes de teto
	ci.draw_rect(Rect2(28, -19, 3, 3), Color("222222"))
	ci.draw_rect(Rect2(28, 16, 3, 3), Color("222222"))
	for y in [-9.0, -3.0, 3.0]:
		ci.draw_rect(Rect2(27, y, 2, 4), Color("ffc107"))
	# Faróis
	ci.draw_rect(Rect2(36, -13, 2, 6), Color("fffde7"))
	ci.draw_rect(Rect2(36, 7, 2, 6), Color("fffde7"))
