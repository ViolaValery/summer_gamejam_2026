extends AnimatedSprite2D
## SIEGES-FLAGGE fürs Game-Loop-Finale.
##
## Alles Visuelle steckt in der Szene/Ressource (im Editor bearbeitbar):
##   - die Frames + die beiden Animationen "spring" (einmal) und "wave"
##     (Schleife) in flagge_frames.tres
##   - Größe (scale), Boden-Anker (offset) und autoplay = "spring" am Knoten
##
## Hier bleibt nur die Logik, die man nicht visuell setzen kann: nach dem
## einmaligen "spring" automatisch ins endlose "wave" wechseln.

func _ready() -> void:
	animation_finished.connect(_on_animation_finished)


func _on_animation_finished() -> void:
	if animation == "spring":
		play("wave")
