extends Node
## Dauerhafter Spielstand – bleibt über Szenenwechsel hinweg (Autoload).
##
## Enthält das Guthaben an Streuselbrötchen und welche Teile man schon besitzt.
## Im Shop kauft man Teile; in der Werkstatt erscheinen nur besessene Teile.

## Guthaben. Startwert zum Ausprobieren – später durch Aufsammeln im Level.
var streusel: int = 30

## Teile, die man besitzt. Reifen hat man von Anfang an.
var owned: Array[String] = ["Reifen", "Platform"]

## In der Werkstatt gebautes Gefährt – wird an die Spielszene übergeben.
var built_vehicle: Node2D = null


## Versucht ein Teil zu kaufen. Gibt true zurück, wenn es geklappt hat.
func buy(item: String, price: int) -> bool:
	if owned.has(item) or streusel < price:
		return false
	streusel -= price
	owned.append(item)
	return true
