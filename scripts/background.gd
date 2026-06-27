extends CanvasLayer
## Parallax-Hintergrund: drei Ebenen, die beim Fahren UNTERSCHIEDLICH schnell
## mitscrollen -> erzeugt Tiefe. Je KLEINER der Faktor, desto weiter hinten.
##
## GRÖSSE & HÖHE stellst du direkt an den Sprites im Editor ein
## (Scale = Größe, Position Y = Höhe der Stadt).
## Die LÄNGE musst du nicht einstellen: _ready macht die Bilder sehr breit und
## sie wiederholen sich endlos -> der Hintergrund hört nie auf.

@export var sky_factor := 0.05
@export var far_factor := 0.25
@export var near_factor := 0.45


func _ready() -> void:
	_widen($Sky)
	_widen($Far)
	_widen($Near)


# Macht ein Bild sehr breit, damit es den Bildschirm deckt und endlos kachelt.
func _widen(sprite: Sprite2D) -> void:
	var r := sprite.region_rect
	r.size.x = 20000.0
	sprite.region_rect = r


func _process(_delta: float) -> void:
	# Die gerade aktive Kamera selbst finden – egal, wo dieser Background hängt.
	# So funktioniert er in jeder Szene (Werkstatt, Level, …) ohne festen Pfad.
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	var x := camera.global_position.x
	$Sky.region_rect.position.x = x * sky_factor
	$Far.region_rect.position.x = x * far_factor
	$Near.region_rect.position.x = x * near_factor
