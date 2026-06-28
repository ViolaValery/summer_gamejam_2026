extends Resource
class_name ProgressionConfig
## Die SPIEL-PROGRESSION als Daten – im Level-Editor bearbeitbar, vom Spiel
## gelesen. So kann das Team Budget, Checkpoint-Abstände und Item-Freischaltung
## balancen, ohne Code anzufassen.
##
## levels[i] beschreibt den i-ten Checkpoint/Level:
##   { "distance": int, "budget": int, "items": Array[String] }
##   - distance: kumulierte Score-Schwelle, ab der Checkpoint i erreicht ist
##               (Level 0 = 0).
##   - budget:   verfügbares Geld auf diesem Level.
##   - items:    IDs der im Shop verfügbaren Items auf diesem Level (kumulativ).

@export var levels: Array = []


func count() -> int:
	return levels.size()


func _clamp(idx: int) -> int:
	return clampi(idx, 0, maxi(0, levels.size() - 1))


# Kumulierte Distanz von Checkpoint idx (über das Ende hinaus extrapoliert).
func distance_at(idx: int) -> int:
	if levels.is_empty():
		return 0
	if idx < levels.size():
		return int(levels[idx].get("distance", 0))
	var last := int(levels[-1].get("distance", 0))
	var gap := 200
	if levels.size() >= 2:
		gap = last - int(levels[-2].get("distance", 0))
	return last + maxi(1, gap) * (idx - levels.size() + 1)


func budget_at(idx: int) -> int:
	if levels.is_empty():
		return 0
	return int(levels[_clamp(idx)].get("budget", 0))


func items_at(idx: int) -> Array:
	if levels.is_empty():
		return []
	return levels[_clamp(idx)].get("items", [])


# Erster Level-Index, auf dem das Item verfügbar ist (oder -1).
func unlock_level_of(id: String) -> int:
	for i in levels.size():
		if id in (levels[i].get("items", []) as Array):
			return i
	return -1
