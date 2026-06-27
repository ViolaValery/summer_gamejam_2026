extends Control
## Minimal-HUD: nur eine kurze Erklärung und ein Reset-Knopf.
## Das Bauen/Snappen macht world.gd.

var world: Node2D:
	set(value):
		world = value
		_build_ui()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(12, 12)
	add_child(panel)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(260, 0)
	panel.add_child(box)

	var title := Label.new()
	title.text = "Garage – Prototyp"
	box.add_child(title)

	var hint := Label.new()
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	hint.custom_minimum_size = Vector2(260, 0)
	hint.text = "Ziehe Teile von rechts auf die Basis. Der grüne Faden zeigt, wo sich das Teil verbindet."
	box.add_child(hint)

	var reset := Button.new()
	reset.text = "Zurücksetzen"
	reset.pressed.connect(func(): world.clear_parts())
	box.add_child(reset)
