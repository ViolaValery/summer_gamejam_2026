extends Node
## Dauerhafter Spielstand (Autoload).
##
## Speichert die Fahrzeug-KONFIGURATION als Bauplan, damit sie zwischen
## Werkstatt und Spielszene erhalten bleibt – auch wenn man zurück in die
## Werkstatt geht, ist der Bau wieder genau wie vorher.
##
## Jeder Bauplan-Eintrag beschreibt ein angebautes Teil:
##   { path = Szene des Teils, pos/rot = Lage relativ zum Gefährt, kind = Name }

const INITIAL_BUDGET: int = 1000

var highscore: int
var last_checkpoint: int = 0 # i guess just index?
var last_checkpoint_dist: int = 0

var budget: int = INITIAL_BUDGET # recalculated with new highscore

# checkpoints
const FIRST_CHECKPOINT: int = 150
const CHECKPOINT_COEFF: float = 1.3

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


# calcucate budget depending on score
func set_budget() -> void:
	var score = highscore
	var increment: int = 100 # add N to budget 
	var budget_coeff = 1.3
	var res: int = 0
	while score - FIRST_CHECKPOINT > 0:
		res += increment
		var next_checkpoint = int(FIRST_CHECKPOINT * CHECKPOINT_COEFF)
		increment = int(increment * budget_coeff)
		score -= next_checkpoint

	budget = max(INITIAL_BUDGET, res) 


func get_next_checkpoint() -> int:
	return last_checkpoint_dist + FIRST_CHECKPOINT * int(CHECKPOINT_COEFF ** last_checkpoint) 

func increment_checkpoint(checkpoint: int) -> int:
	last_checkpoint += 1
	last_checkpoint_dist = checkpoint 
	return get_next_checkpoint()
