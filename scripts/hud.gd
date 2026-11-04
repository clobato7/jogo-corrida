extends CanvasLayer
## Interface: voltas, tempo, contagem regressiva, tela de vitória e controles de toque.
## Toque na metade esquerda da tela = virar à esquerda; metade direita = virar à direita.

signal restart_requested
signal start_pressed

@onready var lap_label: Label = $LapLabel
@onready var time_label: Label = $TimeLabel
@onready var countdown_label: Label = $CountdownLabel
@onready var victory_panel: Control = $VictoryPanel
@onready var result_label: Label = $VictoryPanel/Box/ResultLabel
@onready var restart_button: Button = $VictoryPanel/Box/RestartButton
@onready var start_screen: Control = $StartScreen
@onready var tap_label: Label = $StartScreen/Box/TapLabel

var _touches := {}   # índice do dedo -> -1 (esquerda) ou 1 (direita)
var _left_on := false
var _right_on := false
var _blink_tween: Tween
var _ignore_presses_until := 0  # evita que o toque de início também vire o carro


func _ready() -> void:
	victory_panel.hide()
	countdown_label.hide()
	start_screen.hide()
	restart_button.pressed.connect(func(): restart_requested.emit())


func set_lap(current: int, total: int) -> void:
	lap_label.text = "Volta %d/%d" % [current, total]


func set_time(seconds: float) -> void:
	time_label.text = format_time(seconds)


## Mostra a tela inicial e espera um toque (ou clique/tecla).
## O navegador só libera o som depois de uma interação, por isso esse toque é obrigatório.
func wait_for_start() -> void:
	start_screen.show()
	_blink_tween = create_tween().set_loops()
	_blink_tween.tween_property(tap_label, "modulate:a", 0.3, 0.6)
	_blink_tween.tween_property(tap_label, "modulate:a", 1.0, 0.6)
	await start_pressed
	_blink_tween.kill()
	start_screen.hide()
	_ignore_presses_until = Time.get_ticks_msec() + 300


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
	victory_panel.show()


static func format_time(seconds: float) -> String:
	return "%d:%05.2f" % [floori(seconds / 60.0), fmod(seconds, 60.0)]


func _input(event: InputEvent) -> void:
	if start_screen.visible:
		var tapped: bool = (event is InputEventScreenTouch or event is InputEventMouseButton or event is InputEventKey) and event.pressed
		if tapped:
			get_viewport().set_input_as_handled()
			start_pressed.emit()
		return
	if victory_panel.visible:
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
