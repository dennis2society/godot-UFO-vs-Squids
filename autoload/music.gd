extends AudioStreamPlayer
## The gameplay soundtrack. Lives outside the levels, so it plays straight through
## restarts and level changes, and through the pause menu.

const TRACK := preload("res://sounds/music.ogg")
const VOLUME_DB := -13.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var track: AudioStreamOggVorbis = TRACK
	track.loop = true
	stream = track
	bus = &"Music"
	volume_db = VOLUME_DB


## Levels call this when they open. Does nothing if off or already playing.
func start() -> void:
	if Settings.music and not playing:
		play()


func set_enabled(value: bool) -> void:
	Settings.set_music(value)
	if value:
		start()
	else:
		stop()
