extends AnimatedSprite2D
## SIEGES-FLAGGE fürs Game-Loop-Finale: wächst aus dem Boden ("spriest") und
## weht dann endlos. Baut ihre SpriteFrames aus der PNG-Sequenz selbst auf.
##
## Zwei Animationen:
##   "spring" – alle Frames einmal (Mast wächst raus, Flagge entfaltet sich)
##   "wave"   – nur die letzten Frames, in Schleife (das Wehen)
## Nach "spring" wird automatisch auf "wave" umgeschaltet.

const DIR := "res://assets/flagge/"
const FRAME_COUNT := 37
const WAVE_FROM := 26          # letzte 11 Frames (26..36) = Wehen-Schleife

@export var fps := 18.0
@export var flag_scale := 0.55


func _ready() -> void:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	sf.add_animation("spring")
	sf.set_animation_loop("spring", false)
	sf.set_animation_speed("spring", fps)
	sf.add_animation("wave")
	sf.set_animation_loop("wave", true)
	sf.set_animation_speed("wave", fps)

	var first: Texture2D = null
	for i in FRAME_COUNT:
		var tex: Texture2D = load(DIR + "frame_%02d.png" % i)
		if first == null:
			first = tex
		sf.add_frame("spring", tex)
		if i >= WAVE_FROM:
			sf.add_frame("wave", tex)
	sprite_frames = sf

	# Mast-Fuß (unten-Mitte) sitzt im Knoten-Ursprung -> Flagge "steckt" im Boden.
	centered = false
	var sz := first.get_size()
	offset = Vector2(-sz.x / 2.0, -sz.y)
	scale = Vector2(flag_scale, flag_scale)

	animation_finished.connect(_on_anim_finished)
	play("spring")


func _on_anim_finished() -> void:
	if animation == "spring":
		play("wave")          # ins endlose Wehen übergehen
