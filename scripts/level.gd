extends Node2D
## SPIELSZENE: das in der Werkstatt gebaute Gefährt fährt die Strecke.
##
## Steuerung über die Knöpfe im HUD (liegen in level.tscn, hier nur verdrahtet):
##   ◀ / ▶  : Gefährt nach links/rechts kippen (gedrückt halten)
##   Mitte  : Spezial-Knöpfe (z.B. Booster) – pro Spezial-Sorte einer.

## Startpunkt auf der Strecke (oben am Start-Hügel).
const START_POSITION := Vector2(150, 100)
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

# Spezial-Knöpfe je Sorte: kind -> { parts (in Platzier-Reihenfolge), button, bar }
var _specials := {}

## Rückkehr in die Werkstatt, wenn das Gefährt zur Ruhe kommt.
@export var stop_speed := 35.0   # px/s – darunter gilt das Gefährt als "steht"
@export var stop_time := 1.5     # s – so lange muss es ruhig bleiben
## Wie lange das Flaggen-Finale (Sprießen + Wehen) läuft, bevor es zurückgeht.
@export var flag_finale_time := 3.5
var _has_moved := false          # erst losgefahren, bevor wir aufs Stehen prüfen
var _stopped_for := 0.0
var _returning := false          # Szenenwechsel läuft schon -> nicht doppelt

const FLAG_SCENE := preload("res://scenes/flagge.tscn")


func _ready() -> void:
	_spawn_vehicle()
	camera.global_position = chassis.global_position

	update_progress(false)
	
	# Knöpfe aus der Szene mit der Logik verbinden.
	tilt_left.button_down.connect(func(): tilt = -1.0)
	tilt_left.button_up.connect(func(): tilt = 0.0)
	tilt_right.button_down.connect(func(): tilt = 1.0)
	tilt_right.button_up.connect(func(): tilt = 0.0)
	workshop_button.pressed.connect(_go_to_edit)

	_add_special_buttons()


# Baut das Gefährt aus dem gespeicherten Bauplan – oder ein Standard-Gefährt.
func _spawn_vehicle() -> void:
	vehicle = preload("res://scenes/vehicle.tscn").instantiate()
	GameState.build_into(vehicle)  # Teile aus dem Bauplan der Werkstatt

	if GameState.blueprint.is_empty():
		# Fallback, wenn die Szene direkt (ohne Werkstatt) gestartet wird.
		for x in [-45.0, 45.0]:
			var w := preload("res://scenes/attachments/wheel.tscn").instantiate()
			w.position = Vector2(x, 32)
			w.set_meta("kind", "Reifen")
			vehicle.add_child(w)

	add_child(vehicle)
	vehicle.position = START_POSITION
	chassis = vehicle.get_node("Chassis")

	vehicle.assemble()  # alle Teile fest mit dem Fahrwerk verbinden
	# Auftauen (in der Werkstatt war alles eingefroren).
	for child in vehicle.get_children():
		if child is RigidBody2D:
			child.freeze = false


func _physics_process(delta: float) -> void:
	if tilt != 0.0:
		chassis.apply_torque(tilt * TILT_TORQUE)
	_check_came_to_rest(delta)


# Schließt den Gameloop: sobald das Gefährt einmal gefahren ist und dann
# unter der Schwellengeschwindigkeit zur Ruhe kommt (am Boden liegen bleibt),
# wird es angehalten und es geht zurück in die Werkstatt.
func _check_came_to_rest(delta: float) -> void:
	if _returning:
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
	# update score
	var score := int(chassis.global_position.x / 5)
	move_rocket(score)
	if score > GameState.highscore:
		GameState.highscore =  score
	score_label.text = str(score)
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
			var kind := String(node.get_meta("kind", "Spezial"))
			if not by_kind.has(kind):
				by_kind[kind] = []
			by_kind[kind].append(node)  # Tree-Reihenfolge = Platzier-Reihenfolge

	for kind in by_kind:
		_make_special_control(kind, by_kind[kind])
	_update_specials()


func _make_special_control(kind: String, parts: Array) -> void:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(120, 0)
	box.add_theme_constant_override("separation", 2)
	specials_box.add_child(box)

	var button := Button.new()
	button.custom_minimum_size = Vector2(120, 46)
	button.pressed.connect(_fire_next.bind(kind))
	box.add_child(button)

	# dünner Fortschrittsbalken für den laufenden Effekt
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(120, 9)
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(1.0, 0.55, 0.1)        # orange = aktiver Effekt
	bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.0, 0.0, 0.0, 0.45)
	bar.add_theme_stylebox_override("background", bg)
	box.add_child(bar)

	_specials[kind] = {"parts": parts, "button": button, "bar": bar}


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
		# Text: Sorte + Restanzahl. Glüht, solange ein Effekt läuft.
		button.text = "%s (%d)" % [kind, remaining]
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

# For Pause UI
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):  # Escape key by default
		Global.game_controller.pause_game()
