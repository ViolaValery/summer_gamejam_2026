extends Node2D
## WERKSTATT (Editor-Szene): Gefährt zusammenbauen.
##
## Bauen:   Teil aus der Palette (rechts) aufs Fahrwerk ziehen.
##          Grüne Umrandung = es berührt das Fahrwerk und dockt an.
##          Ohne Berührung loslassen = verwerfen.
## Spielen: übergibt das gebaute Gefährt an die Spielszene (level.tscn).
## Shop:    neue Teile kaufen.   Reset: Werkstatt neu aufbauen.
##
## Hier wird NUR gebaut (alles eingefroren). Zusammenbauen + Fahren passiert
## in der Spielszene.

## Alle baubaren Teile (Name -> Szene). Gezeigt werden nur besessene (GameState).
const PARTS := {
	"Reifen": preload("res://scenes/attachments/wheel.tscn"),
	"Booster": preload("res://scenes/attachments/booster.tscn"),
	"Ballon": preload("res://scenes/attachments/balloon.tscn"),
	"Platform": preload("res://scenes/platforms/platform.tscn"),
}

@onready var vehicle: Node2D = $Vehicle
@onready var chassis: RigidBody2D = $Vehicle/Chassis
@onready var palette: Node2D = $Palette

var dragging: RigidBody2D = null
var drag_kind := ""
var drag_home := Vector2.ZERO
var can_attach := false    # darf das gezogene Teil gerade platziert werden?
var core_blocked := false  # überlappt der No-Overlap-Kern gerade einen anderen?

# Zeichen-Ebene, die ÜBER allem liegt (sonst verdecken Teile/Boden die Zonen).
var overlay: Node2D


func _ready() -> void:
	_freeze_all()       # in der Werkstatt bewegt sich nichts
	_build_palette()
	# Overlay zuletzt hinzufügen + hoher z_index -> zeichnet über allem.
	overlay = Node2D.new()
	overlay.z_index = 1000
	overlay.draw.connect(_draw_zones)
	add_child(overlay)
	# Die HUD-Knöpfe liegen in der Szene (UI/HUD) – hier nur mit Logik verbinden.
	$UI/HUD/Panel/VBox/Spielen.pressed.connect(_play)
	$UI/HUD/Panel/VBox/Shop.pressed.connect(_to_shop)
	$UI/HUD/Panel/VBox/Reset.pressed.connect(_to_reset)


# --- Palette --------------------------------------------------------------

func _build_palette() -> void:
	var pos := Vector2(880, 110)
	for kind in PARTS:
		if not GameState.owned.has(kind):
			continue  # nur Teile zeigen, die man besitzt (Rest gibt's im Shop)
		_spawn_palette_item(kind, pos)
		pos.y += 130.0


func _spawn_palette_item(kind: String, pos: Vector2) -> void:
	var item := (PARTS[kind] as PackedScene).instantiate() as RigidBody2D
	palette.add_child(item)
	item.global_position = pos
	item.freeze = true
	item.set_meta("kind", kind)
	item.set_meta("home", pos)
	item.add_to_group("palette_item")


# --- Bauen (Drag & Drop) ---------------------------------------------------

func _process(_delta: float) -> void:
	if dragging != null:
		dragging.global_position = get_global_mouse_position()
		core_blocked = _core_overlaps_any(dragging)
		can_attach = _touches_vehicle(dragging) and not core_blocked
		overlay.queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var item := _palette_item_at(get_global_mouse_position())
			if item != null:
				_start_drag(item)
		elif dragging != null:
			_drop()


func _start_drag(item: RigidBody2D) -> void:
	dragging = item
	drag_kind = item.get_meta("kind", "")
	drag_home = item.get_meta("home", item.global_position)
	item.remove_from_group("palette_item")
	_spawn_palette_item(drag_kind, drag_home)  # Palettenplatz sofort nachfüllen


func _drop() -> void:
	var part := dragging
	dragging = null
	can_attach = false
	overlay.queue_redraw()
	if _can_place(part):
		part.reparent(vehicle)  # ans Gefährt anbauen (Position bleibt)
		part.freeze = true      # bleibt liegen bis "Spielen"
	else:
		part.queue_free()       # darf nicht hierhin -> verwerfen


# Darf das Teil hier angebaut werden? Zwei Bedingungen:
#  1. Sticky: sein Rand muss das Fahrwerk oder ein anderes Teil berühren.
#  2. No-Overlap: sein Kern darf KEINEN anderen Kern überlappen (kein Stapeln).
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


# Überlappt der Kern des Teils den Kern eines anderen ATTACHMENTS?
# Körperteile (Fahrwerk/Plattform) zählen nicht – auf denen darf man montieren.
func _core_overlaps_any(part: RigidBody2D) -> bool:
	var r := _core_radius(part)
	for other in vehicle.get_children():
		if not (other is RigidBody2D) or _is_body(other):
			continue
		var dist := part.global_position.distance_to((other as Node2D).global_position)
		if dist < r + _core_radius(other):
			return true
	return false


# Außenradius der Form (Kreis: Radius; Rechteck: halbe kürzere Seite).
func _outer_radius(part: RigidBody2D) -> float:
	var shape := (part.get_node("CollisionShape2D") as CollisionShape2D).shape
	if shape is CircleShape2D:
		return (shape as CircleShape2D).radius
	if shape is RectangleShape2D:
		return minf((shape as RectangleShape2D).size.x, (shape as RectangleShape2D).size.y) / 2.0
	return 1.0


# Radius des No-Overlap-Kerns, abgeleitet aus dem Sticky-Anteil in PROZENT
# (metadata/sticky_percent, 0–100, pro Item einstellbar):
#    0 %  -> Kern = ganze Form (kein Sticky-Rand)
#   50 %  -> Kern = halber Radius (äußere Hälfte ist Sticky)
#  100 %  -> Kern = 0 (alles Sticky, keine No-Overlap-Zone)
func _core_radius(part: RigidBody2D) -> float:
	# Wert in Prozent. Feld "sticky_percent" – oder das alte "sticky_width",
	# das ebenfalls als Prozent gelesen wird (egal wie es im Inspector heißt).
	var percent: float = part.get_meta("sticky_percent", part.get_meta("sticky_width", 40.0))
	percent = clampf(percent, 0.0, 100.0)
	return _outer_radius(part) * (1.0 - percent / 100.0)


func _palette_item_at(point: Vector2) -> RigidBody2D:
	for it in get_tree().get_nodes_in_group("palette_item"):
		if _point_in_body(it, point):
			return it as RigidBody2D
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


# Zeichnet auf dem Overlay (über allem) die beiden Zonen des gezogenen Teils:
#   Außen (eingefärbte Fläche) = Sticky-Area: weiß = in der Hand, grün = dockt an.
#   Innen (rot) = No-Overlap-Kern; kräftiger rot, wenn er gerade überlappt.
func _draw_zones() -> void:
	if dragging == null:
		return
	var pos := dragging.global_position
	var outer := _outer_radius(dragging)
	var core := _core_radius(dragging)

	var sticky_col := Color(0.3, 1.0, 0.4, 0.5) if can_attach else Color(1.0, 1.0, 1.0, 0.30)
	overlay.draw_circle(pos, outer, sticky_col)

	if core > 0.5:
		var a := 0.6 if core_blocked else 0.35
		overlay.draw_circle(pos, core, Color(0.95, 0.25, 0.2, a))


# --- Übergabe / Reset ------------------------------------------------------

# Übergibt das gebaute Gefährt an die Spielszene.
func _play() -> void:
	remove_child(vehicle)            # aus der Werkstatt herauslösen
	GameState.built_vehicle = vehicle  # ...und an die Spielszene weiterreichen
	get_tree().change_scene_to_file("res://scenes/level.tscn")


# Friert Fahrwerk und alle angebauten Teile ein.
func _freeze_all() -> void:
	for child in vehicle.get_children():
		if child is RigidBody2D:
			child.freeze = true


func _to_shop() -> void:
	get_tree().change_scene_to_file("res://scenes/shop.tscn")


func _to_reset() -> void:
	get_tree().reload_current_scene()
