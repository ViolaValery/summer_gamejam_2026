@tool
extends StaticBody2D
## Boden / Strecke – texturiert: oben ein Belag, darunter Erde.
##
## Die FORM bearbeitest du wie bisher am Kind-Knoten "CollisionPolygon2D"
## (Punkte ziehen). Dank @tool passt sich alles live an.
##
## Über die ganze Länge ist der Boden in 3 BIOME geteilt (Stein / Winter / Weiß).
## Texturen, Belag-Dicke, Biom-Grenzen und Tönungen sind alle im Inspector
## einstellbar – nur die Aufbau-Logik (Form anpassen, in Biome schneiden) steckt
## hier im Skript.

@export var erde_textur: Texture2D
@export var belag_stein: Texture2D
@export var belag_winter: Texture2D
@export var belag_weiss: Texture2D

## Dicke des Belags (oberste Schicht) in Pixeln.
@export var belag_dicke := 40.0
## Die zwei Übergänge zwischen den Biomen, als Anteil der Gesamtlänge (0..1).
@export var biom_grenzen := Vector2(0.34, 0.67)
## Tönung der Erde je Biom (multipliziert die Erd-Textur).
@export var erde_stein := Color(0.95, 0.92, 0.88)
@export var erde_winter := Color(0.82, 0.9, 1.0)
@export var erde_weiss := Color(1, 1, 1)
## Wie fein die Erd-Textur kachelt (kleiner = größere Schollen).
@export var erde_tiling := 1.0

var _last := PackedVector2Array()


func _ready() -> void:
	_rebuild()


func _process(_delta: float) -> void:
	# Im Editor live nachziehen, sobald sich die Form ändert.
	if Engine.is_editor_hint() and $CollisionPolygon2D.polygon != _last:
		_rebuild()


func _rebuild() -> void:
	var poly: PackedVector2Array = $CollisionPolygon2D.polygon
	_last = poly.duplicate()
	if poly.size() < 3:
		return

	var minx := INF
	var maxx := -INF
	for p in poly:
		minx = minf(minx, p.x)
		maxx = maxf(maxx, p.x)

	# --- Erde (gefüllter Körper mit Textur + Biom-Tönung pro Eckpunkt) ---
	var ground: Polygon2D = $Ground
	ground.polygon = poly
	ground.color = Color.WHITE
	ground.texture = erde_textur
	ground.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	ground.texture_scale = Vector2(erde_tiling, erde_tiling)
	ground.uv = poly                       # Welt-Koordinaten -> Textur kachelt
	var cols := PackedColorArray()
	for p in poly:
		cols.append(_biome_tint(p.x, minx, maxx))
	ground.vertex_colors = cols

	# --- Belag (oberste Schicht) als 3 Biom-Streifen entlang der Oberkante ---
	_build_belag(poly, minx, maxx)


# Biom-Tönung der Erde an Welt-x (mit weichem Übergang an den Grenzen).
func _biome_tint(x: float, minx: float, maxx: float) -> Color:
	var f := (x - minx) / maxf(1.0, maxx - minx)
	var b0: float = biom_grenzen.x
	var b1: float = biom_grenzen.y
	var tw := 0.04                          # halbe Überblendbreite
	if f < b0 - tw:
		return erde_stein
	if f < b0 + tw:
		return erde_stein.lerp(erde_winter, (f - (b0 - tw)) / (2.0 * tw))
	if f < b1 - tw:
		return erde_winter
	if f < b1 + tw:
		return erde_winter.lerp(erde_weiss, (f - (b1 - tw)) / (2.0 * tw))
	return erde_weiss


func _build_belag(poly: PackedVector2Array, minx: float, maxx: float) -> void:
	var container := get_node_or_null("Belag")
	if container == null:
		container = Node2D.new()
		container.name = "Belag"
		add_child(container)
	# 3 wiederverwendbare Line2D sicherstellen.
	while container.get_child_count() < 3:
		var ln := Line2D.new()
		ln.texture_mode = Line2D.LINE_TEXTURE_TILE
		ln.joint_mode = Line2D.LINE_JOINT_ROUND
		ln.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		container.add_child(ln)

	var top := _top_edge(poly)
	var bx0 := lerpf(minx, maxx, biom_grenzen.x)
	var bx1 := lerpf(minx, maxx, biom_grenzen.y)
	var bounds := [minx, bx0, bx1, maxx]
	var texes := [belag_stein, belag_winter, belag_weiss]

	for i in 3:
		var ln: Line2D = container.get_child(i)
		var seg := _slice_polyline(top, bounds[i], bounds[i + 1])
		# Belag nach unten versetzen, damit seine Oberkante = echte Oberfläche.
		for j in seg.size():
			seg[j] += Vector2(0, belag_dicke * 0.5)
		ln.points = seg
		ln.width = belag_dicke
		ln.texture = texes[i]
		ln.visible = seg.size() >= 2


# Die obere (befahrbare) Kante = Punkte vom Anfang bis zum am weitesten rechts
# liegenden Eckpunkt (Strecke wird oben-links beginnend gezeichnet).
func _top_edge(poly: PackedVector2Array) -> PackedVector2Array:
	var imax := 0
	for i in poly.size():
		if poly[i].x >= poly[imax].x:
			imax = i
	var top := PackedVector2Array()
	for i in range(imax + 1):
		top.append(poly[i])
	return top


# Schneidet eine (in x steigende) Linie auf den Bereich [xa, xb] zu und fügt an
# den Grenzen interpolierte Punkte ein.
func _slice_polyline(pts: PackedVector2Array, xa: float, xb: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(pts.size() - 1):
		var a := pts[i]
		var b := pts[i + 1]
		if b.x <= a.x:
			continue                        # vertikal/rückwärts überspringen
		if b.x < xa or a.x > xb:
			continue
		var sa := a
		var sb := b
		if a.x < xa:
			sa = a.lerp(b, (xa - a.x) / (b.x - a.x))
		if b.x > xb:
			sb = a.lerp(b, (xb - a.x) / (b.x - a.x))
		if out.is_empty():
			out.append(sa)
		out.append(sb)
	return out
