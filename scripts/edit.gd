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

## Baubare Teile – wird beim Start DATENGETRIEBEN aus dem ItemCatalog gefüllt
## (res://items/*.tres). Struktur je Eintrag:
##   { scene, available_from_level, price, display_name }
## Neue Items = neue .tres-Datei, kein Code hier.
var PARTS := {}


# Liest die Item-Definitionen aus dem Katalog in PARTS (id -> Anzeige-Infos).
func _build_parts_from_catalog() -> void:
	PARTS.clear()
	for id in ItemCatalog.ids():
		var def = ItemCatalog.get_def(id)
		PARTS[id] = {
			"scene": def.scene,
			"available_from_level": def.unlock_checkpoint,
			"price": def.price,
			"display_name": def.display_name,
		}

## Pflicht-Passagier (kein normales Palette-Teil): steht links, muss per Hand
## ans Fahrzeug gestickt werden, bevor man "Spielen" kann.
const FIGUR_SCENE := preload("res://scenes/attachments/figur.tscn")
## Heimat-Position der Figur links im Bild (Welt-Koordinaten = Hand/Andockpunkt).
const FIGUR_HOME := Vector2(-30, 230)

## Eine Karte im Shop (Icon + Name + Preis). Aussehen in der Szene.
const STORE_ITEM := preload("res://scenes/store_item.tscn")

@onready var vehicle: Node2D = $Vehicle
@onready var chassis: RigidBody2D = $Vehicle/Chassis
@onready var palette: Node2D = $Palette
@onready var budget_label: Label = $UI/HUD/Budget/Value
@onready var level_label: Label = $UI/HUD/Level/Value
@onready var store_list: VBoxContainer = $UI/HUD/Store/VBox/Scroll/List

# Shop-Karten je Teil-Sorte (kind -> Button).
var _cards := {}

## Schwebendes "-500"/"+500" am Budget.
const BUDGET_POPUP := preload("res://scenes/budget_popup.tscn")

## Drehschritt pro Mausrad-Tick (~15°).
const ROT_STEP := 0.2618

## Standard-Sticky-Anteil in % (falls ein Teil kein metadata/sticky_percent hat).
const DEFAULT_STICKY := 35.0

var dragging: RigidBody2D = null
var drag_kind := ""
var can_attach := false    # darf das gezogene Teil gerade platziert werden?
var core_blocked := false  # überlappt der No-Overlap-Kern gerade einen anderen?

# Beim Verschieben eines schon platzierten Teils: Rückfall-Lage, falls ungültig.
var drag_is_move := false
var drag_return_pos := Vector2.ZERO
var drag_return_rot := 0.0

# Wird gerade der Pflicht-Passagier gezogen? (wird nie verworfen -> zurück nach links)
var drag_is_passenger := false
# Der eine Passagier (Figur). Liegt entweder links (Palette) oder am Fahrzeug.
var passenger: RigidBody2D = null

# Zeichen-Ebene, die ÜBER allem liegt (sonst verdecken Teile/Boden die Zonen).
var overlay: Node2D

func _update_budget_label() -> void:
	budget_label.text = str(GameState.budget) + "$"


# Summe der Preise ALLER aktuell verbauten Teile (Figur ist gratis).
func _spent() -> int:
	var sum := 0
	for child in vehicle.get_children():
		if child is RigidBody2D and child != chassis:
			var kind := String(child.get_meta("kind", ""))
			if PARTS.has(kind):
				sum += PARTS[kind]["price"] as int
	return sum


# Budget IMMER sauber aus den verbauten Teilen ableiten -> nie negativ, nie
# "Geld weg ohne Teil". Wird nach jeder Bau-Änderung aufgerufen.
func _recompute_budget() -> void:
	GameState.budget = GameState.base_budget - _spent()
	_update_budget_label()
	_update_store()


# Kurzes schwebendes "-500" (Kauf) / "+500" (Rückgabe) am Budget.
func _show_budget_delta(amount: int) -> void:
	if amount == 0:
		return
	var popup := BUDGET_POPUP.instantiate()
	budget_label.add_child(popup)
	popup.position = Vector2(-30, -8)   # knapp über/neben der Zahl
	popup.show_delta(amount)

func _ready() -> void:
	_build_parts_from_catalog()    # Items aus res://items/*.tres laden
	GameState.set_budget()
	GameState.build_into(vehicle)  # gespeicherten Bau wiederherstellen
	level_label.text = str(GameState.last_checkpoint + 1) # +1 because initial "last" checkpoint is 0

	_freeze_all()       # in der Werkstatt bewegt sich nichts
	_build_store()      # Shop-Karten aufbauen
	_recompute_budget() # Budget aus den (geladenen) Teilen sauber ableiten
	_setup_passenger()  # Pflicht-Figur links (oder die schon angebaute übernehmen)
	# Overlay zuletzt hinzufügen + hoher z_index -> zeichnet über allem.
	overlay = Node2D.new()
	overlay.z_index = 1000
	overlay.draw.connect(_draw_zones)
	add_child(overlay)
	# Die HUD-Knöpfe liegen in der Szene (UI/HUD) – hier nur mit Logik verbinden.
	$UI/HUD/Panel/VBox/Spielen.pressed.connect(_play)
	$UI/HUD/Panel/VBox/Reset.pressed.connect(_to_reset)


# --- Shop (scrollbare Liste, skaliert auf beliebig viele Teile) -----------

# Baut für jede Teil-Sorte eine Karte. Das Icon wird automatisch aus der
# Teil-Szene gerendert (SubViewport) – keine eigene Textur nötig.
func _build_store() -> void:
	for child in store_list.get_children():
		child.queue_free()
	_cards.clear()
	for kind in PARTS:
		var card: Button = STORE_ITEM.instantiate()
		store_list.add_child(card)
		(card.get_node("Row/Info/Name") as Label).text = PARTS[kind].get("display_name", kind)
		_fill_icon(card.get_node("Row/IconBox/Icon"), kind)
		card.button_down.connect(_begin_buy.bind(kind))
		_cards[kind] = card
	_update_store()


# Rendert die Teil-Szene als Vorschau in den kleinen SubViewport der Karte.
func _fill_icon(vp: SubViewport, kind: String) -> void:
	var part: Node = ItemCatalog.create(kind)        # Variante (Größe/Farbe) korrekt
	part.process_mode = Node.PROCESS_MODE_DISABLED   # Teil-Skripte im Icon ruhig
	if part is RigidBody2D:
		part.freeze = true
		part.collision_layer = 0
		part.collision_mask = 0
	# Anhand der SICHTBAREN Ausdehnung einpassen (nicht der Kollision): manche
	# Teile haben winzige Kollision aber große/versetzte Optik – z.B. der Ballon,
	# der über einer Schnur am kleinen Andock-Knoten hängt.
	var bounds := _visual_bounds(part)
	var ext := maxf(bounds.size.x, bounds.size.y) * 0.5
	var s := 24.0 / maxf(8.0, ext)                  # auf ~48 px einpassen
	part.scale = Vector2(s, s)
	# Box-Mitte (nicht den Ursprung) ins Viewport-Zentrum legen, damit versetzte
	# Optik nicht aus dem Icon rutscht.
	part.position = Vector2(vp.size) * 0.5 - bounds.get_center() * s
	vp.add_child(part)


# Lokale Bounding-Box aller sichtbaren/kollidierenden Knoten eines Teils
# (in Teil-Koordinaten) – zum Einpassen ins Shop-Icon.
func _visual_bounds(part: Node) -> Rect2:
	var rect := Rect2()
	var has := false
	for n in part.get_children():
		if not (n is Node2D):
			continue
		var r := _node_extent(n as Node2D)
		if r.size == Vector2.ZERO:
			continue
		rect = r if not has else rect.merge(r)
		has = true
	return rect if has else Rect2(-30, -30, 60, 60)


# Ausdehnung eines einzelnen Knotens in Teil-Koordinaten (Drehung ignoriert –
# fürs Icon genügt eine grobe Box). Deckt Form, Polygon, Linie und Sprites ab.
func _node_extent(n: Node2D) -> Rect2:
	var local := Rect2()
	if n is CollisionShape2D:
		var sh := (n as CollisionShape2D).shape
		if sh is CircleShape2D:
			var r := (sh as CircleShape2D).radius
			local = Rect2(-r, -r, 2.0 * r, 2.0 * r)
		elif sh is RectangleShape2D:
			var sz := (sh as RectangleShape2D).size
			local = Rect2(-sz * 0.5, sz)
		else:
			return Rect2()
	elif n is Polygon2D:
		local = _points_rect((n as Polygon2D).polygon)
	elif n is Line2D:
		local = _points_rect((n as Line2D).points)
	elif n is Sprite2D and (n as Sprite2D).texture != null:
		var t := (n as Sprite2D).texture.get_size()
		local = Rect2(-t * 0.5, t)
	elif n is AnimatedSprite2D:
		var t := _anim_frame_size(n as AnimatedSprite2D)
		if t == Vector2.ZERO:
			return Rect2()
		local = Rect2(-t * 0.5, t)
	else:
		return Rect2()
	# Eigene Position/Skalierung des Knotens auf die Box anwenden.
	local.position = local.position * n.scale + n.position
	local.size *= n.scale
	return local


# Achsen-Box einer Punktwolke (z.B. Polygon- oder Linien-Punkte).
func _points_rect(pts: PackedVector2Array) -> Rect2:
	if pts.is_empty():
		return Rect2()
	var mn := pts[0]
	var mx := pts[0]
	for p in pts:
		mn = mn.min(p)
		mx = mx.max(p)
	return Rect2(mn, mx - mn)


# Größe des ersten Frames einer AnimatedSprite2D (für die Icon-Box).
func _anim_frame_size(a: AnimatedSprite2D) -> Vector2:
	var frames := a.sprite_frames
	if frames == null:
		return Vector2.ZERO
	var anim := a.animation
	if not frames.has_animation(anim):
		var names := frames.get_animation_names()
		if names.is_empty():
			return Vector2.ZERO
		anim = names[0]
	if frames.get_frame_count(anim) == 0:
		return Vector2.ZERO
	var tex := frames.get_frame_texture(anim, 0)
	return tex.get_size() if tex != null else Vector2.ZERO


# Aktualisiert Preis-Text und Verfügbarkeit (Level/Geld) aller Karten.
# Verfügbarkeit kommt aus der Progression-Config (oder Formel-Fallback).
func _update_store() -> void:
	for kind in _cards:
		var card: Button = _cards[kind]
		var preis := card.get_node("Row/Info/Preis") as Label
		var price := PARTS[kind]["price"] as int
		if not GameState.is_item_available(kind):
			var lvl: int = GameState.unlock_level_of(kind)
			preis.text = ("from Level " + str(lvl + 1)) if lvl >= 0 else "locked"
			card.disabled = true
		else:
			preis.text = str(price) + "$"
			card.disabled = price > GameState.budget
		card.modulate.a = 0.4 if card.disabled else 1.0


func _can_buy(kind: String) -> bool:
	if not GameState.is_item_available(kind):
		return false
	return PARTS[kind]["price"] <= GameState.budget


# Aus dem Shop ein neues Teil "in die Hand nehmen": am Mauszeiger erzeugen und
# ab da übernimmt die normale Drag&Drop-/Sticky-Logik.
func _begin_buy(kind: String) -> void:
	if dragging != null or not _can_buy(kind):
		return
	var item := ItemCatalog.create(kind) as RigidBody2D  # inkl. Varianten-Overrides
	palette.add_child(item)
	item.global_position = get_global_mouse_position()
	item.freeze = true
	dragging = item
	drag_is_move = false
	drag_is_passenger = false
	drag_kind = kind


# --- Pflicht-Passagier (Figur) --------------------------------------------

# Übernimmt eine bereits angebaute Figur (aus dem Bauplan) – sonst neue links.
func _setup_passenger() -> void:
	passenger = _figur_on_vehicle()
	if passenger == null:
		passenger = _spawn_passenger_home()


# Frische Figur an ihrer Heimat-Position links erzeugen.
func _spawn_passenger_home() -> RigidBody2D:
	var fig := FIGUR_SCENE.instantiate() as RigidBody2D
	palette.add_child(fig)
	fig.global_position = FIGUR_HOME
	fig.freeze = true
	fig.set_meta("kind", "Figur")
	return fig


# Schickt die Figur zurück an ihren Platz links.
func _send_passenger_home() -> void:
	if passenger.get_parent() != palette:
		passenger.reparent(palette)
	passenger.global_position = FIGUR_HOME
	passenger.rotation = 0.0
	passenger.freeze = true


# Die am Fahrzeug angebaute Figur (oder null).
func _figur_on_vehicle() -> RigidBody2D:
	for child in vehicle.get_children():
		if child is RigidBody2D and child.get_meta("kind", "") == "Figur":
			return child as RigidBody2D
	return null


func _passenger_attached() -> bool:
	return passenger != null and is_instance_valid(passenger) \
			and passenger.get_parent() == vehicle


# --- Bauen (Drag & Drop) ---------------------------------------------------

func _process(_delta: float) -> void:
	if dragging != null:
		dragging.global_position = get_global_mouse_position()
		core_blocked = _core_overlaps_any(dragging)
		can_attach = _touches_vehicle(dragging) and not core_blocked
		overlay.queue_redraw()


func _input(event: InputEvent) -> void:
	# Mausrad dreht das gerade gezogene Teil.
	if dragging != null:
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				dragging.rotation += ROT_STEP
				overlay.queue_redraw()
				return
			if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				dragging.rotation -= ROT_STEP
				overlay.queue_redraw()
				return
		elif Input.is_action_pressed("ui_a"):
			dragging.rotation += ROT_STEP
			overlay.queue_redraw()
			return
		elif Input.is_action_pressed("ui_d"):
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
			if placed == passenger:
				_send_passenger_home()     # Figur nie löschen -> zurück nach links
			else:
				var kind := String(placed.get_meta("kind", ""))
				vehicle.remove_child(placed)   # sofort raus (queue_free wäre verzögert)
				placed.queue_free()
				if PARTS.has(kind):
					_show_budget_delta(PARTS[kind]["price"] as int)  # grünes +Preis
			GameState.save_from(vehicle)   # Bauplan ohne das Teil neu schreiben
			_recompute_budget()            # Geld korrekt zurückbuchen


# Greift ein schon platziertes Teil (zum Verschieben/Drehen) oder den
# Passagier. Neue Teile kommen über den Shop (_begin_buy), nicht hierüber.
func _try_grab(point: Vector2) -> void:
	drag_is_passenger = false

	# Pflicht-Passagier links (hängt noch nicht am Fahrzeug)?
	if passenger != null and is_instance_valid(passenger) \
			and passenger.get_parent() != vehicle and _point_in_body(passenger, point):
		dragging = passenger
		drag_is_move = false
		drag_is_passenger = true
		drag_kind = "Figur"
		passenger.reparent(palette)         # während des Ziehens "in der Hand"
		passenger.freeze = true
		return

	var placed := _attachment_at(point)
	if placed != null:
		dragging = placed
		drag_is_move = true
		drag_is_passenger = placed == passenger   # angebaute Figur verschieben
		drag_kind = placed.get_meta("kind", "")
		drag_return_pos = placed.position   # zum Zurücklegen, falls ungültig
		drag_return_rot = placed.rotation
		placed.reparent(palette)            # während des Ziehens "in der Hand"


func _drop() -> void:
	var part := dragging
	dragging = null
	can_attach = false
	overlay.queue_redraw()
	# Nur ein NEUES Teil (frisch aus der Palette) wird gekauft; Verschieben/Figur
	# kostet nichts.
	var is_new_buy := not drag_is_move and not drag_is_passenger
	if _can_place(part):
		part.reparent(vehicle)  # ans Gefährt anbauen (Position bleibt)
		part.freeze = true      # bleibt liegen bis "Spielen"
		if is_new_buy and PARTS.has(drag_kind):
			_show_budget_delta(-(PARTS[drag_kind]["price"] as int))  # rote -Preis
	elif drag_is_move:
		# Verschobenes Teil ungültig abgelegt -> zurück an die alte Stelle.
		part.reparent(vehicle)
		part.position = drag_return_pos
		part.rotation = drag_return_rot
		part.freeze = true
	elif drag_is_passenger:
		_send_passenger_home()  # Figur nie verwerfen -> zurück nach links
	else:
		part.queue_free()       # neues Teil daneben -> verwerfen
	drag_is_passenger = false
	GameState.save_from(vehicle)  # Bauplan aktualisieren (auch nach Verschieben)
	_recompute_budget()           # Budget immer sauber neu ableiten


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
# ABER: erst wenn der Passagier mit der Hand am Fahrzeug klebt. Sonst blinkt
# seine Hand auffällig -> Hinweis "muss erst angesteckt werden".
func _play() -> void:
	if not _passenger_attached():
		if passenger != null and is_instance_valid(passenger):
			passenger.flash_hand(chassis.global_position)  # Pfeil zeigt zum Fahrwerk
		return
	GameState.save_from(vehicle)
	# Über den GameController wechseln, damit der Loop im GUI-System bleibt
	# (Werkstatt <-> Spiel ohne den Controller zu zerstören); sonst direkt.
	var gc = Global.game_controller
	if gc != null and is_instance_valid(gc):
		gc.change_gui_scene("res://scenes/level.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/level.tscn")


# Friert Fahrwerk und alle angebauten Teile ein.
func _freeze_all() -> void:
	for child in vehicle.get_children():
		if child is RigidBody2D:
			child.freeze = true


# Setzt die Werkstatt auf Anfang: alle Attachments/Plattformen weg, Bauplan leer.
func _to_reset() -> void:
	GameState.blueprint.clear()          # sonst würde der Bau gleich neu geladen
	if passenger != null and is_instance_valid(passenger):
		passenger.queue_free()           # alte Figur (egal ob links oder am Fahrzeug)
	for child in vehicle.get_children():
		if child is RigidBody2D and child != chassis:
			child.queue_free()
	passenger = _spawn_passenger_home()  # frische Figur links bereitstellen
	GameState.set_budget()               # base_budget (aus Highscore) neu setzen
	_recompute_budget()                  # leerer Wagen -> volles Budget zurück
