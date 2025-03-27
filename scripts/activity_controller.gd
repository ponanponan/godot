extends Node



func play_vedio(parent: Node, on_finished = null):
	print("🎬 播放影片被呼叫")
	var vedio_scene = preload("res://scene/vedio.tscn")
	var vedio_instance = vedio_scene.instantiate()
	parent.add_child(vedio_instance)

	var player = vedio_instance.get_node("SubViewport/VideoStreamPlayer")
	player.play()

	# 當影片播放完畢，自動解除鎖定
	player.connect("finished", Callable(self, "_on_video_finished").bind(vedio_instance, on_finished))

func _on_video_finished(vedio_node, callback):
	vedio_node.queue_free()
	if callback:
		callback.call()
