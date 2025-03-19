extends Label
#class_name textBalloon
@export var display_time: float = 3.0  # How long the balloon stays visible

var timer: Timer
# Called when the node enters the scene tree for the first time.
func _ready():
	timer = Timer.new()
	timer.one_shot = true
	timer.timeout.connect(_on_timer_timeout)
	add_child(timer)
func show_message(message: String):
	# Update the label text
	text = message
	show()
	
	# Start the timer
	timer.start(display_time)
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_timer_timeout():
	hide()
