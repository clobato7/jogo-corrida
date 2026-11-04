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

## Carro escolhido. "static" mantém o valor quando a cena recarrega em "Correr de novo".
static var selected_car := ""


func _ready() -> void:
	track.checkpoint_passed.connect(_on_checkpoint_passed)
	hud.restart_requested.connect(func(): get_tree().reload_current_scene())
	hud.change_car_requested.connect(_on_change_car)

	var start: Transform2D = track.get_start_transform()
	car.global_position = start.origin
	car.rotation = start.get_rotation()
	$Car/Camera2D.reset_smoothing()

	hud.set_lap(1, total_laps)
	hud.set_time(0.0)
	if selected_car == "":
		selected_car = await hud.choose_car()
	car.set_model(selected_car)
	await hud.play_countdown()
	racing = true
	car.can_drive = true


func _on_change_car() -> void:
	selected_car = ""
	get_tree().reload_current_scene()


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
	hud.show_victory(race_time, selected_car)
