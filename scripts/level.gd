extends Node2D
## SPIELSZENE: das in der Werkstatt gebaute Gefährt fährt die Strecke.
##
## Steuerung über die Knöpfe im HUD (liegen in level.tscn, hier nur verdrahtet):
##   ◀ / ▶  : Gefährt nach links/rechts kippen (gedrückt halten)
##   Mitte  : Spezial-Knöpfe (z.B. Booster) – pro Spezial-Sorte einer.

## Startpunkt des Gefährts auf der Strecke (im Inspector am Level einstellbar).
## x = wie weit rechts entlang der Strecke, y = Höhe (kleiner = weiter oben).
@export var start_position := Vector2(150, -30)
## Wie stark das Kippen wirkt.
const TILT_TORQUE := 12000.0

@onready var camera: Camera2D = $Camera2D
@onready var tilt_left: Button = $UI/HUD/Controls/TiltLeft
@onready var tilt_right: Button = $UI/HUD/Controls/TiltRight
@onready var specials_box: HBoxContainer = $UI/HUD/Controls/Specials
@onready var workshop_button: Button = $UI/HUD/Werkstatt
@onready var score_label: Label = $UI/HUD/Score/Value
@onready var highscore_label: Label = $UI/HUD/Highscore/Value
# @onready var progress_bar: ProgressBar = $UI/HUD/ProgressBar
@onready var progress_label_min: Label = $UI/HUD/ProgressRocket/Min
@onready var progress_label_max: Label = $UI/HUD/ProgressRocket/Max
@onready var rocket: AnimatedSprite2D = $UI/HUD/ProgressRocket

var vehicle: Node2D
var chassis: RigidBody2D
var tilt := 0.0  # -1 = links, +1 = rechts, 0 = nichts

var next_checkpoint := 0

## Höchster in diesem Lauf erreichter Score. Steigt nur -> der angezeigte Score
## rutscht beim Rückwärtsfahren nicht zurück und zählt beim Hin-und-Her auch
## nicht erneut hoch (das Maximum wird nur bei echtem Weiterkommen überschritten).
var _run_max := 0

# Spezial-Knöpfe je Sorte: kind -> { parts (in Platzier-Reihenfolge), button, bar }
var _specials := {}

## Rückkehr in die Werkstatt, wenn das Gefährt zur Ruhe kommt.
@export var stop_speed := 35.0   # px/s – darunter gilt das Gefährt als "steht"
@export var stop_time := 1.5     # s – so lange muss es ruhig bleiben
## Wie lange das Flaggen-Finale (Sprießen + Wehen) läuft, bevor es zurückgeht.
@export var flag_finale_time := 3.5
## Wie lange der "Geschafft!"-Bildschirm gezeigt wird, bevor es zurückgeht.
@export var win_screen_time := 5.0
var _has_moved := false          # erst losgefahren, bevor wir aufs Stehen prüfen
var _stopped_for := 0.0
var _returning := false          # Szenenwechsel läuft schon -> nicht doppelt
var _won := false                # Ziel erreicht -> Sieg-Ablauf läuft

const FLAG_SCENE := preload("res://scenes/flagge.tscn")
const WIN_SCREEN := preload("res://scenes/geschafft.tscn")
const SPECIAL_BUTTON := preload("res://scenes/special_button.tscn")


func _ready() -> void:
	_spawn_vehicle()
	camera.global_position = chassis.global_position

	update_progress(false)
	
	# Knöpfe aus der Szene mit der Logik verbinden.
	tilt_left.button_down.connect(func(): tilt = -1.0)
	tilt_left.button_up.connect(func(): tilt = 0.0)
	tilt_right.button_down.connect(func(): tilt = 1.0)
	tilt_right.button_up.connect(func(): tilt = 0.0)
	# Kein UI-Fokus -> Pfeiltasten neigen nur, navigieren nicht zwischen Knöpfen.
	tilt_left.focus_mode = Control.FOCUS_NONE
	tilt_right.focus_mode = Control.FOCUS_NONE
	workshop_button.pressed.connect(_go_to_edit)

	# Ziel (falls im Level platziert): Erreichen -> Sieg.
	var ziel := get_node_or_null("Ziel")
	if ziel != null:
		ziel.reached.connect(_win)

	_add_special_buttons()


# Baut das Gefährt aus dem gespeicherten Bauplan – oder ein Standard-Gefährt.
func _spawn_vehicle() -> void:
	vehicle = preload("res://scenes/vehicle.tscn").instantiate()
	GameState.build_into(vehicle)  # Teile aus dem Bauplan der Werkstatt

	if GameState.blueprint.is_empty():
		# Fallback, wenn die Szene direkt (ohne Werkstatt) gestartet wird.
		for x in [-45.0, 45.0]:
			var w: Node = ItemCatalog.create("wheel")
			vehicle.add_child(w)
			w.position = Vector2(x, 32)

	add_child(vehicle)
	vehicle.position = start_position
	chassis = vehicle.get_node("Chassis")

	vehicle.assemble()  # alle Teile fest mit dem Fahrwerk verbinden
	# Auftauen (in der Werkstatt war alles eingefroren).
	for child in vehicle.get_children():
		if child is RigidBody2D:
			child.freeze = false


func _physics_process(delta: float) -> void:
	# Neigen über HUD-Knöpfe (tilt) ODER Pfeiltasten links/rechts.
	var t := tilt
	if Input.is_action_pressed("ui_right"):
		t += 1.0
	if Input.is_action_pressed("ui_left"):
		t -= 1.0
	t = clampf(t, -1.0, 1.0)
	if t != 0.0:
		chassis.apply_torque(t * TILT_TORQUE)
	_check_came_to_rest(delta)


# Schließt den Gameloop: sobald das Gefährt einmal gefahren ist und dann
# unter der Schwellengeschwindigkeit zur Ruhe kommt (am Boden liegen bleibt),
# wird es angehalten und es geht zurück in die Werkstatt.
func _check_came_to_rest(delta: float) -> void:
	if _returning or _won:
		return
	var speed := chassis.linear_velocity.length()
	if speed > 80.0:
		_has_moved = true                 # das Gefährt ist losgefahren
	if not _has_moved:
		return
	if speed < stop_speed and absf(chassis.angular_velocity) < 0.8:
		_stopped_for += delta
		if _stopped_for >= stop_time:
			_return_to_workshop()
	else:
		_stopped_for = 0.0


# ZIEL ERREICHT: Gefährt anhalten, "Geschafft!"-Bildschirm + Sieges-Sound,
# dann zurück in die Werkstatt.
func _win() -> void:
	if _won or _returning:
		return
	_won = true
	_returning = true            # blockiert Stop-Erkennung + doppelten Wechsel
	for child in vehicle.get_children():
		if child is RigidBody2D:
			child.linear_velocity = Vector2.ZERO
			child.angular_velocity = 0.0
			child.freeze = true
	add_child(WIN_SCREEN.instantiate())
	await get_tree().create_timer(win_screen_time).timeout
	_go_to_edit()


# Hält das Gefährt an, lässt zum Abschluss die Flagge sprießen + wehen und
# kehrt danach in die Werkstatt zurück.
func _return_to_workshop() -> void:
	if _returning:
		return
	_returning = true
	for child in vehicle.get_children():
		if child is RigidBody2D:
			child.linear_velocity = Vector2.ZERO
			child.angular_velocity = 0.0
			child.freeze = true
	_play_flag_finale()


func _play_flag_finale() -> void:
	# Flagge am Boden direkt unter dem stehengebliebenen Gefährt aufpflanzen.
	var flag := FLAG_SCENE.instantiate() as Node2D
	add_child(flag)
	flag.global_position = _ground_point_below(chassis.global_position)
	# kurz sprießen + wehen lassen, dann zurück in die Werkstatt.
	await get_tree().create_timer(flag_finale_time).timeout
	_go_to_edit()


# Bodenpunkt senkrecht unter 'from' (trifft nur das Terrain, nicht das Fahrzeug).
func _ground_point_below(from: Vector2) -> Vector2:
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(
			from + Vector2(0, -120), from + Vector2(0, 800))
	q.collision_mask = 8        # Terrain liegt (auch) auf Ebene 4 -> Wert 8
	var hit := space.intersect_ray(q)
	return hit.position if hit else from


# Wechsel in die Werkstatt – bevorzugt über den GameController (change_gui_scene),
# damit der Loop sauber im GUI-System bleibt; sonst direkter Szenenwechsel.
func _go_to_edit() -> void:
	var gc = Global.game_controller
	if gc != null and is_instance_valid(gc):
		gc.change_gui_scene("res://scenes/edit.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/edit.tscn")

func _process(delta: float) -> void:
	# Kamera folgt dem Fahrwerk mit etwas Vorausblick.
	var target := chassis.global_position + Vector2(150, -40)
	camera.global_position = camera.global_position.lerp(target, 5.0 * delta)
	# Score = erreichtes Maximum dieses Laufs (steigt nur, rutscht nie zurück).
	var raw := int(chassis.global_position.x / 5)
	if raw > _run_max:
		_run_max = raw
	move_rocket(_run_max)
	if _run_max > GameState.highscore:
		GameState.highscore = _run_max
	score_label.text = str(_run_max)
	highscore_label.text = str(GameState.highscore)
	_update_specials()


func update_progress(increment: bool = true) -> void:
	progress_label_min.text = str(next_checkpoint)
	if increment:
		next_checkpoint = GameState.increment_checkpoint(next_checkpoint)
	else:
		next_checkpoint = GameState.get_next_checkpoint()
	progress_label_max.text = str(next_checkpoint)

func move_rocket(score: int) -> void:
	if score > next_checkpoint:
		update_progress() # updates next_checkpoint
	var min_value := int(progress_label_min.text)
	var max_value := int(progress_label_max.text)
	var value := float(score - min_value) / (max_value - min_value)
	var total_frames = rocket.sprite_frames.get_frame_count("progress")
	var frame_index = int(clamp(value, 0.0, 1.0) * (total_frames - 1))

	rocket.animation = "progress"
	rocket.frame = frame_index

# --- Spezial-Knöpfe (dynamisch: je nachdem, welche Teile dranhängen) -------

# Specials = Teile mit einer activate()-Methode (z.B. Booster). Pro Sorte EIN
# Knopf. Die Teile werden in PLATZIER-Reihenfolge gesammelt; jeder Klick zündet
# das nächste noch ungenutzte Teil. Der Knopf zeigt die Restanzahl und einen
# Balken für den gerade laufenden Effekt.
func _add_special_buttons() -> void:
	var by_kind := {}
	for node in vehicle.find_children("*", "RigidBody2D", true, false):
		if node.has_method("activate"):
			var kind := String(node.get_meta("kind", "Special"))
			if not by_kind.has(kind):
				by_kind[kind] = []
			by_kind[kind].append(node)  # Tree-Reihenfolge = Platzier-Reihenfolge

	for kind in by_kind:
		_make_special_control(kind, by_kind[kind])
	_update_specials()


func _make_special_control(kind: String, parts: Array) -> void:
	# Aussehen (Knopf + Balken + Farben) kommt aus special_button.tscn.
	var ctrl := SPECIAL_BUTTON.instantiate()
	specials_box.add_child(ctrl)
	var button: Button = ctrl.get_node("Button")
	var bar: ProgressBar = ctrl.get_node("Bar")
	button.pressed.connect(_fire_next.bind(kind))
	button.focus_mode = Control.FOCUS_NONE   # Zahltasten zünden, Pfeile navigieren nicht
	# Anzeigename aus dem Katalog (z.B. "Heavy Booster" statt "booster_heavy").
	var disp := kind
	if ItemCatalog.has(kind):
		disp = ItemCatalog.get_def(kind).display_name
	_specials[kind] = {"parts": parts, "button": button, "bar": bar, "name": disp}


# Zündet das nächste noch ungenutzte Teil dieser Sorte (in Platzier-Reihenfolge).
func _fire_next(kind: String) -> void:
	for p in _specials[kind]["parts"]:
		if is_instance_valid(p) and p.has_method("can_activate") and p.can_activate():
			p.activate()
			return


# Aktualisiert jeden Frame Anzahl, Aktiv-Anzeige und Ablauf-Balken.
func _update_specials() -> void:
	for kind in _specials:
		var d = _specials[kind]
		var remaining := 0
		var active_count := 0
		var max_frac := 0.0
		for p in d["parts"]:
			if not is_instance_valid(p):
				continue
			remaining += _part_uses(p)
			var f := _part_active_fraction(p)
			if f > 0.0:
				active_count += 1
				max_frac = maxf(max_frac, f)

		var button: Button = d["button"]
		var bar: ProgressBar = d["bar"]
		# Text: Anzeigename + Restanzahl. Glüht, solange ein Effekt läuft.
		button.text = "%s (%d)" % [d.get("name", kind), remaining]
		button.modulate = Color(1.0, 0.75, 0.4) if active_count > 0 else Color(1, 1, 1)
		# Zünden nur möglich, solange noch etwas übrig ist.
		button.disabled = remaining <= 0
		# Balken zeigt den jüngsten laufenden Effekt ablaufen.
		bar.value = max_frac


func _part_uses(p) -> int:
	if p.has_method("remaining_uses"):
		return p.remaining_uses()
	if p.has_method("can_activate"):
		return 1 if p.can_activate() else 0
	return 0


func _part_active_fraction(p) -> float:
	if p.has_method("active_fraction"):
		return p.active_fraction()
	return 0.0

# Pause (Escape) + Zahltasten 1-9 für die Spezial-Slots.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):  # Escape key by default
		Global.game_controller.pause_game()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var slot := _slot_from_key(event.keycode)
		if slot >= 0:
			_fire_slot(slot)


# Taste 1..9 (auch Ziffernblock) -> 0-basierter Slot, sonst -1.
func _slot_from_key(keycode: int) -> int:
	if keycode >= KEY_1 and keycode <= KEY_9:
		return keycode - KEY_1
	if keycode >= KEY_KP_1 and keycode <= KEY_KP_9:
		return keycode - KEY_KP_1
	return -1


# Zündet das nächste Item des Spezial-Slots (Reihenfolge der Spezial-Knöpfe).
# Mehrfaches Drücken zündet nacheinander die weiteren Items dieses Slots.
func _fire_slot(slot: int) -> void:
	var kinds := _specials.keys()
	if slot >= 0 and slot < kinds.size():
		_fire_next(kinds[slot])
