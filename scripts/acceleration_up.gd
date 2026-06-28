extends Area2D

@export var push_force := Vector2(500, -200)  # Direction and strength

func _physics_process(delta):
	for body in get_overlapping_bodies():
		if body is RigidBody2D:
			body.apply_central_force(push_force)
		elif body is CharacterBody2D:
			body.velocity += push_force * delta
			body.move_and_slide()
