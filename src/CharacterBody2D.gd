extends CharacterBody2D


var speed: float = 200.0
var target_position = Vector2()
var moving = false
var areas = {} 

@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D



func _ready():
	# These values need to be adjusted for the actor's speed
	# and the navigation layout.
	var parent_node = get_parent()
	for child in parent_node.get_children():
		if child is Marker2D:
			areas[child.name] = child.position	#navigation_agent.path_desired_distance = 2.0
			print(areas)
	#navigation_agent.target_desired_distance = 2.0
	#navigation_agent.debug_enabled = true


# The "click" event is a custom input action defined in
# Project > Project Settings > Input Map tab.
func _unhandled_input(event):
	if not event.is_action_pressed("click"):
		return
	set_movement_target(get_global_mouse_position())

func _process(delta):
	if moving:
		move_towards_target(delta)

# Function to move the character towards the target position
func move_towards_target(delta):
	var direction = (target_position - position).normalized()
	var velocity = direction * speed * delta
	var remaining_distance = position.distance_to(target_position)
	
	if remaining_distance > velocity.length():
		velocity = velocity.normalized() * speed * delta
		move_and_slide()
	else:
		position = target_position
		moving = false
		
		
# Function to handle movement commands
func go_to_area(area):
	if area in areas:
		#target_position = areas[area_name]
		print(areas[area])
		set_movement_target(areas[area])
		#moving = true
	else:
		print("Area not found: " + area)

# Example function to parse textual commands
func parse_command(command):
	var parts = command.split(" ")
	if parts.size() == 3 and parts[0].to_lower() == "go" and parts[1].to_lower() == "to":
		var area_name = parts[2]
		go_to_area(area_name)
	else:
		print("Invalid command: " + command)
						
func set_movement_target(movement_target: Vector2):
	navigation_agent.target_position = movement_target


func _physics_process(_delta):
	if navigation_agent.is_navigation_finished():
		return

	var current_agent_position: Vector2 = global_position
	var next_path_position: Vector2 = navigation_agent.get_next_path_position()

	velocity = current_agent_position.direction_to(next_path_position) * speed
	move_and_slide()
