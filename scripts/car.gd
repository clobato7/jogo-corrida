extends CharacterBody2D
## Carro do piloto. Acelera sozinho; o jogador só vira para a esquerda ou direita.

@export var max_speed := 500.0       ## velocidade máxima (pixels por segundo)
@export var acceleration := 200.0    ## quanto a velocidade sobe por segundo
@export var turn_speed := 3.0        ## quão rápido o carro vira (radianos por segundo)
@export var grip := 4.0              ## aderência: quanto maior, menos o carro "escorrega"
@export var wall_slowdown := 0.5     ## ao bater, a velocidade é multiplicada por isso
@export var body_color := Color("b96f00")
@export var desktop_zoom := 0.85     ## zoom da câmera no PC (menor = mais afastado)
@export var mobile_zoom := 1.25      ## zoom da câmera no celular (tela pequena, câmera mais perto)
@export var engine_idle_pitch := 0.6 ## tom do motor parado
@export var engine_max_pitch := 1.8  ## tom do motor na velocidade máxima

var speed := 0.0
var can_drive := false
var _hit_cooldown := 0.0


func _ready() -> void:
	var zoom := mobile_zoom if is_mobile() else desktop_zoom
	$Camera2D.zoom = Vector2(zoom, zoom)


## Verdadeiro no celular, tanto no app nativo quanto no navegador (Android ou iPhone).
static func is_mobile() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")


func _physics_process(delta: float) -> void:
	if can_drive:
		speed = move_toward(speed, max_speed, acceleration * delta)
		var steer := Input.get_axis("steer_left", "steer_right")
		# Parado o carro não gira; ganha controle conforme acelera.
		rotation += steer * turn_speed * delta * clampf(speed / 200.0, 0.0, 1.0)
	else:
		speed = move_toward(speed, 0.0, acceleration * 2.0 * delta)

	_update_engine_sound()

	var forward := Vector2.RIGHT.rotated(rotation)
	velocity = velocity.lerp(forward * speed, clampf(grip * delta, 0.0, 1.0))
	move_and_slide()

	_hit_cooldown -= delta
	if get_slide_collision_count() > 0:
		var normal := get_slide_collision(0).get_normal()
		# Vira o carro um pouco na direção da parede, para não ficar preso de frente.
		var tangent := normal.orthogonal()
		if tangent.dot(forward) < 0.0:
			tangent = -tangent
		rotation = lerp_angle(rotation, tangent.angle(), 0.25)
		if _hit_cooldown <= 0.0:
			if speed > 120.0:
				Sfx.play("hit")
			speed *= wall_slowdown
			velocity *= wall_slowdown
			_hit_cooldown = 0.3


func _update_engine_sound() -> void:
	# O tom do motor acompanha a velocidade.
	var t := clampf(speed / max_speed, 0.0, 1.0)
	$EngineSound.pitch_scale = lerpf(engine_idle_pitch, engine_max_pitch, t)
	$EngineSound.volume_db = lerpf(-20.0, -10.0, t)


func _draw() -> void:
	# Desenho simples do carro (apontando para a direita, que é a "frente").
	var wheel := Color("222222")
	for p in [Vector2(-20, -18), Vector2(12, -18), Vector2(-20, 12), Vector2(12, 12)]:
		draw_rect(Rect2(p, Vector2(12, 6)), wheel)
	draw_rect(Rect2(-30, -14, 60, 28), body_color)
	draw_rect(Rect2(14, -10, 10, 20), Color("90caf9"))   # para-brisa
	draw_rect(Rect2(-30, -14, 8, 28), body_color.darkened(0.3))  # aerofólio
	draw_circle(Vector2(-2, 0), 8.0, Color("ffd54f"))     # capacete do piloto
	draw_circle(Vector2(1, 0), 3.0, Color("333333"))      # viseira
