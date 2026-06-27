extends RigidBody2D
## Raketen-Boost.
##
## Zwei Lebenslagen:
##  - allein (in der Palette / frei gefallen): drückt sich selbst.
##  - verschmolzen mit der Basis: "host" ist gesetzt -> der Schub wirkt auf die
##    Basis (am Ort der Rakete, damit auch das Drehmoment stimmt).
##
## Der orange Pfeil (_draw) zeigt immer die echte Schubrichtung und dreht
## automatisch mit, weil _draw in lokalen Koordinaten zeichnet.

@export var thrust: float = 1500.0:
	set(value):
		thrust = value
		queue_redraw()

# Wird beim Verschmelzen von world.gd gesetzt (die Basis).
var host: RigidBody2D = null


func _physics_process(_delta: float) -> void:
	var dir := Vector2.UP.rotated(global_rotation)
	if host != null and is_instance_valid(host):
		# Schub auf das verschmolzene Fahrzeug, angreifend am Ort der Rakete.
		host.apply_force(dir * thrust, global_position - host.global_position)
	else:
		apply_central_force(dir * thrust)


func _draw() -> void:
	var col := Color(1.0, 0.7, 0.2)
	var start := Vector2(0, -25)
	var length: float = clampf(thrust / 12.0, 20.0, 130.0)
	var tip := start + Vector2(0, -length)
	draw_line(start, tip, col, 4.0)
	draw_line(tip, tip + Vector2(-8, 12), col, 4.0)
	draw_line(tip, tip + Vector2(8, 12), col, 4.0)
