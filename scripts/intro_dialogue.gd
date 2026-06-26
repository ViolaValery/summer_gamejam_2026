extends Node2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Dialogic.signal_event.connect(DialogicSignal)
	Dialogic.start("basic_timeline")
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass

func DialogicSignal(argument:String):
	if argument == "quit":
		get_tree().quit()
	elif argument == "scene_mainmenu":
		print("scene_mainmenu")
		
		
