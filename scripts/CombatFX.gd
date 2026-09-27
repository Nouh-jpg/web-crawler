extends Node2D

var host: Node = null


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if host != null and host.has_method("draw_world_fx"):
		host.call("draw_world_fx", self)
