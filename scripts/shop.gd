extends Control
## SHOP: neue Fahrzeug-Teile mit Streuselbrötchen kaufen.
## Gekaufte Teile landen im GameState und sind danach in der Werkstatt baubar.

## Was es zu kaufen gibt: Teil-Name -> Preis (in Streuselbrötchen).
const SHOP := {
	"Booster": 10,
	"Ballon": 15,
}

const COIN := preload("res://assets/streuselbrötchen.png")

var _list: VBoxContainer  # hier kommen die Zeilen rein (wird neu gefüllt)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.12, 0.12, 0.15)
	add_child(background)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	add_child(panel)

	_list = VBoxContainer.new()
	_list.custom_minimum_size = Vector2(360, 0)
	panel.add_child(_list)

	_refresh()


# Baut die Liste komplett neu (nach jedem Kauf einfach erneut aufrufen).
func _refresh() -> void:
	for child in _list.get_children():
		child.queue_free()

	var title := Label.new()
	title.text = "Shop"
	_list.add_child(title)

	_list.add_child(_money_row())
	_list.add_child(HSeparator.new())

	for item in SHOP:
		_list.add_child(_item_row(item, SHOP[item]))

	_list.add_child(HSeparator.new())

	var back := Button.new()
	back.text = "Zur Werkstatt"
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/edit.tscn"))
	_list.add_child(back)


# Zeile mit Icon + aktuellem Guthaben.
func _money_row() -> HBoxContainer:
	var row := HBoxContainer.new()

	var icon := TextureRect.new()
	icon.texture = COIN
	icon.custom_minimum_size = Vector2(28, 28)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)

	var label := Label.new()
	label.text = "Guthaben: %d" % GameState.streusel
	row.add_child(label)
	return row


# Zeile pro Teil: Name, Preis, Kauf-Knopf (oder "Gekauft" / "Zu teuer").
func _item_row(item: String, price: int) -> HBoxContainer:
	var row := HBoxContainer.new()

	var name_label := Label.new()
	name_label.text = item
	name_label.custom_minimum_size = Vector2(150, 0)
	row.add_child(name_label)

	var price_label := Label.new()
	price_label.text = "Preis: %d" % price
	price_label.custom_minimum_size = Vector2(110, 0)
	row.add_child(price_label)

	var buy := Button.new()
	if GameState.owned.has(item):
		buy.text = "Gekauft"
		buy.disabled = true
	elif GameState.streusel < price:
		buy.text = "Zu teuer"
		buy.disabled = true
	else:
		buy.text = "Kaufen"
		buy.pressed.connect(func():
			GameState.buy(item, price)
			_refresh())
	row.add_child(buy)
	return row
