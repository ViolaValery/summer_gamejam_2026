extends RigidBody2D
## Booster = Spezial: gibt auf Knopfdruck einen KURZEN Schub nach vorne
## (lokale +X-Richtung). Nicht mehr dauerhaft an.
##
## Wird beim Zusammenbauen mit dem Fahrwerk VERSCHMOLZEN (metadata/attach =
## "weld"), darum zeigt "vorne" immer in Fahrtrichtung. Der Schub wirkt dann
## auf das Fahrwerk (host), angreifend am Ort des Boosters.

@export var thrust: float = 6000.0    # Schubkraft während des Boosts
@export var boost_time: float = 0.5   # Dauer eines Boosts in Sekunden
@export var uses: int = 1             # wie oft pro Runde nutzbar (Rakete: 1x)

var host: RigidBody2D = null          # das Fahrwerk (beim Verschmelzen gesetzt)
var _remaining := 0.0                 # Restzeit des laufenden Boosts
var _uses_left := 0                   # verbleibende Nutzungen


func _ready() -> void:
	_uses_left = uses


# Ist noch ein Boost übrig? (der Spezial-Knopf deaktiviert sich sonst)
func can_activate() -> bool:
	return _uses_left > 0


# Vom Spezial-Knopf in der Spielszene aufgerufen.
func activate() -> void:
	if _uses_left <= 0:
		return
	_uses_left -= 1
	_remaining = boost_time


# --- Abfragen für die Spezial-Knöpfe (Anzahl + laufender Effekt) ----------

# Wie viele Zündungen sind noch übrig?
func remaining_uses() -> int:
	return _uses_left

# Läuft gerade ein Boost?
func is_active() -> bool:
	return _remaining > 0.0

# Restanteil des laufenden Boosts (1.0 = gerade gezündet, 0.0 = vorbei).
func active_fraction() -> float:
	if boost_time <= 0.0:
		return 0.0
	return clampf(_remaining / boost_time, 0.0, 1.0)


func _physics_process(delta: float) -> void:
	if _remaining <= 0.0:
		return  # gerade kein Boost aktiv
	_remaining -= delta

	var dir := Vector2.RIGHT.rotated(global_rotation)
	if host != null and is_instance_valid(host):
		host.apply_force(dir * thrust, global_position - host.global_position)
	else:
		apply_central_force(dir * thrust)
