extends Node
## Dauerhafter Spielstand (Autoload).
##
## Speichert die Fahrzeug-KONFIGURATION als Bauplan, damit sie zwischen
## Werkstatt und Spielszene erhalten bleibt – auch wenn man zurück in die
## Werkstatt geht, ist der Bau wieder genau wie vorher.
##
## Jeder Bauplan-Eintrag beschreibt ein angebautes Teil:
##   { path = Szene des Teils, pos/rot = Lage relativ zum Gefährt, kind = Name }

var blueprint: Array = []


# Liest den Bauplan aus den aktuell angebauten Teilen eines Gefährts.
func save_from(vehicle: Node2D) -> void:
	blueprint.clear()
	var chassis := vehicle.get_node("Chassis")
	for child in vehicle.get_children():
		if child is RigidBody2D and child != chassis:
			blueprint.append({
				"path": child.scene_file_path,
				"pos": child.position,
				"rot": child.rotation,
				"kind": child.get_meta("kind", ""),
			})


# Baut die Teile aus dem Bauplan als (eingefrorene) Kinder ins Gefährt.
func build_into(vehicle: Node2D) -> void:
	for entry in blueprint:
		if entry.path == "":
			continue
		var part := (load(entry.path) as PackedScene).instantiate()
		vehicle.add_child(part)
		part.position = entry.pos
		part.rotation = entry.rot
		part.freeze = true
		part.set_meta("kind", entry.kind)
