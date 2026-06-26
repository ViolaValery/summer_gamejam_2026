extends Node2D

@export var rest_length := 50
@export var suspension_stiffness := 3.0
@export var suspension_damping := 2.0
var axis_position := Vector2.ZERO
var axis_velocity := Vector2.ZERO

func _process(delta: float) -> void:
	var old_axis_position := axis_position
	if $RayCast2D.is_colliding():
		axis_position = $RayCast2D.get_collision_point() - global_position
	else:
		axis_position = $RayCast2D.target_position
	$Sprite2D.position = axis_position
	axis_velocity = axis_position - old_axis_position
	$Sprite2D.rotate(delta)


func get_force(local_velocity: Vector2) -> Vector2:
	if not $RayCast2D.is_colliding():
		return Vector2.ZERO
	
	var distance_to_floor := ($RayCast2D.get_collision_point() as Vector2 - global_position).length()
	var compression := rest_length - distance_to_floor
	
	if compression <= 0:
		return Vector2.ZERO

	var suspension_direction: Vector2 = $RayCast2D.target_position.normalized()
	var suspension_force := suspension_stiffness * compression
	
	print("axis velocity: ", axis_velocity)
	var damping_force := suspension_damping * axis_velocity.dot(-suspension_direction)
	print("suspension: ", suspension_force)
	print("damping: ", damping_force)
	print("total: ", suspension_force + damping_force)
	return (suspension_force + damping_force) * -suspension_direction
	
	
