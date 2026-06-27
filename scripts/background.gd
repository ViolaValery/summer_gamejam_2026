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

## Kamera-Höhe beim ersten Frame – dient als Bezugspunkt fürs vertikale
## Verankern am Terrain (siehe _process). So bleibt die im Editor eingestellte
## Höhe der Sprites erhalten; ausgeglichen wird nur die ABWEICHUNG davon.
var _base_camera_y: float
var _has_base := false


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

	# WAAGERECHT: echter Parallax – jede Ebene scrollt mit eigenem Faktor mit,
	# je kleiner desto weiter hinten.
	var x := camera.global_position.x
	$Sky.region_rect.position.x = x * sky_factor
	$Far.region_rect.position.x = x * far_factor
	$Near.region_rect.position.x = x * near_factor

	# SENKRECHT: NICHT an der Kamera, sondern an der Welt (Terrain) verankern.
	# Wir verschieben die ganze Ebene vertikal gegengleich zur Kamera-Höhe,
	# damit die Skyline auf konstanter Welt-Höhe sitzt (statt am Bildschirm zu
	# kleben). Alle drei Ebenen bewegen sich dabei gleich -> keine vertikale
	# Parallax-Variation, der Hintergrund "wackelt" beim Steigen/Fallen nicht.
	# Bezug ist die Start-Höhe der Kamera, damit die im Editor eingestellten
	# Sprite-Höhen unverändert bleiben.
	if not _has_base:
		_base_camera_y = camera.global_position.y
		_has_base = true
	offset.y = _base_camera_y - camera.global_position.y
