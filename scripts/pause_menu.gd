extends Control

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

func _on_resume_pressed() -> void:
	get_tree().paused = false
	visible = false

func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	visible = false
	Global.game_controller.change_2d_scene("res://scenes/gui/main_menu.tscn")
