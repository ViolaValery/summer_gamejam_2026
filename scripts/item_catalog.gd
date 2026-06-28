extends Node
## ITEM-KATALOG (Autoload): lädt alle ItemDef-Ressourcen aus res://items/ und
## erzeugt daraus die Teile (inkl. Varianten-Overrides). Einzige Quelle der
## Wahrheit für baubare Items – Shop, Bauplan und (später) Level-Editor lesen
## von hier.

const DIR := "res://items/"

var _defs := {}        # id -> ItemDef
var _ordered := []     # ids in Sortier-Reihenfolge


func _ready() -> void:
	_load()


func _load() -> void:
	_defs.clear()
	_ordered.clear()
	var dir := DirAccess.open(DIR)
	if dir == null:
		push_warning("ItemCatalog: %s nicht gefunden" % DIR)
		return
	var list: Array = []
	var seen := {}
	for f in dir.get_files():
		# WICHTIG (Export/Web): exportierte Ressourcen liegen im PCK als
		# "<name>.tres.remap" bzw. importierte Assets als "<name>.import".
		# Im Editor heißen sie noch "<name>.tres". Daher die Suffixe abschneiden,
		# bevor wir prüfen/laden – sonst ist der Shop im Web-Export leer.
		f = f.trim_suffix(".remap").trim_suffix(".import")
		if not (f.ends_with(".tres") or f.ends_with(".res")):
			continue
		if seen.has(f):
			continue   # gleiche Datei evtl. doppelt gelistet -> nur einmal laden
		seen[f] = true
		var def := load(DIR + f) as ItemDef
		if def != null and def.id != "":
			list.append(def)
	list.sort_custom(func(a: ItemDef, b: ItemDef) -> bool:
		if a.sort_order != b.sort_order:
			return a.sort_order < b.sort_order
		return a.id < b.id)
	for def in list:
		if _defs.has(def.id):
			continue
		_defs[def.id] = def
		_ordered.append(def.id)


func ids() -> Array:
	return _ordered


func has(id: String) -> bool:
	return _defs.has(id)


func get_def(id: String) -> ItemDef:
	return _defs.get(id)


# Erzeugt ein fertig konfiguriertes Teil aus der ItemDef (oder null).
func create(id: String) -> Node:
	var def: ItemDef = _defs.get(id)
	if def == null or def.scene == null:
		return null
	var part := def.scene.instantiate()
	_apply_params(part, def.params)
	_resize(part, def)
	part.set_meta("kind", id)
	return part


# Überschreibt Eigenschaften/Metadaten/Material/Optik laut params-Dictionary.
func _apply_params(part: Node, params: Dictionary) -> void:
	for key in params:
		var v = params[key]
		match key:
			"sticky_percent", "attach", "platform":
				part.set_meta(key, v)
			"friction", "bounce":
				var m: PhysicsMaterial = part.get("physics_material_override")
				if m == null:
					m = PhysicsMaterial.new()
				else:
					m = m.duplicate()   # nicht die geteilte Material-Ressource ändern
				m.set(key, v)
				part.set("physics_material_override", m)
			"color":
				var poly := part.get_node_or_null("Polygon2D")
				if poly != null:
					poly.color = v
				else:
					# Kein Polygon (z.B. Sprite-Booster): über modulate tönen.
					for c in part.get_children():
						if c is Sprite2D or c is AnimatedSprite2D:
							c.modulate = v
							break
			_:
				if key in part:
					part.set(key, v)


# Setzt eine neue Kollisionsgröße und skaliert die Optik (Polygon2D) mit.
# Die Form-Ressource wird vorher dupliziert, damit nicht alle Instanzen mutieren.
func _resize(part: Node, def: ItemDef) -> void:
	var col := part.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col == null:
		return
	var visual := _visual_of(part)   # Polygon ODER Sprite/Animation
	if def.radius > 0.0 and col.shape is CircleShape2D:
		var sh := col.shape.duplicate() as CircleShape2D
		var factor := def.radius / maxf(0.001, sh.radius)
		sh.radius = def.radius
		col.shape = sh
		if visual != null:
			visual.scale *= factor       # Grundskalierung (z.B. 0.08) beibehalten
	elif def.rect_size != Vector2.ZERO and col.shape is RectangleShape2D:
		var sh := col.shape.duplicate() as RectangleShape2D
		var f := def.rect_size / Vector2(maxf(0.001, sh.size.x), maxf(0.001, sh.size.y))
		sh.size = def.rect_size
		col.shape = sh
		if visual != null:
			visual.scale *= f


# Der sichtbare Knoten eines Teils (Polygon, Sprite oder Animation).
func _visual_of(part: Node) -> Node2D:
	for n in ["Polygon2D", "Anim", "Sprite2D"]:
		var node := part.get_node_or_null(n)
		if node != null:
			return node
	for c in part.get_children():
		if c is Polygon2D or c is Sprite2D or c is AnimatedSprite2D:
			return c
	return null
