extends Area2D
## Streuselbrötchen zum Aufsammeln.
##
## Berührt das Gefährt (irgendein RigidBody2D-Teil) das Brötchen, gibt es
## +1 Guthaben und das Brötchen verschwindet.

func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if body is RigidBody2D:        # nur das Gefährt sammelt, nicht der Boden
		GameState.streusel += 1
		queue_free()
