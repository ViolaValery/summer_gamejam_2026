extends Resource
class_name ItemDef
## Definition eines baubaren Items – DATENGETRIEBEN.
##
## Neue Items/Varianten legt man als .tres-Datei in res://items/ an – KEIN Code
## nötig. Eine einzige Teil-Szene (z.B. wheel.tscn) kann über `params` und die
## Größen-Overrides beliebig viele Varianten erzeugen (kleiner/großer Reifen,
## leichter/schwerer Booster, …).

@export var id := ""                  ## eindeutige ID (= meta "kind")
@export var display_name := ""        ## Anzeigename im Shop
@export var category := ""            ## "wheel" | "booster" | "balloon" | "platform"
@export var scene: PackedScene        ## Basis-Szene des Teils
@export var price := 0
@export var unlock_checkpoint := 0    ## ab welchem Checkpoint kaufbar (0 = Start)
@export var sort_order := 0           ## Reihenfolge im Shop

## Überschreibt Eigenschaften des erzeugten Teils. Schlüssel z.B.:
##   mass, gravity_scale, linear_damp  (RigidBody2D)
##   thrust, boost_time, uses          (Booster-Skript)
##   friction, bounce                  (Physik-Material)
##   sticky_percent                    (Metadaten)
##   color                             (Polygon2D-Farbe)
@export var params := {}

## Größen-Override der Kollisionsform (Optik wird mitskaliert):
@export var radius := 0.0             ## Kreis-Teile (>0 setzt neuen Radius)
@export var rect_size := Vector2.ZERO ## Rechteck-Teile (≠0 setzt neue Größe)
