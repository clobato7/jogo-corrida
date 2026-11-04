extends SceneTree
## Teste de corrida completa com piloto automático (sem tela).
## Uso: godot --headless --path . -s tools/test/autopilot.gd
## Variável CAR escolhe o carro (padrão caminhao_azul). Deve imprimir "FINISHED laps=3".
## O ranking é apontado para um endereço inválido para nunca gravar no Supabase real.

var main
var t := 0.0
var hits := 0
var done := false


func _initialize() -> void:
	root.get_node("Leaderboard")._base_url = "http://127.0.0.1:9/rest/v1/rpc/"
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _physics_process(delta: float) -> bool:
	t += delta
	if main == null or not main.is_node_ready():
		return false
	if main.hud.car_select.visible:
		var car_model := OS.get_environment("CAR")
		main.hud.car_chosen.emit(car_model if car_model != "" else "caminhao_azul")
	var tr = main.track
	var car = main.car
	# Mira num ponto um pouco à frente na linha central da pista
	var best := 0
	var bd := INF
	for i in tr.center_points.size():
		var d: float = car.global_position.distance_to(tr.center_points[i])
		if d < bd:
			bd = d
			best = i
	var target: Vector2 = tr.center_points[(best + 6) % tr.center_points.size()]
	var ang := wrapf((target - car.global_position).angle() - car.rotation, -PI, PI)
	Input.action_release("steer_left")
	Input.action_release("steer_right")
	if ang < -0.05:
		Input.action_press("steer_left")
	elif ang > 0.05:
		Input.action_press("steer_right")
	if car.get_slide_collision_count() > 0:
		hits += 1
	if main.hud.victory_panel.visible and not done:
		done = true
		print("FINISHED laps=", main.laps_done, " time=", main.race_time, " wallframes=", hits)
		quit()
	if t > 180:
		print("TIMEOUT laps=", main.laps_done, " next=", main.next_checkpoint, " speed=", car.speed)
		quit()
	return false
