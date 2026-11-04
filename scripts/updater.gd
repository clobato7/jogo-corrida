extends CanvasLayer
## Autoload "Updater": avisa quando existe uma versão nova do jogo publicada.
##
## O navegador guarda os arquivos do jogo (cache do site e service worker do PWA)
## e pode continuar abrindo uma versão antiga. Por isso, ao abrir, o jogo consulta
## o version.txt do site sem cache. Se a versão publicada for diferente da que está
## rodando, aparece um botão que limpa o cache e recarrega a página.

var _button: Button


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not OS.has_feature("web") or BuildInfo.VERSION == "dev":
		return
	JavaScriptBridge.pwa_update_available.connect(_show_banner)
	if JavaScriptBridge.pwa_needs_update():
		_show_banner()
	_check_published_version()


func _check_published_version() -> void:
	var page_url: String = JavaScriptBridge.eval("location.origin + location.pathname", true)
	var base := page_url.substr(0, page_url.rfind("/") + 1)
	var req := HTTPRequest.new()
	req.accept_gzip = false
	add_child(req)
	var url := "%sversion.txt?t=%d" % [base, Time.get_unix_time_from_system()]
	if req.request(url, PackedStringArray(["Cache-Control: no-cache"])) != OK:
		return
	var result: Array = await req.request_completed
	req.queue_free()
	if result[0] != HTTPRequest.RESULT_SUCCESS or result[1] != 200:
		return
	var published := (result[3] as PackedByteArray).get_string_from_utf8().strip_edges()
	if published != "" and published != BuildInfo.VERSION:
		_show_banner(published)


func _show_banner(new_version := "") -> void:
	if _button != null:
		return
	_button = Button.new()
	var label := "Nova versão disponível"
	if new_version != "":
		label += " (%s)" % new_version
	_button.text = label + "! Toque aqui para atualizar"
	_button.focus_mode = Control.FOCUS_NONE
	_button.add_theme_font_size_override("font_size", 28)
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		_button.add_theme_color_override(c, Color("1b1b1b"))
	var style := StyleBoxFlat.new()
	style.bg_color = Color("ffd740")
	style.set_corner_radius_all(18)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 8
	for state in ["normal", "hover", "pressed"]:
		_button.add_theme_stylebox_override(state, style)
	_button.anchor_left = 0.5
	_button.anchor_right = 0.5
	_button.offset_top = 90
	_button.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_button.pressed.connect(_update_now)
	add_child(_button)


func _update_now() -> void:
	_button.text = "Atualizando..."
	# Remove o service worker e o cache do jogo e recarrega pedindo os arquivos de novo.
	JavaScriptBridge.eval("""
		(async () => {
			try {
				const regs = await navigator.serviceWorker.getRegistrations();
				await Promise.all(regs.map(r => r.unregister()));
				const keys = await caches.keys();
				await Promise.all(keys.map(k => caches.delete(k)));
			} catch (e) {}
			location.replace(location.pathname + '?v=' + Date.now());
		})();
	""", true)
