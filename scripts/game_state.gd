extends Node
## Dauerhafter Spielstand – bleibt über Szenenwechsel hinweg (Autoload).
##
## Aktuell nur die Übergabe des in der Werkstatt gebauten Gefährts an die
## Spielszene. (Shop/Währung wurden entfernt; Budget kommt später über den
## Highscore.)

## In der Werkstatt gebautes Gefährt – wird an die Spielszene übergeben.
var built_vehicle: Node2D = null
