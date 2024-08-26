extends LineEdit


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_text_submitted(new_text):
	var character_node = get_node("/root/Node2D/Character1")  # Adjust the path as necessary
	character_node.parse_command_(new_text)
	# Clear the text field after entering the command
	self.text = ""
