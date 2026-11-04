extends CanvasLayer
## Interface: escolha de carro, voltas, tempo, contagem regressiva, vitória com confete
## e controles de toque.
## Toque na metade esquerda da tela = virar à esquerda; metade direita = virar à direita.

signal restart_requested
signal change_car_requested
signal car_chosen(model: String)
signal name_entered

const CarCard := preload("res://scripts/car_card.gd")
const CarIcon := preload("res://scripts/car_icon.gd")
const CONFETTI_COLORS := [Color("ff5252"), Color("ffd740"), Color("69f0ae"), Color("40c4ff"), Color("e040fb"), Color("ffffff")]

@onready var lap_label: Label = $LapLabel
@onready var time_label: Label = $TimeLabel
@onready var countdown_label: Label = $CountdownLabel
@onready var victory_panel: Control = $VictoryPanel
@onready var result_label: Label = $VictoryPanel/Columns/Box/ResultLabel
@onready var restart_button: Button = $VictoryPanel/Columns/Box/RestartButton
@onready var change_car_button: Button = $VictoryPanel/Columns/Box/ChangeCarButton
@onready var ranking_list: VBoxContainer = $VictoryPanel/Columns/RankingBox/RankingList
@onready var ranking_status: Label = $VictoryPanel/Columns/RankingBox/RankingStatus
@onready var change_name_button: Button = $VictoryPanel/Columns/RankingBox/ChangeNameButton
@onready var name_prompt: Control = $NamePrompt
@onready var name_edit: LineEdit = $NamePrompt/Panel/Box/NameEdit
@onready var save_button: Button = $NamePrompt/Panel/Box/SaveButton
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
	name_prompt.hide()
	save_button.pressed.connect(_on_name_confirmed)
	name_edit.text_submitted.connect(func(_t): _on_name_confirmed())
	change_name_button.pressed.connect(_on_change_name)
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


func show_victory(seconds: float, car: String) -> void:
	_touches.clear()
	_apply_touches()
	result_label.text = "Tempo: " + format_time(seconds)
	celebrate()
	# O painel aparece logo depois dos primeiros fogos.
	await get_tree().create_timer(0.6).timeout
	victory_panel.show()
	_run_ranking(int(round(seconds * 1000.0)), car)


# ── Ranking ─────────────────────────────────────

## Envia o tempo e mostra o top 10. Na primeira vez pergunta o nome.
func _run_ranking(time_ms: int, car: String) -> void:
	change_name_button.hide()
	if Leaderboard.player_name == "":
		await ask_name()
	ranking_status.text = "Enviando seu tempo..."
	var sent: Dictionary = await Leaderboard.submit(time_ms, car)
	var top = await Leaderboard.fetch_top()
	if top is Array:
		_render_top(top)
	if sent.has("error"):
		ranking_status.text = "Não deu para enviar o tempo (%s)" % sent["error"]
	else:
		var pos: int = sent["position"]
		var text := "Você ficou em %dº lugar!" % pos
		if sent["personal_best"]:
			text += " Novo recorde seu!"
		ranking_status.text = text
		if pos == 1:
			Sfx.play("win")
	if not top is Array:
		ranking_status.text = "Ranking indisponível agora (sem conexão)"
	change_name_button.text = "Jogando como %s (trocar)" % Leaderboard.player_name
	change_name_button.show()


func ask_name() -> void:
	name_edit.text = Leaderboard.player_name
	name_prompt.show()
	name_edit.grab_focus()
	await name_entered
	name_prompt.hide()


func _on_name_confirmed() -> void:
	var typed := name_edit.text.strip_edges()
	if typed == "":
		return
	Leaderboard.save_player_name(typed)
	name_entered.emit()


func _on_change_name() -> void:
	await ask_name()
	change_name_button.text = "Jogando como %s (trocar)" % Leaderboard.player_name


func _render_top(rows: Array) -> void:
	for child in ranking_list.get_children():
		child.queue_free()
	if rows.is_empty():
		ranking_status.text = "Seja o primeiro do ranking!"
		return
	for row in rows:
		var is_me: bool = row["player_name"] == Leaderboard.player_name
		var color := Color(1, 0.84, 0.2) if is_me else Color.WHITE
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 12)
		line.add_child(_cell("%dº" % int(row["pos"]), 50, color, HORIZONTAL_ALIGNMENT_RIGHT))
		var icon := CarIcon.new()
		icon.model = row["car"]
		line.add_child(icon)
		var name_cell := _cell(row["player_name"], 0, color)
		name_cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(name_cell)
		line.add_child(_cell(format_time(int(row["time_ms"]) / 1000.0), 130, color, HORIZONTAL_ALIGNMENT_RIGHT))
		ranking_list.add_child(line)


func _cell(text: String, width: float, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size.x = width
	l.horizontal_alignment = align
	l.clip_text = true
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", color)
	return l


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
