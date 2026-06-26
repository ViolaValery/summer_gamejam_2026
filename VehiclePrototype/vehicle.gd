extends RigidBody2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("activate"):
		for child in $Attachments.get_children():
			if child.has_method("activate"):
				child.activate()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	for child in $Attachments.get_children():
		if child.has_method("get_force"):
			var child_velocity: Vector2 = linear_velocity + angular_velocity * (child.position).orthogonal()
			var force: Vector2 = child.get_force(child_velocity)
			apply_force(force, child.global_position - global_position)
