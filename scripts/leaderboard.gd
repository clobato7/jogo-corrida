extends Node
## Autoload "Leaderboard": conversa com o ranking no Supabase (schema "corrida").
## A chave usada é a publishable key, que é pública por natureza: o banco só deixa
## ela chamar as funções submit_time e top_times (ver supabase/ranking.sql).
## Também guarda no aparelho o nome do jogador.

const BASE_URL := "https://ghshlpnxrcwwpujyypmd.supabase.co/rest/v1/rpc/"
const PUBLISHABLE_KEY := "sb_publishable_SgQI0zlyT3kAE3Zes15Ipw_DMXRWaxe"
const SCHEMA := "corrida"
const TRACK_ID := "pista1"   ## mude se o traçado da pista mudar, para começar um ranking novo
const SAVE_PATH := "user://jogador.cfg"

var player_name := ""
var _base_url := BASE_URL


func _ready() -> void:
	# Nos testes locais dá para apontar para outro servidor (só em build de debug).
	if OS.is_debug_build() and OS.get_environment("RANKING_URL") != "":
		_base_url = OS.get_environment("RANKING_URL")
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		player_name = cfg.get_value("jogador", "nome", "")


func save_player_name(new_name: String) -> void:
	player_name = new_name.strip_edges().left(16)
	var cfg := ConfigFile.new()
	cfg.set_value("jogador", "nome", player_name)
	cfg.save(SAVE_PATH)


## Lista com os 10 melhores: [{pos, player_name, time_ms, car}, ...]
## Em caso de erro devolve {"error": "mensagem"}.
func fetch_top() -> Variant:
	var res: Dictionary = await _rpc("top_times", {"p_track": TRACK_ID, "p_limit": 10})
	return res["data"] if res.has("data") else res


## Envia o tempo. Devolve {"position": n, "personal_best": bool} ou {"error": "..."}.
func submit(time_ms: int, car: String) -> Dictionary:
	var res: Dictionary = await _rpc("submit_time", {
		"p_name": player_name, "p_time_ms": time_ms, "p_car": car, "p_track": TRACK_ID})
	if res.has("error"):
		return res
	return res["data"] if res["data"] is Dictionary else {"error": "Resposta inesperada"}


func _rpc(function_name: String, body: Dictionary) -> Dictionary:
	var req := HTTPRequest.new()
	req.timeout = 10.0
	add_child(req)
	var headers := PackedStringArray([
		"apikey: " + PUBLISHABLE_KEY,
		"Content-Type: application/json",
		"Content-Profile: " + SCHEMA,
		"Accept-Profile: " + SCHEMA,
	])
	var err := req.request(_base_url + function_name, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		req.queue_free()
		return {"error": "Sem conexão"}
	var result: Array = await req.request_completed
	req.queue_free()
	if result[0] != HTTPRequest.RESULT_SUCCESS:
		return {"error": "Sem conexão"}
	var data = JSON.parse_string((result[3] as PackedByteArray).get_string_from_utf8())
	if result[1] >= 300:
		var msg: String = data.get("message", "Erro %d" % result[1]) if data is Dictionary else "Erro %d" % result[1]
		return {"error": msg}
	return {"data": data}
