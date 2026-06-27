extends Control

@onready
var button_start = $start
@onready
var button_quit = $quit

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	visible = false
	print("MAINMENU READY, visible: ", visible)
	print("MAINMENU parent: ", get_parent())
	button_start.pressed.connect(_on_start_pressed)
	button_quit.pressed.connect(_on_quit_pressed)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta) -> void:
	pass

func _on_start_pressed() -> void:
	#Global.change_gui_scene("res://scenes/overlay?")
	print("START PRESSED")
	Global.game_controller.change_gui_scene("res://scenes/level.tscn")

func _on_quit_pressed() -> void:
	print("QUIT PRESSED")
	get_tree().quit()
