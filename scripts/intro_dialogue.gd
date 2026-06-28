extends Node2D

var _switching_scene = false 
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
		go_to_main_menu()

func _on_timeline_ended() -> void:
	if _switching_scene:
		return
	_switching_scene = true
	Global.game_controller.change_gui_scene("res://scenes/gui/main_menu.tscn", true)

func go_to_main_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/game_controller.tscn")

func _on_skip_pressed() -> void:
	print("SKIP PRESSED")
	_switching_scene = true
	Dialogic.clear()
	print("SWITCHING TO MAINMENU")
	await get_tree().process_frame
	Global.game_controller.change_gui_scene("res://scenes/gui/main_menu.tscn")
