extends Node2D
## WERKSTATT (Editor-Szene): Gefährt zusammenbauen.
##
## Bauen:   Teil aus der Palette (rechts) aufs Fahrwerk ziehen.
##          Grüne Umrandung = es berührt das Fahrwerk und dockt an.
##          Ohne Berührung loslassen = verwerfen.
## Spielen: übergibt das gebaute Gefährt an die Spielszene (level.tscn).
## Reset:   Werkstatt neu aufbauen.
##
## Hier wird NUR gebaut (alles eingefroren). Zusammenbauen + Fahren passiert
## in der Spielszene.

## Alle baubaren Teile (Name -> Szene).
const PARTS := {
	"Reifen": {
		"scene": preload("res://scenes/attachments/wheel.tscn"),
		"available_from_level": 0,
		"price": 500
		},
	"Booster": {
		"scene": preload("res://scenes/attachments/booster.tscn"),
		"available_from_level": 5,
		"price": 1000
		},
	"Ballon": {
		"scene": preload("res://scenes/attachments/balloon.tscn"),
		"available_from_level": 3,
		"price": 750
		},
	"Platform": {
		"scene": preload("res://scenes/platforms/platform.tscn"),
		"available_from_level": 6,
		"price": 1000
		},
}

const PRICE_LABEL := preload("res://scenes/attachments/price_tag.tscn")

@onready var vehicle: Node2D = $Vehicle
@onready var chassis: RigidBody2D = $Vehicle/Chassis
@onready var palette: Node2D = $Palette
@onready var budget_label: Label = $UI/HUD/Budget/Value
@onready var level_label: Label = $UI/HUD/Level/Value

## Drehschritt pro Mausrad-Tick (~15°).
const ROT_STEP := 0.2618

## Standard-Sticky-Anteil in % (falls ein Teil kein metadata/sticky_percent hat).
const DEFAULT_STICKY := 35.0

var dragging: RigidBody2D = null
var drag_kind := ""
var drag_home := Vector2.ZERO
var can_attach := false    # darf das gezogene Teil gerade platziert werden?
var core_blocked := false  # überlappt der No-Overlap-Kern gerade einen anderen?

# Beim Verschieben eines schon platzierten Teils: Rückfall-Lage, falls ungültig.
var drag_is_move := false
var drag_return_pos := Vector2.ZERO
var drag_return_rot := 0.0

# Zeichen-Ebene, die ÜBER allem liegt (sonst verdecken Teile/Boden die Zonen).
var overlay: Node2D

func _update_budget_label() -> void:
	budget_label.text = str(GameState.budget) + "$"

func _ready() -> void:
	GameState.set_budget()
	GameState.build_into(vehicle)  # gespeicherten Bau wiederherstellen
	_update_budget_label()
	level_label.text = str(GameState.last_checkpoint + 1) # +1 because initial "last" checkpoint is 0 

	_freeze_all()       # in der Werkstatt bewegt sich nichts
	_build_palette()
	_update_palette()
	# Overlay zuletzt hinzufügen + hoher z_index -> zeichnet über allem.
	overlay = Node2D.new()
	overlay.z_index = 1000
	overlay.draw.connect(_draw_zones)
	add_child(overlay)
	# Die HUD-Knöpfe liegen in der Szene (UI/HUD) – hier nur mit Logik verbinden.
	$UI/HUD/Panel/VBox/Spielen.pressed.connect(_play)
	$UI/HUD/Panel/VBox/Reset.pressed.connect(_to_reset)


# --- Palette --------------------------------------------------------------

func _build_palette() -> void:
	var pos := Vector2(750, 110)
	for kind in PARTS:
		_spawn_palette_item(kind, pos)
		pos.y += 130.0


func _spawn_palette_item(kind: String, pos: Vector2) -> void:
	var item := (PARTS[kind]["scene"] as PackedScene).instantiate() as RigidBody2D
	palette.add_child(item)
	item.global_position = pos
	item.freeze = true
	item.set_meta("kind", kind)
	item.set_meta("home", pos)
	item.set_meta("available", true)
	item.add_to_group("palette_item")
	
	_spawn_item_price_label(kind, Vector2(pos.x + 100, pos.y - 20))

func _spawn_item_price_label(kind: String, pos: Vector2) -> void:
	var price := PARTS[kind]["price"] as int
	var label := (PRICE_LABEL as PackedScene).instantiate() as Label
	palette.add_child(label)
	label.text = str(price) + "$"
	label.global_position = pos
	label.set_meta("kind", kind)
	label.add_to_group("palette_item_label")

# check each item's availability, etc.
func _update_palette() -> void:
	for label in get_tree().get_nodes_in_group("palette_item_label"):
		var kind := label.get_meta("kind") as String
		var item := _get_item_by_meta("palette_item", "kind", kind)
		var price := PARTS[kind]["price"] as int
		var level_needed := PARTS[kind]["available_from_level"] as int
		if level_needed > GameState.last_checkpoint:
			item.set_meta("available", false)
			label.text = "Level " + str(level_needed)
			continue
		else:
			label.text = str(price) + "$"
		var color = label.modulate
		if price > GameState.budget:
			color.a = 0.3
			item.set_meta("available", false)
		else:
			color.a = 1
			item.set_meta("available", true)
		label.modulate = color

# --- Bauen (Drag & Drop) ---------------------------------------------------

func _process(_delta: float) -> void:
	if dragging != null:
		dragging.global_position = get_global_mouse_position()
		core_blocked = _core_overlaps_any(dragging)
		can_attach = _touches_vehicle(dragging) and not core_blocked
		overlay.queue_redraw()


func _input(event: InputEvent) -> void:
	# Mausrad dreht das gerade gezogene Teil.
	if dragging != null and event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			dragging.rotation += ROT_STEP
			overlay.queue_redraw()
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			dragging.rotation -= ROT_STEP
			overlay.queue_redraw()
			return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_try_grab(get_global_mouse_position())
		elif dragging != null:
			_drop()

	# Rechte Maustaste entfernt ein platziertes Teil.
	if dragging == null and event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var placed := _attachment_at(get_global_mouse_position())
		if placed != null:
			vehicle.remove_child(placed)   # sofort raus (queue_free wäre verzögert)
			placed.queue_free()
			GameState.save_from(vehicle)   # Bauplan ohne das Teil neu schreiben


# Greift, was unter dem Mauszeiger liegt: ein Palette-Teil (neu anbauen) ODER
# ein schon platziertes Teil (zum Verschieben/Drehen).
func _try_grab(point: Vector2) -> void:
	var item := _palette_item_at(point)
	if item != null && item.get_meta("available"):
		dragging = item
		drag_is_move = false
		drag_kind = item.get_meta("kind", "")
		drag_home = item.get_meta("home", item.global_position)
		item.remove_from_group("palette_item")
		_spawn_palette_item(drag_kind, drag_home)  # Palettenplatz nachfüllen
		return

	var placed := _attachment_at(point)
	if placed != null:
		dragging = placed
		drag_is_move = true
		drag_kind = placed.get_meta("kind", "")
		drag_return_pos = placed.position   # zum Zurücklegen, falls ungültig
		drag_return_rot = placed.rotation
		placed.reparent(palette)            # während des Ziehens "in der Hand"


func _drop() -> void:
	var part := dragging
	dragging = null
	can_attach = false
	overlay.queue_redraw()
	var price := PARTS[drag_kind]["price"] as int
	if _can_place(part):
		part.reparent(vehicle)  # ans Gefährt anbauen (Position bleibt)
		part.freeze = true      # bleibt liegen bis "Spielen"
		GameState.budget -= price
		_update_budget_label()
		_update_palette()
	elif drag_is_move:
		# Verschobenes Teil ungültig abgelegt -> zurück an die alte Stelle.
		part.reparent(vehicle)
		part.position = drag_return_pos
		part.rotation = drag_return_rot
		part.freeze = true
	else:
		part.queue_free()       # neues Teil daneben -> verwerfen
	GameState.save_from(vehicle)  # Bauplan aktualisieren (auch nach Verschieben)


# Darf das Teil hier angebaut werden? Zwei Bedingungen:
#  1. Sticky: seine Form muss ein Körperteil (Fahrwerk/Plattform) berühren.
#  2. No-Overlap: sein Kern darf KEINEN anderen Kern überlappen – weder den
#     eines Attachments noch den einer Base (Fahrwerk/Plattform).
func _can_place(part: RigidBody2D) -> bool:
	return _touches_vehicle(part) and not _core_overlaps_any(part)


# Ein "Körperteil" = das Fahrwerk oder eine angebaute Plattform. Nur daran
# kann man andocken – nie an einem reinen Attachment (Reifen/Booster/Ballon).
func _is_body(node: Object) -> bool:
	return node == chassis or (node is Node and (node as Node).get_meta("platform", false))


# Berührt die Form des Teils ein Körperteil (Fahrwerk oder Plattform)?
# Echte Physik-Abfrage – funktioniert für Kreise, Rechtecke, gedreht, egal.
func _touches_vehicle(part: RigidBody2D) -> bool:
	var shape := part.get_node("CollisionShape2D") as CollisionShape2D

	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape.shape
	query.transform = shape.global_transform
	query.exclude = [part.get_rid()]  # das Teil selbst nicht mitzählen

	var space := get_world_2d().direct_space_state
	for hit in space.intersect_shape(query, 16):
		if _is_body(hit.collider):
			return true
	return false


# Überlappt der KERN des Teils den KERN IRGENDEINES anderen Teils?
# Geprüft wird gegen ALLE Teile – Attachments UND Körperteile (Fahrwerk,
# Plattformen). Man kann also weder in den Kern eines Attachments noch in den
# Kern einer Base bauen. Das Andocken passiert auf dem Sticky-Rand drumherum.
func _core_overlaps_any(part: RigidBody2D) -> bool:
	var a := _core(part)
	if not _has_core(a.shape):
		return false  # Teil ist komplett Sticky -> blockiert nie
	for other in vehicle.get_children():
		if other == part or not (other is RigidBody2D):
			continue
		var b := _core(other)
		if _has_core(b.shape) and a.shape.collide(a.xform, b.shape, b.xform):
			return true
	return false


# Der No-Overlap-KERN eines Teils: seine Form nach innen um die Sticky-Randbreite
# geschrumpft, samt Weltlage. Funktioniert für Kreise UND (gedrehte) Rechtecke.
# Rückgabe: { shape = Shape2D, xform = Transform2D }.
func _core(part: RigidBody2D) -> Dictionary:
	var col := part.get_node("CollisionShape2D") as CollisionShape2D
	var band := _band(part)
	var core_shape: Shape2D
	if col.shape is CircleShape2D:
		var c := CircleShape2D.new()
		c.radius = maxf(0.0, (col.shape as CircleShape2D).radius - band)
		core_shape = c
	elif col.shape is RectangleShape2D:
		var s := (col.shape as RectangleShape2D).size
		var r := RectangleShape2D.new()
		r.size = Vector2(maxf(0.0, s.x - 2.0 * band), maxf(0.0, s.y - 2.0 * band))
		core_shape = r
	else:
		core_shape = col.shape
	return { "shape": core_shape, "xform": col.global_transform }


# Breite des Sticky-Randes in Pixeln = sticky_percent % der halben kurzen Seite.
# Pro Teil über metadata/sticky_percent (0–100) einstellbar:
#    0 %  -> Kern = ganze Form (kein Sticky-Rand)
#   50 %  -> halbe Tiefe ist Sticky
#  100 %  -> alles Sticky (kein Kern, keine No-Overlap-Zone)
func _band(part: RigidBody2D) -> float:
	var shape := (part.get_node("CollisionShape2D") as CollisionShape2D).shape
	var percent: float = clampf(part.get_meta("sticky_percent", DEFAULT_STICKY), 0.0, 100.0)
	return _min_half_extent(shape) * percent / 100.0


# Halbe kurze Ausdehnung (Kreis: Radius; Rechteck: halbe kürzere Seite).
func _min_half_extent(shape: Shape2D) -> float:
	if shape is CircleShape2D:
		return (shape as CircleShape2D).radius
	if shape is RectangleShape2D:
		var s := (shape as RectangleShape2D).size
		return minf(s.x, s.y) / 2.0
	return 1.0


# Hat das Teil noch einen Kern, oder ist es komplett Sticky (kein No-Overlap)?
func _has_core(shape: Shape2D) -> bool:
	if shape is CircleShape2D:
		return (shape as CircleShape2D).radius > 0.5
	if shape is RectangleShape2D:
		var s := (shape as RectangleShape2D).size
		return s.x > 0.5 and s.y > 0.5
	return false


func _palette_item_at(point: Vector2) -> RigidBody2D:
	for it in get_tree().get_nodes_in_group("palette_item"):
		if _point_in_body(it, point):
			return it as RigidBody2D
	return null

func _get_item_by_meta(group_name: String, meta_key: String, value) -> Node:
	for item in get_tree().get_nodes_in_group(group_name):
		if item.has_meta(meta_key) and item.get_meta(meta_key) == value:
			return item
	return null


# Schon platziertes Teil (Attachment oder Plattform) unter dem Punkt.
func _attachment_at(point: Vector2) -> RigidBody2D:
	for child in vehicle.get_children():
		if child is RigidBody2D and child != chassis and _point_in_body(child, point):
			return child as RigidBody2D
	return null


func _point_in_body(body: Node2D, point: Vector2) -> bool:
	var col := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col == null:
		return false
	var local := body.to_local(point)  # berücksichtigt auch die Drehung des Teils
	var shape := col.shape
	if shape is CircleShape2D:
		return local.length() <= (shape as CircleShape2D).radius
	if shape is RectangleShape2D:
		var half := (shape as RectangleShape2D).size / 2.0
		return absf(local.x) <= half.x and absf(local.y) <= half.y
	return false


# Zeichnet auf dem Overlay (über allem) die beiden Zonen des gezogenen Teils:
#   Außenform getönt = Sticky-Area (weiß = in der Hand, grün = darf andocken).
#   Innenform rot    = No-Overlap-Kern (kräftiger, wenn er gerade überlappt).
func _draw_zones() -> void:
	if dragging == null:
		return
	var col := dragging.get_node("CollisionShape2D") as CollisionShape2D
	var outer := _shape_outline(col.shape, col.global_transform)
	if outer.size() >= 3:
		var sticky_col := Color(0.3, 1.0, 0.4, 0.5) if can_attach else Color(1.0, 1.0, 1.0, 0.3)
		overlay.draw_colored_polygon(outer, sticky_col)

	var core := _core(dragging)
	if _has_core(core.shape):
		var inner := _shape_outline(core.shape, core.xform)
		if inner.size() >= 3:
			var alpha := 0.6 if core_blocked else 0.35
			overlay.draw_colored_polygon(inner, Color(0.95, 0.25, 0.2, alpha))


# Umriss-Punkte einer Form in Weltkoordinaten (zum Zeichnen).
func _shape_outline(shape: Shape2D, xform: Transform2D) -> PackedVector2Array:
	var pts := PackedVector2Array()
	if shape is CircleShape2D:
		var r := (shape as CircleShape2D).radius
		for i in 24:
			var ang := TAU * i / 24.0
			pts.append(xform * (Vector2(cos(ang), sin(ang)) * r))
	elif shape is RectangleShape2D:
		var h := (shape as RectangleShape2D).size / 2.0
		pts.append(xform * Vector2(-h.x, -h.y))
		pts.append(xform * Vector2(h.x, -h.y))
		pts.append(xform * Vector2(h.x, h.y))
		pts.append(xform * Vector2(-h.x, h.y))
	return pts


# --- Übergabe / Reset ------------------------------------------------------

# Speichert den Bauplan und wechselt in die Spielszene.
func _play() -> void:
	GameState.save_from(vehicle)
	get_tree().change_scene_to_file("res://scenes/level.tscn")


# Friert Fahrwerk und alle angebauten Teile ein.
func _freeze_all() -> void:
	for child in vehicle.get_children():
		if child is RigidBody2D:
			child.freeze = true


# Setzt die Werkstatt auf Anfang: alle Attachments/Plattformen weg, Bauplan leer.
func _to_reset() -> void:
	GameState.blueprint.clear()          # sonst würde der Bau gleich neu geladen
	for child in vehicle.get_children():
		if child is RigidBody2D and child != chassis:
			child.queue_free()
	GameState.set_budget()
	_update_budget_label()
	_update_palette()
