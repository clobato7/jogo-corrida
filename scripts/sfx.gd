extends Node
## Autoload "Sfx": toca os efeitos sonoros de qualquer lugar do jogo.
## Exemplo: Sfx.play("beep")
## O som ambiente começa sozinho e fica em loop.

const SOUNDS := {
	"hit": preload("res://assets/sfx/hit.wav"),
	"beep": preload("res://assets/sfx/beep.wav"),
	"go": preload("res://assets/sfx/go.wav"),
	"lap": preload("res://assets/sfx/lap.wav"),
	"win": preload("res://assets/sfx/win.wav"),
}
const VOLUMES := {"hit": -4.0, "beep": -6.0, "go": -4.0, "lap": -4.0, "win": -2.0}

@export var ambient_volume_db := -16.0

var _ambient: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ambient = AudioStreamPlayer.new()
	_ambient.stream = preload("res://assets/sfx/ambient.wav")
	_ambient.volume_db = ambient_volume_db
	add_child(_ambient)
	_ambient.play()


func play(sound_name: String) -> void:
	# Cria um player para cada som, assim vários podem tocar ao mesmo tempo.
	var player := AudioStreamPlayer.new()
	player.stream = SOUNDS[sound_name]
	player.volume_db = VOLUMES.get(sound_name, 0.0)
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()
