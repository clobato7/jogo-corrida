extends Node2D
## Controla a corrida: largada, contagem de voltas e vitória.

@export var total_laps := 3

@onready var track = $Track
@onready var car = $Car
@onready var hud = $HUD

var laps_done := 0
var next_checkpoint := 1   # o carro larga logo depois da linha (checkpoint 0)
var race_time := 0.0
var racing := false

## Só mostra a tela inicial na primeira corrida. "static" mantém o valor ao recarregar a cena.
static var _first_race := true


func _ready() -> void:
	track.checkpoint_passed.connect(_on_checkpoint_passed)
	hud.restart_requested.connect(func(): get_tree().reload_current_scene())

	var start: Transform2D = track.get_start_transform()
	car.global_position = start.origin
	car.rotation = start.get_rotation()
	$Car/Camera2D.reset_smoothing()

	hud.set_lap(1, total_laps)
	hud.set_time(0.0)
	if _first_race:
		_first_race = false
		await hud.wait_for_start()
	await hud.play_countdown()
	racing = true
	car.can_drive = true


func _process(delta: float) -> void:
	if racing:
		race_time += delta
		hud.set_time(race_time)


func _on_checkpoint_passed(index: int, body: Node2D) -> void:
	if not racing or body != car or index != next_checkpoint:
		return
	next_checkpoint = (next_checkpoint + 1) % track.checkpoint_count
	if index == 0:
		laps_done += 1
		if laps_done >= total_laps:
			_finish()
		else:
			Sfx.play("lap")
			hud.set_lap(laps_done + 1, total_laps)


func _finish() -> void:
	racing = false
	car.can_drive = false
	Sfx.play("win")
	hud.show_victory(race_time)
