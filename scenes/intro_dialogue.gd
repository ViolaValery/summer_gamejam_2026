extends Node2D
const timeline = preload("res://timelines/basic_timeline.dtl")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Dialogic.start(timeline)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
