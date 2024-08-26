extends Node

class_name Man

static var areas={}

#static var crowd: Array[Man] = []
# Called when the node enters the scene tree for the first time.
func _ready():
	var parent_node = get_parent()
	for child in parent_node.get_children():
		if child is Marker2D:
			areas[child.name] = child.position	#navigation_agent.path_desired_distance = 2.0
			
	print("im static",areas)
	
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
static func parse(command):
	var parts = command.split(" ")
	if parts.size() == 3 and parts[0].to_lower() == "go" and parts[1].to_lower() == "to":
		var area_name = parts[2]
		go_to_area(area_name)
	elif parts.size() == 3 and parts[0].to_lower() == "\"go" and parts[1].to_lower() == "to":
		var area_name = parts[2]
		print(area_name.left(area_name.length()-1))
		go_to_area(area_name.left(area_name.length()-1))
		
	elif  parts[0].to_lower() == "\"say" and parts[1].to_lower() == "to":
		var targetagent=(parts[2])
		var msg=str(command.right(len(parts[0])+len(parts[1])+len(parts[2])))
		var agentid=0
		#get_parent().get_node(targetagent).somebody_talkingto_you(agentid,msg)
		
	
	elif command=="\"\"":
		pass
	else:
		print("Invalid command: " + command)

static func go_to_area(area):
	if area in areas:
		#target_position = areas[area_name]
		print(areas[area])
		set_movement_target(areas[area])
		#moving = true
	else:
		print("Area not found: " + area)
		
		
static func set_movement_target(movement_target: Vector2):
	pass


