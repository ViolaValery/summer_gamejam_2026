extends Node2D
## Minimalistischer Garage-Prototyp: Teile aus der Palette per Drag & Drop
## an die Basis snappen und kombinieren.
##
## Beim Ziehen wird optisch angezeigt:
##   - ein Reichweiten-Kreis um das Teil (so weit kann es snappen)
##   - ein grüner Faden zum Körper, an den es sich verbinden würde

const PART_SCENES := {
	"Rakete": preload("res://garage_prototype/parts/rocket_boost.tscn"),
	"Reifen": preload("res://garage_prototype/parts/wheel.tscn"),
	"Helium-Ballon": preload("res://garage_prototype/parts/balloon.tscn"),
}
const BASE_SCENE := preload("res://garage_prototype/parts/base.tscn")

## Snap-Reichweite in Pixeln (näher dran -> verbindet sich).
const SNAP_DISTANCE := 100.0

@onready var parts_root: Node2D = $Parts
@onready var base: RigidBody2D = $Parts/Base
@onready var palette: Node2D = $Palette
@onready var editor = $UI/PartEditor

# Zustand "ziehen".
var dragging: RigidBody2D = null
var drag_kind: String = ""
var drag_home: Vector2 = Vector2.ZERO
var drag_from_palette: bool = false
var preview_target: RigidBody2D = null  # Körper, an den gerade gesnappt würde


func _ready() -> void:
	editor.world = self
	for p in palette.get_children():
		if p is RigidBody2D:
			p.add_to_group("draggable")


func _process(_delta: float) -> void:
	if dragging != null:
		dragging.global_position = get_global_mouse_position()
		_update_preview()
		queue_redraw()  # Vorschau jeden Frame neu zeichnen


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var d := _draggable_at(get_global_mouse_position())
			if d != null:
				_start_drag(d)
		elif dragging != null:
			_drop_drag()


# ---------------------------------------------------------------------------
#  Drag & Drop
# ---------------------------------------------------------------------------

func _start_drag(part: RigidBody2D) -> void:
	dragging = part
	part.freeze = true
	part.collision_layer = 0
	part.collision_mask = 0
	part.remove_from_group("draggable")
	drag_from_palette = part.get_parent() == palette
	if drag_from_palette:
		drag_kind = part.get_meta("kind", "")
		drag_home = part.global_position


func _drop_drag() -> void:
	var part := dragging
	dragging = null
	preview_target = null
	queue_redraw()  # Vorschau entfernen

	var near_base: bool = base != null and is_instance_valid(base) \
		and base.global_position.distance_to(part.global_position) <= SNAP_DISTANCE
	var rigid: bool = bool(part.get_meta("rigid", false))

	# Starres Teil (z.B. Rakete) nah an der Basis -> VERSCHMELZEN.
	if near_base and rigid:
		_merge_into_base(part)
		if drag_from_palette:
			_refill_palette(drag_kind, drag_home)
		return

	# Sonst: normales Teil mit losem Gelenk, oder frei fallen lassen.
	if part.get_parent() != parts_root:
		part.reparent(parts_root)
	part.collision_layer = 1
	part.collision_mask = 1
	part.freeze = false

	if near_base:
		attach(part, base)          # loses Gelenk an die Basis
	else:
		part.add_to_group("draggable")  # frei -> kann erneut gegriffen werden

	if drag_from_palette:
		_refill_palette(drag_kind, drag_home)


## Verschmilzt ein Teil fest mit der Basis: seine Form + Optik werden Kinder
## der Basis (Weltposition bleibt exakt erhalten) -> ein einziger starrer Körper,
## ohne Gelenk, ohne Versatz, ohne Wackeln.
func _merge_into_base(part: RigidBody2D) -> void:
	# Form (Kollision) und Optik in die Basis übernehmen.
	var movers: Array = []
	for child in part.get_children():
		if child is CollisionShape2D or child is Polygon2D:
			movers.append(child)
	for child in movers:
		child.reparent(base)  # behält die Weltposition bei

	# Masse der Basis um die des Teils erhöhen (Schwerpunkt rechnet Godot selbst nach).
	base.mass += part.mass

	# Die Rakete selbst bleibt als reiner Schub-/Anzeige-Knoten in der Basis hängen.
	part.reparent(base)
	part.freeze = true
	part.collision_layer = 0
	part.collision_mask = 0
	part.remove_from_group("draggable")
	if "host" in part:
		part.set("host", base)  # Schub wirkt ab jetzt auf die Basis


func _refill_palette(kind: String, pos: Vector2) -> void:
	if not PART_SCENES.has(kind):
		return
	var fresh := PART_SCENES[kind].instantiate() as RigidBody2D
	palette.add_child(fresh)
	fresh.global_position = pos
	fresh.freeze = true
	fresh.set_meta("kind", kind)
	fresh.add_to_group("draggable")


# ---------------------------------------------------------------------------
#  Verbindungs-Vorschau
# ---------------------------------------------------------------------------

func _update_preview() -> void:
	# Ziel ist immer nur die Basis.
	if base != null and is_instance_valid(base) \
			and base.global_position.distance_to(dragging.global_position) <= SNAP_DISTANCE:
		preview_target = base
	else:
		preview_target = null


# Wird automatisch gezeichnet (queue_redraw stößt es an).
func _draw() -> void:
	if dragging == null:
		return
	var p := dragging.global_position
	# Reichweite (heller Kreis)
	draw_arc(p, SNAP_DISTANCE, 0.0, TAU, 48, Color(1, 1, 1, 0.25), 2.0)
	# Verbindungs-Vorschau (grüner Faden + Punkt am künftigen Gelenk)
	if preview_target != null:
		var t := preview_target.global_position
		draw_line(p, t, Color(0.3, 1.0, 0.4), 3.0)
		draw_circle((p + t) / 2.0, 6.0, Color(0.3, 1.0, 0.4))


# ---------------------------------------------------------------------------
#  Hilfsfunktionen
# ---------------------------------------------------------------------------

## Loses Gelenk (Scharnier) zwischen zwei Körpern (für Ballon, Reifen).
func attach(a: RigidBody2D, b: RigidBody2D) -> void:
	var joint := PinJoint2D.new()
	parts_root.add_child(joint)
	joint.global_position = (a.global_position + b.global_position) / 2.0
	joint.node_a = a.get_path()
	joint.node_b = b.get_path()


func _draggable_at(point: Vector2) -> RigidBody2D:
	for p in get_tree().get_nodes_in_group("draggable"):
		if _point_in_body(p, point):
			return p as RigidBody2D
	return null


func _point_in_body(body: Node2D, point: Vector2) -> bool:
	var col := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col == null:
		return false
	var local := point - body.global_position
	var shape := col.shape
	if shape is CircleShape2D:
		return local.length() <= (shape as CircleShape2D).radius
	if shape is RectangleShape2D:
		var half := (shape as RectangleShape2D).size / 2.0
		return absf(local.x) <= half.x and absf(local.y) <= half.y
	return false


## Alles Angebaute löschen und die Basis frisch neu erzeugen.
func clear_parts() -> void:
	for child in parts_root.get_children():
		child.queue_free()
	await get_tree().process_frame
	base = BASE_SCENE.instantiate() as RigidBody2D
	base.position = Vector2(576, 150)
	parts_root.add_child(base)
