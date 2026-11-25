extends Area2D

@export var next_level = ""

func _on_body_entered(_body: Node2D) -> void:
	call_deferred("load_next_scene")

func load_next_scene():
	pass
