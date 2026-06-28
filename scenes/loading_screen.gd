extends CanvasLayer

@onready var label: Label = $Label
@onready var anim = $AnimatedSprite2D
@onready var timer = $Timer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	anim.play("loading")
	# timer.start()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
