extends Control

@onready var start: Button = $start

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	visible = false
	start.connect("pressed", _on_start_pressed)
	print("MAINMENU READY, visible: ", visible)
	print("MAINMENU parent: ", get_parent())
	print("MAINMENU children of parent: ", get_parent().get_children())

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta) -> void:
	pass

func _on_start_pressed() -> void:
	#Global.change_gui_scene("res://scenes/overlay?")
	print("START PRESSED")
	Global.game_controller.change_2d_scene("res://scenes/level.tscn")

func _on_quit_pressed() -> void:
	print("QUIT PRESSED")
	get_tree().quit()
