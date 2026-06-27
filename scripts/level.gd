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

var vehicle: Node2D
var chassis: RigidBody2D
var tilt := 0.0  # -1 = links, +1 = rechts, 0 = nichts


func _ready() -> void:
	_spawn_vehicle()
	camera.global_position = chassis.global_position

	# Knöpfe aus der Szene mit der Logik verbinden.
	tilt_left.button_down.connect(func(): tilt = -1.0)
	tilt_left.button_up.connect(func(): tilt = 0.0)
	tilt_right.button_down.connect(func(): tilt = 1.0)
	tilt_right.button_up.connect(func(): tilt = 0.0)
	workshop_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/edit.tscn"))

	_add_special_buttons()


# Holt das Gefährt aus der Werkstatt – oder baut ein Standard-Gefährt.
func _spawn_vehicle() -> void:
	if GameState.built_vehicle != null:
		vehicle = GameState.built_vehicle
		GameState.built_vehicle = null
	else:
		# Fallback, wenn die Szene direkt (ohne Werkstatt) gestartet wird.
		vehicle = preload("res://scenes/vehicle.tscn").instantiate()
		for x in [-45.0, 45.0]:
			var w := preload("res://scenes/attachments/wheel.tscn").instantiate()
			w.position = Vector2(x, 32)
			vehicle.add_child(w)

	add_child(vehicle)
	vehicle.position = START_POSITION
	chassis = vehicle.get_node("Chassis")

	vehicle.assemble()  # alle Teile fest mit dem Fahrwerk verbinden
	# Auftauen (in der Werkstatt war alles eingefroren).
	for child in vehicle.get_children():
		if child is RigidBody2D:
			child.freeze = false


func _physics_process(_delta: float) -> void:
	if tilt != 0.0:
		chassis.apply_torque(tilt * TILT_TORQUE)


func _process(delta: float) -> void:
	# Kamera folgt dem Fahrwerk mit etwas Vorausblick.
	var target := chassis.global_position + Vector2(150, -40)
	camera.global_position = camera.global_position.lerp(target, 5.0 * delta)


# --- Spezial-Knöpfe (dynamisch: je nachdem, welche Teile dranhängen) -------

# Specials = Teile mit einer activate()-Methode (z.B. Booster). Pro Sorte ein
# Knopf, der alle Teile dieser Sorte zünden lässt.
func _add_special_buttons() -> void:
	var by_kind := {}
	for node in vehicle.find_children("*", "RigidBody2D", true, false):
		if node.has_method("activate"):
			var kind := String(node.get_meta("kind", "Spezial"))
			if not by_kind.has(kind):
				by_kind[kind] = []
			by_kind[kind].append(node)

	for kind in by_kind:
		var button := Button.new()
		button.text = kind
		button.custom_minimum_size = Vector2(110, 56)
		button.pressed.connect(_use_special.bind(by_kind[kind], button))
		specials_box.add_child(button)


# Zündet alle Teile dieser Sorte und deaktiviert den Knopf, wenn keine
# Nutzung mehr übrig ist (z.B. Rakete nach dem einmaligen Boost).
func _use_special(parts: Array, button: Button) -> void:
	for p in parts:
		if is_instance_valid(p):
			p.activate()
	button.disabled = not _any_usable(parts)


func _any_usable(parts: Array) -> bool:
	for p in parts:
		if is_instance_valid(p) and p.has_method("can_activate") and p.can_activate():
			return true
	return false
