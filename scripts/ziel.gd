extends Area2D
## ZIEL (RWTH-Fristenkasten): das Spielende. Frei im Level/Terrain platzierbar.
## Sobald das Gefährt hindurchfährt, ist das Spiel geschafft -> Signal "reached".

signal reached

var _done := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if _done:
		return
	# Nur das Gefährt zählt (RigidBody2D); Terrain (StaticBody) ignorieren.
	if not (body is RigidBody2D):
		return
	_done = true
	reached.emit()
