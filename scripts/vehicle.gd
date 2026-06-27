extends Node2D
## Baseline-Gefährt: nur ein Fahrwerk ("Chassis").
##
## Welche Teile drankommen, wird NICHT hier festgelegt, sondern in der
## Editor-Szene angebaut (als Kinder dieses Knotens).
##
## assemble() verbindet dann alle angebauten Teile – je nach metadata/attach:
##   "pin"  = drehbares Gelenk (Reifen rollt, Ballon pendelt)
##   "weld" = VERSCHMELZEN: die Form des Teils wird Teil des Fahrwerks, also
##            ein einziger starrer Körper. Dreht sich nie weg, auch nicht nach
##            einem harten Aufprall (z.B. Booster).

@onready var chassis: RigidBody2D = $Chassis


func assemble() -> void:
	for child in get_children():
		if child is RigidBody2D and child != chassis:
			if child.get_meta("attach", "pin") == "weld":
				_weld(child)
			else:
				_pin(child)


# Drehbares Gelenk in der Teil-Mitte (Reifen, Ballon).
func _pin(part: RigidBody2D) -> void:
	var joint := PinJoint2D.new()
	add_child(joint)
	joint.global_position = part.global_position
	joint.node_a = chassis.get_path()
	joint.node_b = part.get_path()


# Verschmilzt ein Teil fest mit dem Fahrwerk: Form + Optik werden Kinder des
# Chassis (Weltposition bleibt). Damit ist es ein einziger starrer Körper.
func _weld(part: RigidBody2D) -> void:
	for child in part.get_children():
		if child is CollisionShape2D or child is Polygon2D:
			child.reparent(chassis)

	chassis.mass += part.mass  # Masse dazu (Schwerpunkt rechnet Godot selbst neu)

	# Das Teil bleibt als reiner Logik-/Schub-Knoten am Fahrwerk hängen.
	part.reparent(chassis)
	part.freeze = true
	part.collision_layer = 0
	part.collision_mask = 0
	# Hat es eine Schub-Logik (Booster)? Dann ab jetzt aufs Fahrwerk wirken.
	if "host" in part:
		part.set("host", chassis)
