extends RigidBody2D
## FIGUR (Ragdoll-Passagier) – ein Spezial-Attachment.
##
## Die Wurzel dieses Knotens IST die klebrige rechte Hand. Übers normale
## Bau-System (sticky_percent = 100, attach = "pin") wird genau diese Hand ans
## Fahrzeug "angestickt" – ohne Berührung lässt sie sich nicht platzieren, man
## kann also nicht ohne festgehaltene Hand losfahren.
##
## In der WERKSTATT zeigt nur ein Vorschau-Sprite die ganze Figur (folgt der
## Hand, keine Physik). Sobald das Fahrzeug LOSFÄHRT (die Hand wird entfroren),
## baut _wake() zur Laufzeit die 14 Körperteile als lose über PinJoint2D
## verbundene RigidBody2D auf -> die Figur baumelt und zappelt lustig mit.

## Gesamtgröße der Figur (1.0 = Originalgröße der Zeichnung, ~636 px hoch).
@export var fig_scale := 0.25
## Masse je Körperteil (klein halten, sonst kippt es das Fahrzeug).
@export var part_mass := 0.1
## Dämpfung -> "lose mit etwas Dämpfung": zappelt, aber nicht völlig chaotisch.
@export var ang_damp := 3.0
@export var lin_damp := 0.4

const ASSET := "res://assets/figur/"
const HAND := "hand_rechts"      # die Wurzel/Halte-Hand
## Das Terrain liegt (zusätzlich) auf dieser Kollisions-Ebene. Die Figur
## maskiert NUR diese -> sie ruht auf dem Boden, schiebt aber das Fahrzeug
## nicht und kollidiert nicht mit sich selbst. (Muss zu terrain.tscn passen:
## dort collision_layer = 9 = Ebene 1 + Ebene 4.)
const GROUND_LAYER := 8          # Ebene 4

# --- aus der Zeichnung extrahierte Skelett-Daten (Canvas-Pixel, 1024er Raum) --
const HAND_IN_PREVIEW := Vector2(442, 168)   # Hand-Mittelpunkt im Vorschaubild
const PARTS := {
	"oberschenkel_links": {"center": Vector2(398.5, 590), "size": Vector2(79, 122)},
	"unterschenkel_links": {"center": Vector2(375.5, 705.5), "size": Vector2(45, 147)},
	"fuss_links": {"center": Vector2(368.5, 787.5), "size": Vector2(99, 51)},
	"oberarm_links": {"center": Vector2(355.5, 441), "size": Vector2(117, 84)},
	"unterarm_links": {"center": Vector2(299, 521), "size": Vector2(50, 118)},
	"hand_links": {"center": Vector2(286, 588), "size": Vector2(46, 36)},
	"oberschenkel_rechts": {"center": Vector2(472.5, 581.5), "size": Vector2(65, 117)},
	"unterschenkel_rechts": {"center": Vector2(515, 691), "size": Vector2(58, 136)},
	"fuss_rechts": {"center": Vector2(545, 763), "size": Vector2(96, 60)},
	"oberarm_rechts": {"center": Vector2(510, 393), "size": Vector2(110, 54)},
	"unterarm_rechts": {"center": Vector2(600, 372), "size": Vector2(106, 38)},
	"hand_rechts": {"center": Vector2(705, 345), "size": Vector2(120, 80)},
	"body": {"center": Vector2(437.5, 453.5), "size": Vector2(73, 179)},
	"kopf": {"center": Vector2(442, 278), "size": Vector2(166, 202)},
}
# Gelenke: [teil_a, teil_b, pin_pos (Canvas)] – Pin sitzt mittig zwischen beiden.
const BONES := [
	["body", "kopf", Vector2(439.75, 365.75)],
	["body", "oberarm_links", Vector2(396.5, 447.25)],
	["oberarm_links", "unterarm_links", Vector2(327.25, 481)],
	["unterarm_links", "hand_links", Vector2(292.5, 554.5)],
	["body", "oberarm_rechts", Vector2(473.75, 423.25)],
	["oberarm_rechts", "unterarm_rechts", Vector2(555, 382.5)],
	["unterarm_rechts", "hand_rechts", Vector2(652.5, 358.5)],
	["body", "oberschenkel_links", Vector2(418, 521.75)],
	["oberschenkel_links", "unterschenkel_links", Vector2(387, 647.75)],
	["unterschenkel_links", "fuss_links", Vector2(372, 746.5)],
	["body", "oberschenkel_rechts", Vector2(455, 517.5)],
	["oberschenkel_rechts", "unterschenkel_rechts", Vector2(493.75, 636.25)],
	["unterschenkel_rechts", "fuss_rechts", Vector2(530, 727)],
]

var _alive := false
@onready var _hand_center: Vector2 = PARTS[HAND]["center"]


func _ready() -> void:
	_build_preview()


# Werkstatt-Vorschau: ganze Figur, Hand sitzt im Knoten-Ursprung (= Andockpunkt).
func _build_preview() -> void:
	if has_node("Preview"):
		return
	var s := Sprite2D.new()
	s.name = "Preview"
	s.texture = load(ASSET + "figur_preview.png")
	s.centered = false
	s.offset = -HAND_IN_PREVIEW       # Hand-Pixel landet im Knoten-Ursprung
	s.scale = Vector2(fig_scale, fig_scale)
	s.z_index = 1
	add_child(s)


# Lässt die Hand kräftig leuchten/pulsieren und zeigt einen blinkenden Pfeil
# Richtung Fahrzeug – Hinweis: "muss erst ans Fahrzeug angesteckt werden!".
# target_global = Weltposition des Fahrzeugs (für die Pfeilrichtung); optional.
func flash_hand(target_global = null, cycles: int = 8) -> void:
	var old := get_node_or_null("Attention")
	if old:
		old.free()
	var att := Node2D.new()
	att.name = "Attention"
	att.z_index = 5
	add_child(att)

	var s := Vector2(fig_scale, fig_scale)

	# 1) Weicher gelber Schein (Halo) hinter der Hand.
	var halo := Polygon2D.new()
	halo.polygon = _circle_points(46.0, 28)
	halo.color = Color(1.0, 0.9, 0.2, 0.0)
	att.add_child(halo)

	# 2) Die Hand selbst leuchtet hell auf.
	var hl := Sprite2D.new()
	hl.texture = load(ASSET + HAND + ".png")
	hl.centered = true
	hl.scale = s
	hl.modulate = Color(1, 1, 0.7, 0.0)
	att.add_child(hl)

	# 3) Pfeil, der vom Hand-Bereich Richtung Fahrzeug zeigt.
	var ldir := Vector2.RIGHT
	if target_global != null:
		var lv: Vector2 = to_local(target_global)
		if lv.length() > 1.0:
			ldir = lv.normalized()
	var arrow := Polygon2D.new()
	arrow.polygon = PackedVector2Array([
		Vector2(0, -8), Vector2(48, -8), Vector2(48, -20),
		Vector2(82, 0), Vector2(48, 20), Vector2(48, 8), Vector2(0, 8)])
	arrow.color = Color(1.0, 0.8, 0.05, 1.0)
	arrow.rotation = ldir.angle()
	arrow.position = ldir * 46.0
	att.add_child(arrow)

	# Animation: kräftiges Pulsieren; der Pfeil "wandert" Richtung Fahrzeug.
	var near := ldir * 46.0
	var far := ldir * 78.0
	var tw := create_tween().set_loops(cycles)
	# aufleuchten
	tw.tween_property(halo, "modulate:a", 0.7, 0.16)
	tw.parallel().tween_property(hl, "modulate", Color(1, 1, 0.8, 1.0), 0.16)
	tw.parallel().tween_property(hl, "scale", s * 1.7, 0.16)
	tw.parallel().tween_property(arrow, "position", far, 0.16)
	tw.parallel().tween_property(arrow, "modulate:a", 1.0, 0.16)
	# abklingen
	tw.tween_property(halo, "modulate:a", 0.0, 0.22)
	tw.parallel().tween_property(hl, "modulate", Color(1, 1, 0.8, 0.15), 0.22)
	tw.parallel().tween_property(hl, "scale", s, 0.22)
	tw.parallel().tween_property(arrow, "position", near, 0.22)
	tw.parallel().tween_property(arrow, "modulate:a", 0.25, 0.22)
	tw.chain().tween_callback(att.queue_free)


# Punkte eines Kreises (für den Halo-Schein).
func _circle_points(radius: float, segments: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments:
		var a := TAU * i / float(segments)
		pts.append(Vector2(cos(a), sin(a)) * radius)
	return pts


# Wird aktiv, sobald das Fahrzeug die Hand entfriert (= Spiel startet).
func _physics_process(_delta: float) -> void:
	if not _alive and not freeze:
		_wake()


# Canvas-Punkt -> Weltposition (berücksichtigt Lage/Drehung der Hand-Wurzel).
func _world_of(canvas: Vector2) -> Vector2:
	return to_global((canvas - _hand_center) * fig_scale)


func _wake() -> void:
	_alive = true
	var prev := get_node_or_null("Preview")
	if prev:
		prev.queue_free()

	# Kollidiert nur mit dem Terrain (Boden) – nicht mit Fahrzeug oder sich
	# selbst. layer = 0: niemand "sieht" die Figur; mask = Boden: die Figur
	# ruht auf dem Boden statt durchzufallen.
	collision_layer = 0
	collision_mask = GROUND_LAYER
	mass = part_mass
	angular_damp = ang_damp
	linear_damp = lin_damp
	_add_sprite(self, HAND)          # die Hand-Wurzel bekommt ihr Bild

	# Container für die übrigen Teile + Gelenke (neben der Hand, am Fahrzeug).
	var rag := Node2D.new()
	rag.name = "Ragdoll"
	get_parent().add_child(rag)

	var bodies := {HAND: self}
	for kind in PARTS:
		if kind == HAND:
			continue
		bodies[kind] = _make_part(rag, kind)

	for bone in BONES:
		_make_joint(rag, bodies[bone[0]], bodies[bone[1]], bone[2])


func _make_part(rag: Node2D, kind: String) -> RigidBody2D:
	var info: Dictionary = PARTS[kind]
	var rb := RigidBody2D.new()
	rb.name = kind
	rag.add_child(rb)
	rb.global_position = _world_of(info["center"])
	rb.global_rotation = global_rotation
	rb.mass = part_mass
	rb.angular_damp = ang_damp
	rb.linear_damp = lin_damp
	rb.collision_layer = 0
	rb.collision_mask = GROUND_LAYER
	_add_sprite(rb, kind)
	# Form = Kollisionskörper gegen den Boden (und Trägheit).
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = info["size"] * fig_scale
	col.shape = shape
	rb.add_child(col)
	return rb


func _add_sprite(host: Node2D, kind: String) -> void:
	var s := Sprite2D.new()
	s.name = "Bild"
	s.texture = load(ASSET + kind + ".png")
	s.centered = true                # Bild-Mitte = Teil-Mittelpunkt = Knoten 0
	s.scale = Vector2(fig_scale, fig_scale)
	host.add_child(s)


func _make_joint(rag: Node2D, a: RigidBody2D, b: RigidBody2D, canvas_pos: Vector2) -> void:
	var j := PinJoint2D.new()
	rag.add_child(j)
	j.global_position = _world_of(canvas_pos)
	j.node_a = a.get_path()
	j.node_b = b.get_path()
	j.disable_collision = true
	j.softness = 0.0
