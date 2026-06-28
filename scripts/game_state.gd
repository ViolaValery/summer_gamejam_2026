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

## Gesamtbudget (aus Highscore) – die Obergrenze. Ändert sich nur über set_budget().
var base_budget: int = INITIAL_BUDGET
## Aktuell verfügbares Geld = base_budget minus Wert der verbauten Teile.
## Wird in der Werkstatt aus den tatsächlich verbauten Teilen neu berechnet,
## damit es IMMER stimmt (Kauf, Verschieben, Zurückgeben).
var budget: int = INITIAL_BUDGET

# checkpoints
const FIRST_CHECKPOINT: int = 150
const CHECKPOINT_COEFF: float = 1.3

var blueprint: Array = []

## Datengetriebene Progression (vom Level-Editor erstellt). Fehlt sie, greift
## überall die alte Formel – das Spiel funktioniert also auch ohne Config.
const PROGRESSION_PATH := "res://config/progression.tres"
var progression = null   # ProgressionConfig (untypisiert wg. class_name-Auflösung)


func _ready() -> void:
	if ResourceLoader.exists(PROGRESSION_PATH):
		progression = load(PROGRESSION_PATH)


func has_progression() -> bool:
	return progression != null and progression.count() > 0


# Ist das Item auf dem aktuellen Level im Shop verfügbar?
func is_item_available(id: String) -> bool:
	if has_progression():
		return id in progression.items_at(last_checkpoint)
	if ItemCatalog.has(id):
		return ItemCatalog.get_def(id).unlock_checkpoint <= last_checkpoint
	return true


# Erstes Level, auf dem das Item verfügbar ist (für "ab Level X").
func unlock_level_of(id: String) -> int:
	if has_progression():
		return progression.unlock_level_of(id)
	if ItemCatalog.has(id):
		return ItemCatalog.get_def(id).unlock_checkpoint
	return 0


# Budget, das auf Level idx zur Verfügung steht (Config oder Formel).
func budget_for_level(idx: int) -> int:
	if has_progression():
		return maxi(INITIAL_BUDGET, progression.budget_at(idx))
	var res := 0
	var inc := 100
	for k in idx:
		res += inc
		inc = int(inc * 1.3)
	return maxi(INITIAL_BUDGET, res)


# Alle auf Level idx verfügbaren Item-IDs.
func items_for_level(idx: int) -> Array:
	if idx < 0:
		return []
	if has_progression():
		return progression.items_at(idx)
	var arr := []
	for id in ItemCatalog.ids():
		if ItemCatalog.get_def(id).unlock_checkpoint <= idx:
			arr.append(id)
	return arr


# Items, die NEU auf Level idx freigeschaltet werden (gegenüber idx-1).
func new_items_at_level(idx: int) -> Array:
	var before := items_for_level(idx - 1)
	var fresh := []
	for id in items_for_level(idx):
		if not (id in before):
			fresh.append(id)
	return fresh


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
# Katalog-Items über ItemCatalog erzeugen (damit Varianten-Overrides wie
# Größe/Schub erhalten bleiben – sie teilen sich ja dieselbe Szene). Nur was
# nicht im Katalog ist (z.B. die Figur) wird direkt aus dem Pfad geladen.
func build_into(vehicle: Node2D) -> void:
	for entry in blueprint:
		var part: Node = null
		if entry.kind != "" and ItemCatalog.has(entry.kind):
			part = ItemCatalog.create(entry.kind)
		elif entry.path != "":
			part = (load(entry.path) as PackedScene).instantiate()
		if part == null:
			continue
		vehicle.add_child(part)
		part.position = entry.pos
		part.rotation = entry.rot
		part.freeze = true
		part.set_meta("kind", entry.kind)


# calcucate budget depending on score
func set_budget() -> void:
	# Aus der Progression-Config (vom Level-Editor), falls vorhanden.
	if has_progression():
		base_budget = maxi(INITIAL_BUDGET, progression.budget_at(last_checkpoint))
		budget = base_budget
		return
	# Fallback: bisherige Highscore-Formel.
	var score = highscore
	var increment: int = 100 # add N to budget 
	var budget_coeff = 1.3
	var res: int = 0
	while score - FIRST_CHECKPOINT > 0:
		res += increment
		var next_checkpoint = int(FIRST_CHECKPOINT * CHECKPOINT_COEFF)
		increment = int(increment * budget_coeff)
		score -= next_checkpoint

	base_budget = max(INITIAL_BUDGET, res)
	budget = base_budget


func get_next_checkpoint() -> int:
	if has_progression():
		return progression.distance_at(last_checkpoint + 1)
	return last_checkpoint_dist + FIRST_CHECKPOINT * int(CHECKPOINT_COEFF ** last_checkpoint)

func increment_checkpoint(checkpoint: int) -> int:
	last_checkpoint += 1
	last_checkpoint_dist = checkpoint 
	return get_next_checkpoint()
