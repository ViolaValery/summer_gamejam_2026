extends Node2D

@export var duration = 3
@export var output_force = 100
var active = false

func activate() -> void:
	active = true
	await get_tree().create_timer(3.0).timeout
	active = false

func get_force() -> Vector2:
	if not active:
		return Vector2.ZERO
	print("firing")
	return Vector2(output_force, 0)
