@tool
extends StaticBody2D
## Boden / Strecke.
##
## Die FORM bearbeitest du im Editor am Kind-Knoten "CollisionPolygon2D":
## einfach dessen Punkte mit der Maus ziehen (oder neue hinzufügen).
## Die grüne Fläche "Ground" übernimmt diese Form automatisch –
## dank @tool sogar live im Editor.

func _process(_delta: float) -> void:
	$Ground.polygon = $CollisionPolygon2D.polygon
