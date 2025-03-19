extends Camera2D

# Export variables for tweaking in the editor
@export var smoothing_speed: float =.1
@export var zoom_smoothing_speed: float = .1
@export var min_zoom: float = 0.4
@export var max_zoom: float = 0.6
@export var margin: float = 200.0  # Extra margin around characters

# Reference to character nodes
var characters: Array = []

func _ready():
	# Get references to your character nodes
	# Adjust this based on your scene structure
	characters = [get_node("/root/Node2D/Character1"), get_node("/root/Node2D/Character2"),get_node("/root/Node2D/Character3")]
	

func _process(delta):
	#if characters.is_empty():
	#   return
		
	# Calculate average position
	#var center = Vector2.ZERO
	#for character in characters:
	var pos1=get_node("/root/Node2D/Character1").global_position
	var pos2=get_node("/root/Node2D/Character2").global_position
	var pos3=get_node("/root/Node2D/Character3").global_position
	var center = pos1+pos2+pos3
	center = center / 3
	
	# Smooth camera movement
	global_position = global_position.lerp(center, smoothing_speed * delta)
	
	# Calculate desired zoom based on character spread
	var max_distance = 0.0
	for i in range(3):
		for j in range(i + 1, 3):
			var distance = characters[i].global_position.distance_to(characters[j].global_position)
			max_distance = max(max_distance, distance)
	
	# Add margin to max distance
	max_distance += margin
	
	# Calculate zoom factor
	# Adjust these values to get desired zoom behavior
	var target_zoom = clamp(1000.0 / (max_distance + 400.0), min_zoom, max_zoom)
	var new_zoom = Vector2(target_zoom, target_zoom)
	
	# Smooth zoom transition
	zoom = zoom.lerp(new_zoom, zoom_smoothing_speed * delta)
