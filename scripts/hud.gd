extends CanvasLayer
## Interface: escolha de carro, voltas, tempo, contagem regressiva, vitória com confete
## e controles de toque.
## Toque na metade esquerda da tela = virar à esquerda; metade direita = virar à direita.

signal restart_requested
signal change_car_requested
signal car_chosen(model: String)

const CarCard := preload("res://scripts/car_card.gd")
const CONFETTI_COLORS := [Color("ff5252"), Color("ffd740"), Color("69f0ae"), Color("40c4ff"), Color("e040fb"), Color("ffffff")]

@onready var lap_label: Label = $LapLabel
@onready var time_label: Label = $TimeLabel
@onready var countdown_label: Label = $CountdownLabel
@onready var victory_panel: Control = $VictoryPanel
@onready var result_label: Label = $VictoryPanel/Box/ResultLabel
@onready var restart_button: Button = $VictoryPanel/Box/RestartButton
@onready var change_car_button: Button = $VictoryPanel/Box/ChangeCarButton
@onready var car_select: Control = $CarSelect
@onready var cards: HBoxContainer = $CarSelect/Box/Cards

var _touches := {}   # índice do dedo -> -1 (esquerda) ou 1 (direita)
var _left_on := false
var _right_on := false
var _ignore_presses_until := 0  # evita que o toque da escolha também vire o carro


func _ready() -> void:
	victory_panel.hide()
	countdown_label.hide()
	car_select.hide()
	restart_button.pressed.connect(func(): restart_requested.emit())
	change_car_button.pressed.connect(func(): change_car_requested.emit())
	for model in CarArt.ORDER:
		var card := CarCard.new()
		card.model = model
		card.pressed.connect(func(): car_chosen.emit(model))
		cards.add_child(card)


func set_lap(current: int, total: int) -> void:
	lap_label.text = "Volta %d/%d" % [current, total]


func set_time(seconds: float) -> void:
	time_label.text = format_time(seconds)


## Mostra a tela de escolha e espera o jogador tocar num carro.
## Esse toque também libera o som no navegador.
func choose_car() -> String:
	car_select.show()
	var model: String = await car_chosen
	car_select.hide()
	_ignore_presses_until = Time.get_ticks_msec() + 300
	return model


func play_countdown() -> void:
	countdown_label.show()
	for text in ["3", "2", "1"]:
		countdown_label.text = text
		Sfx.play("beep")
		await get_tree().create_timer(0.8).timeout
	countdown_label.text = "VAI!"
	Sfx.play("go")
	get_tree().create_timer(0.8).timeout.connect(countdown_label.hide)


func show_victory(seconds: float) -> void:
	_touches.clear()
	_apply_touches()
	result_label.text = "Tempo: " + format_time(seconds)
	celebrate()
	# O painel aparece logo depois dos primeiros fogos.
	await get_tree().create_timer(0.6).timeout
	victory_panel.show()


## Chuva de confete e alguns fogos estourando pela tela.
func celebrate() -> void:
	var view := get_viewport().get_visible_rect().size
	add_child(_confetti_rain(view))
	var spots := [Vector2(0.2, 0.3), Vector2(0.8, 0.25), Vector2(0.5, 0.18), Vector2(0.3, 0.6), Vector2(0.72, 0.55)]
	for i in spots.size():
		get_tree().create_timer(i * 0.35).timeout.connect(func():
			add_child(_firework(view * spots[i], CONFETTI_COLORS[i % CONFETTI_COLORS.size()]))
			Sfx.play("pop"))


func _confetti_rain(view: Vector2) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.position = Vector2(view.x / 2.0, -20)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(view.x / 2.0, 10)
	p.amount = 160
	p.lifetime = 4.0
	p.one_shot = true
	p.explosiveness = 0.3
	p.direction = Vector2.DOWN
	p.spread = 25.0
	p.gravity = Vector2(0, 180)
	p.initial_velocity_min = 80.0
	p.initial_velocity_max = 220.0
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	p.scale_amount_min = 6.0
	p.scale_amount_max = 12.0
	p.color_initial_ramp = _rainbow()
	p.texture = _confetti_texture()
	p.finished.connect(p.queue_free)
	p.emitting = true
	return p


func _firework(pos: Vector2, color: Color) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.position = pos
	p.amount = 70
	p.lifetime = 1.4
	p.one_shot = true
	p.explosiveness = 1.0
	p.spread = 180.0
	p.gravity = Vector2(0, 120)
	p.initial_velocity_min = 150.0
	p.initial_velocity_max = 320.0
	p.damping_min = 80.0
	p.damping_max = 120.0
	p.scale_amount_min = 5.0
	p.scale_amount_max = 9.0
	var fade := Gradient.new()
	fade.set_color(0, color.lightened(0.4))
	fade.set_color(1, Color(color, 0.0))
	p.color_ramp = fade
	p.texture = _confetti_texture()
	p.finished.connect(p.queue_free)
	p.emitting = true
	return p


func _rainbow() -> Gradient:
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	var offsets := PackedFloat32Array()
	for i in CONFETTI_COLORS.size():
		offsets.append(float(i) / CONFETTI_COLORS.size())
	g.offsets = offsets
	g.colors = PackedColorArray(CONFETTI_COLORS)
	return g


static var _tex: ImageTexture
static func _confetti_texture() -> ImageTexture:
	# Um quadradinho branco de 1 px; a cor vem das partículas e o tamanho do scale.
	if _tex == null:
		var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_tex = ImageTexture.create_from_image(img)
	return _tex


static func format_time(seconds: float) -> String:
	return "%d:%05.2f" % [floori(seconds / 60.0), fmod(seconds, 60.0)]


func _input(event: InputEvent) -> void:
	if car_select.visible or victory_panel.visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed and Time.get_ticks_msec() < _ignore_presses_until:
			return
		if event.pressed:
			_touches[event.index] = _side(event.position)
		else:
			_touches.erase(event.index)
		_apply_touches()
	elif event is InputEventScreenDrag:
		_touches[event.index] = _side(event.position)
		_apply_touches()


func _side(pos: Vector2) -> int:
	return -1 if pos.x < get_viewport().get_visible_rect().size.x / 2.0 else 1


func _apply_touches() -> void:
	# O toque "aperta" as mesmas ações do teclado, então o carro não precisa saber de onde veio.
	var left: bool = _touches.values().has(-1)
	var right: bool = _touches.values().has(1)
	if left != _left_on:
		_left_on = left
		if left: Input.action_press("steer_left")
		else: Input.action_release("steer_left")
	if right != _right_on:
		_right_on = right
		if right: Input.action_press("steer_right")
		else: Input.action_release("steer_right")
