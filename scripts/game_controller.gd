extends Node
class_name GameController 

# This is the main scene script for the whole project
# It is accessible everywhere (because we set variable in the global script)

@export var game_2d : Node2D
@export var gui : Control
@export var pause_menu : Control

var current_2d_scene
var current_gui_scene

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Global.game_controller = self
	change_gui_scene("res://scenes/gui/intro_dialogue.tscn", true)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta) -> void:
	pass

func change_gui_scene(new_scene: String, delete: bool = true, keep_running: bool = false) -> void:
	print("CHANGE GUI SCENE: ", new_scene, " current: ", current_gui_scene)
	LoadingScreen.visible = true
	await get_tree().process_frame
	await get_tree().create_timer(1).timeout
	if current_gui_scene != null:
		print("REMOVING: ", current_gui_scene)
		if delete:
			current_gui_scene.queue_free() # remove node entirely
		elif keep_running:
			current_gui_scene.visible = false # keeps in memory and running
		else: 
			gui.remove_child(current_gui_scene) # keeps in memory but not running
	var new = load(new_scene).instantiate()
	gui.add_child(new)
	await get_tree().process_frame
	new.visible = true
	current_gui_scene = new
	LoadingScreen.visible = false
	
func change_2d_scene(new_scene: String, delete: bool = true, keep_running: bool = false) -> void:
	if current_2d_scene != null:
		if delete:
			current_2d_scene.queue_free() # remove node entirely
		elif keep_running:
			current_2d_scene.visible = false # keeps in memory and running
		else: 
			game_2d.remove_child(current_2d_scene) # keeps in memory but not running
	var new = load(new_scene).instantiate()
	game_2d.add_child(new)
	current_2d_scene = new

func pause_game() -> void:
	get_tree().paused = true
	pause_menu.visible = true
