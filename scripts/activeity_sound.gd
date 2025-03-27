extends Node

const JACKPOT_SOUND_PATH := "res://sound/sound.mp3"

func play_jackpot(parent: Node, on_finished = null):
	var player = AudioStreamPlayer.new()
	player.stream = preload(JACKPOT_SOUND_PATH)
	parent.add_child(player)
	player.play()
	player.connect("finished", Callable(self, "_on_finished").bind(player, on_finished))


func _on_finished(player: AudioStreamPlayer, callback: Callable):
	player.queue_free()

	if callback:
		callback.call()
