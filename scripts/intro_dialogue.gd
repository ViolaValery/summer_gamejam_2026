extends Node2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Dialogic.timeline_ended.connect(_on_timeline_ended)
	Dialogic.start("basic_timeline")
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass

func DialogicSignal(argument:String):
	if argument == "quit":
		get_tree().quit()

func _on_timeline_ended() -> void:
	Global.game_controller.change_gui_scene("res://scenes/gui/main_menu.tscn")
	
func _on_skip_pressed() -> void:
	print("SKIP PRESSED")
	Dialogic.timeline_ended.disconnect(_on_timeline_ended)
	Dialogic.clear()
	print("SWITCHING TO MAINMENU")
	Global.game_controller.change_gui_scene("res://scenes/gui/main_menu.tscn")
	print("DONE")
