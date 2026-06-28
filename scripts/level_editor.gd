extends Control
## LEVEL-EDITOR (Developer-Tool) – NICHT aus dem Spiel erreichbar.
## Szene direkt im Godot-Editor öffnen und mit F6 starten.
##
## Zeigt die Checkpoints auf einem Zeitstrahl (Distanz + Abstände) und lässt
## pro Checkpoint Budget und verfügbare Items einstellen. Speichert das alles
## in res://config/progression.tres, das das Spiel dann liest.

const CONFIG_PATH := "res://config/progression.tres"

# Formel-Werte (müssen zu GameState passen) – für "Aus Formel generieren".
const FIRST_CHECKPOINT := 150
const CHECKPOINT_COEFF := 1.3
const INITIAL_BUDGET := 1000

var _rows: Array = []          # je Zeile: { box, num, dist, budget, checks:{id:CheckBox} }
var _rows_box: VBoxContainer
var _band: Control
var _status: Label
var _gen_count: SpinBox


func _ready() -> void:
	_build_ui()
	if ResourceLoader.exists(CONFIG_PATH):
		_reload()
	else:
		_generate(8)


# --- UI-Aufbau ------------------------------------------------------------

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Nur fürs Editor-Tool eine neutrale System-Schrift statt der Spiel-Schrift.
	var sys := SystemFont.new()
	sys.font_names = PackedStringArray(["Sans-Serif", "DejaVu Sans", "Noto Sans", "Arial"])
	var neutral := Theme.new()
	neutral.default_font = sys
	neutral.default_font_size = 15
	theme = neutral
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	var title := Label.new()
	title.text = "LEVEL EDITOR  (dev – speichert nach %s)" % CONFIG_PATH
	title.add_theme_font_size_override("font_size", 22)
	root.add_child(title)

	# Werkzeugleiste
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	root.add_child(bar)
	bar.add_child(_make_label("Checkpoints:"))
	_gen_count = SpinBox.new()
	_gen_count.min_value = 1
	_gen_count.max_value = 40
	_gen_count.value = 8
	bar.add_child(_gen_count)
	bar.add_child(_make_button("Aus Formel generieren", _on_generate))
	bar.add_child(_make_button("+ Checkpoint", _on_add))
	bar.add_child(_make_button("Speichern", _save))
	bar.add_child(_make_button("Neu laden", _reload))
	_status = _make_label("")
	bar.add_child(_status)

	# Zeitstrahl / Längenband
	_band = Control.new()
	_band.custom_minimum_size = Vector2(0, 90)
	_band.draw.connect(_draw_band)
	root.add_child(_band)

	# Scrollbare Liste der Checkpoint-Zeilen
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	root.add_child(scroll)
	_rows_box = VBoxContainer.new()
	_rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows_box.add_theme_constant_override("separation", 4)
	scroll.add_child(_rows_box)


func _make_label(t: String) -> Label:
	var l := Label.new()
	l.text = t
	return l


func _make_button(t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.pressed.connect(cb)
	return b


# Eine Checkpoint-Zeile: Nummer, Distanz, Budget, Item-Häkchen, Entfernen.
func _add_row(distance: int, budget: int, items: Array) -> void:
	var idx := _rows.size()
	var panel := PanelContainer.new()
	_rows_box.add_child(panel)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	panel.add_child(hb)

	var num := _make_label("CP %d" % idx)
	num.custom_minimum_size = Vector2(48, 0)
	hb.add_child(num)

	hb.add_child(_make_label("Dist"))
	var dist := SpinBox.new()
	dist.min_value = 0
	dist.max_value = 10000000
	dist.step = 10
	dist.value = distance
	dist.value_changed.connect(func(_v): _band.queue_redraw())
	hb.add_child(dist)

	hb.add_child(_make_label("Budget"))
	var bud := SpinBox.new()
	bud.min_value = 0
	bud.max_value = 10000000
	bud.step = 50
	bud.value = budget
	hb.add_child(bud)

	hb.add_child(_make_label("Items:"))
	var flow := HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(flow)
	var checks := {}
	for id in ItemCatalog.ids():
		var cb := CheckBox.new()
		cb.text = ItemCatalog.get_def(id).display_name
		cb.button_pressed = id in items
		flow.add_child(cb)
		checks[id] = cb

	var rm := _make_button("✕", func(): _remove_row(panel))
	hb.add_child(rm)

	_rows.append({"box": panel, "num": num, "dist": dist, "budget": bud, "checks": checks})


func _remove_row(panel: Node) -> void:
	for i in _rows.size():
		if _rows[i]["box"] == panel:
			_rows.remove_at(i)
			break
	panel.queue_free()
	_renumber()


func _clear_rows() -> void:
	for r in _rows:
		r["box"].queue_free()
	_rows.clear()


func _renumber() -> void:
	for i in _rows.size():
		_rows[i]["num"].text = "CP %d" % i
	_band.queue_redraw()


# --- Aktionen -------------------------------------------------------------

func _on_generate() -> void:
	_generate(int(_gen_count.value))


func _generate(count: int) -> void:
	_clear_rows()
	for i in count:
		_add_row(_formula_distance(i), _formula_budget(i), _formula_items(i))
	_renumber()
	_set_status("%d Checkpoints aus Formel generiert." % count)


func _on_add() -> void:
	var i := _rows.size()
	_add_row(_formula_distance(i), _formula_budget(i), _formula_items(i))
	_renumber()


func _save() -> void:
	DirAccess.make_dir_recursive_absolute("res://config")
	var cfg = ProgressionConfig.new()
	var levels := []
	for r in _rows:
		var items := []
		for id in r["checks"]:
			if (r["checks"][id] as CheckBox).button_pressed:
				items.append(id)
		levels.append({
			"distance": int(r["dist"].value),
			"budget": int(r["budget"].value),
			"items": items,
		})
	cfg.levels = levels
	var err := ResourceSaver.save(cfg, CONFIG_PATH)
	if err == OK:
		_set_status("Gespeichert: %d Checkpoints -> %s" % [levels.size(), CONFIG_PATH])
	else:
		_set_status("FEHLER beim Speichern (%d)" % err)


func _reload() -> void:
	if not ResourceLoader.exists(CONFIG_PATH):
		_set_status("Keine Config vorhanden – erst speichern.")
		return
	var cfg = load(CONFIG_PATH)
	_clear_rows()
	for lvl in cfg.levels:
		_add_row(int(lvl.get("distance", 0)), int(lvl.get("budget", 0)), lvl.get("items", []))
	_renumber()
	_set_status("Geladen: %d Checkpoints." % _rows.size())


func _set_status(t: String) -> void:
	_status.text = "   " + t


# --- Formel (= GameState) -------------------------------------------------

func _formula_distance(idx: int) -> int:
	var d := 0
	for k in idx:
		d += FIRST_CHECKPOINT * int(pow(CHECKPOINT_COEFF, k))
	return d


func _formula_budget(idx: int) -> int:
	var res := 0
	var inc := 100
	for k in idx:
		res += inc
		inc = int(inc * 1.3)
	return maxi(INITIAL_BUDGET, res)


func _formula_items(idx: int) -> Array:
	var arr := []
	for id in ItemCatalog.ids():
		if ItemCatalog.get_def(id).unlock_checkpoint <= idx:
			arr.append(id)
	return arr


# --- Zeitstrahl zeichnen --------------------------------------------------

func _draw_band() -> void:
	var w := _band.size.x
	var h := _band.size.y
	var left := 60.0
	var right := w - 30.0
	var y := h * 0.5
	var font := ThemeDB.fallback_font
	_band.draw_line(Vector2(left, y), Vector2(right, y), Color(0.5, 0.5, 0.55), 2.0)

	if _rows.is_empty():
		return
	var max_d := 1.0
	for r in _rows:
		max_d = maxf(max_d, float(r["dist"].value))

	var prev_x := left
	var prev_d := 0
	for i in _rows.size():
		var d := int(_rows[i]["dist"].value)
		var x: float = left + (float(d) / max_d) * (right - left)
		_band.draw_line(Vector2(x, y - 14), Vector2(x, y + 14), Color(0.9, 0.6, 0.2), 3.0)
		_band.draw_string(font, Vector2(x - 12, y - 20), "CP%d" % i, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
		_band.draw_string(font, Vector2(x - 14, y + 32), str(d), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.8, 0.8, 0.85))
		if i > 0:
			var gap := d - prev_d
			var mid := (prev_x + x) * 0.5
			_band.draw_string(font, Vector2(mid - 14, y - 2), "+%d" % gap, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.55, 0.85, 0.55))
		prev_x = x
		prev_d = d
