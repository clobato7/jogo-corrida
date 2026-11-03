extends Node2D
## Pista gerada a partir de uma linha central (control_points).
## Para mudar o desenho da pista, edite control_points: é uma volta fechada.

signal checkpoint_passed(index: int, body: Node2D)

@export var track_width := 280.0
@export var checkpoint_count := 8
@export var samples_per_segment := 14

## Pontos por onde passa o centro da pista (a largada fica no primeiro).
@export var control_points := PackedVector2Array([
	Vector2(0, 0), Vector2(1400, 0), Vector2(1950, 250), Vector2(2000, 750),
	Vector2(1600, 1050), Vector2(1150, 850), Vector2(700, 1050), Vector2(800, 1550),
	Vector2(300, 1800), Vector2(-350, 1550), Vector2(-550, 900), Vector2(-450, 300),
])

var center_points := PackedVector2Array()
var outer_points := PackedVector2Array()
var inner_points := PackedVector2Array()
var _trees: Array[Vector2] = []

const GRASS := Color("4caf50")
const ASPHALT := Color("555a60")


func _ready() -> void:
	center_points = _smooth_closed(control_points, samples_per_segment)
	outer_points = _largest(Geometry2D.offset_polygon(center_points, track_width / 2.0, Geometry2D.JOIN_ROUND))
	inner_points = _largest(Geometry2D.offset_polygon(center_points, -track_width / 2.0, Geometry2D.JOIN_ROUND))
	_build_walls()
	_build_checkpoints()
	_place_trees()
	queue_redraw()


## Posição e direção de largada (um pouco depois da linha de chegada).
func get_start_transform() -> Transform2D:
	var dir := (center_points[1] - center_points[0]).normalized()
	return Transform2D(dir.angle(), center_points[0] + dir * 90.0)


func _build_walls() -> void:
	var walls := StaticBody2D.new()
	walls.name = "Walls"
	for poly in [outer_points, inner_points]:
		var shape := CollisionPolygon2D.new()
		shape.build_mode = CollisionPolygon2D.BUILD_SEGMENTS
		shape.polygon = poly
		walls.add_child(shape)
	add_child(walls)


func _build_checkpoints() -> void:
	# Linhas invisíveis atravessando a pista. O carro precisa passar por todas, em ordem.
	# O checkpoint 0 é a linha de chegada.
	var n := center_points.size()
	for i in checkpoint_count:
		var idx := int(float(i) * n / checkpoint_count)
		var p := center_points[idx]
		var dir := (center_points[(idx + 1) % n] - p).normalized()
		var normal := dir.orthogonal() * (track_width / 2.0 - 10.0)
		var area := Area2D.new()
		area.name = "Checkpoint%d" % i
		var col := CollisionShape2D.new()
		var seg := SegmentShape2D.new()
		seg.a = p - normal
		seg.b = p + normal
		col.shape = seg
		area.add_child(col)
		area.body_entered.connect(_on_checkpoint_body_entered.bind(i))
		add_child(area)


func _on_checkpoint_body_entered(body: Node2D, index: int) -> void:
	checkpoint_passed.emit(index, body)


func _place_trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var bounds := Rect2(center_points[0], Vector2.ZERO)
	for p in center_points:
		bounds = bounds.expand(p)
	bounds = bounds.grow(500)
	var tries := 0
	while _trees.size() < 70 and tries < 2000:
		tries += 1
		var p := Vector2(rng.randf_range(bounds.position.x, bounds.end.x), rng.randf_range(bounds.position.y, bounds.end.y))
		if _distance_to_center(p) > track_width / 2.0 + 70.0:
			_trees.append(p)


func _distance_to_center(p: Vector2) -> float:
	var best := INF
	var n := center_points.size()
	for i in n:
		var q := Geometry2D.get_closest_point_to_segment(p, center_points[i], center_points[(i + 1) % n])
		best = minf(best, p.distance_to(q))
	return best


func _draw() -> void:
	draw_rect(Rect2(-6000, -6000, 14000, 14000), GRASS)
	draw_colored_polygon(outer_points, ASPHALT)
	draw_colored_polygon(inner_points, GRASS)
	_draw_curb(outer_points)
	_draw_curb(inner_points)
	_draw_start_line()
	for t in _trees:
		draw_circle(t + Vector2(6, 8), 34.0, Color(0, 0, 0, 0.15))
		draw_circle(t, 34.0, Color("2e7d32"))
		draw_circle(t + Vector2(-8, -8), 18.0, Color("43a047"))


func _draw_curb(poly: PackedVector2Array) -> void:
	# Zebra vermelha e branca na borda da pista.
	var n := poly.size()
	var red := true
	var acc := 0.0
	for i in n:
		var a := poly[i]
		var b := poly[(i + 1) % n]
		draw_line(a, b, Color("e53935") if red else Color.WHITE, 14.0)
		acc += a.distance_to(b)
		if acc > 40.0:
			acc = 0.0
			red = not red


func _draw_start_line() -> void:
	var p := center_points[0]
	var dir := (center_points[1] - p).normalized()
	var normal := dir.orthogonal()
	var size := 20.0
	var count := int(track_width / size)
	for row in 2:
		for i in count:
			var c := Color.WHITE if (i + row) % 2 == 0 else Color.BLACK
			var o := p + normal * (-track_width / 2.0 + i * size) + dir * (row * size - size)
			var quad := PackedVector2Array([o, o + normal * size, o + normal * size + dir * size, o + dir * size])
			draw_colored_polygon(quad, c)


static func _smooth_closed(pts: PackedVector2Array, steps: int) -> PackedVector2Array:
	# Curva Catmull-Rom fechada passando por todos os pontos.
	var out := PackedVector2Array()
	var n := pts.size()
	for i in n:
		var p0 := pts[(i - 1 + n) % n]
		var p1 := pts[i]
		var p2 := pts[(i + 1) % n]
		var p3 := pts[(i + 2) % n]
		for s in steps:
			var t := float(s) / steps
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	return out


static func _largest(polys: Array[PackedVector2Array]) -> PackedVector2Array:
	var best := PackedVector2Array()
	var best_area := -1.0
	for poly in polys:
		var area := 0.0
		for i in poly.size():
			area += poly[i].cross(poly[(i + 1) % poly.size()])
		if absf(area) > best_area:
			best_area = absf(area)
			best = poly
	return best
