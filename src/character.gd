extends CharacterBody2D

var headers = ["Content-Type: application/json"]
@onready var httpreq = $HTTPRequest
@onready var space_state = get_world_2d().direct_space_state
var agentid = 1
var POS = global_position
# The port we will listen to
const port = 9088
# Our WebSocketServer instance
const url = "http://127.0.0.1:8001"
var speed: float = 200.0
var target_position = Vector2()
var moving = false
var areas = {} 
var orientation = 0
var FOV_increment = PI/30
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@onready var trnsform1 = Transform2D()
@onready var trnsform2 = Transform2D()
####	# personal charcteristics 
#vitals
var hunger = 0 #level
var sleep = 0 #level
var sickness = 0
# info
var home= ""
var job = ""
var money = 0
var hobbies = ""
var family= ""
var friends = ""

func _on_http_request_request_completed(result, response_code, headers, body):
	print(body.get_string_from_utf8()) # Replace with function body.

func _ready():
	# These values need to be adjusted for the actor's speed
	# and the navigation layout.
	#httpreq.request(url)
	
	var parent_node = get_parent()
	for child in parent_node.get_children():
		if child is Marker2D:
			areas[child.name] = child.position	#navigation_agent.path_desired_distance = 2.0
			print(areas)
	#navigation_agent.target_desired_distance = 2.0
	#navigation_agent.debug_enabled = true
	var wake = {'agent_id':agentid,'heartbeat': 70,'post_type': 'wakeup','home': 'homeA','job':'companyA', 'money':1010}
	var wakeup = JSON.stringify(wake)
	httpreq.request(url, headers, HTTPClient.METHOD_POST, wakeup)



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

func parse_command_(command):
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
	
	orientation = ((next_path_position-current_agent_position).angle()  )#/PI *180)
	#print((next_path_position-current_agent_position).angle())
	#$VisionArea/CollisionPolygon2D.rotate(rotation)
	velocity = current_agent_position.direction_to(next_path_position) * speed
	move_and_slide()
	$VisionArea.global_rotation = orientation
	#global_rotation = orientation
	modify_vision_area()
	

func modify_vision_area():
	#var pos = $/root/Node2D/Character.global_position
	#var points = PackedVector2Array()
	#points.append(Vector2)
	#get_FOV($/root/Node2D/Character.global_position,300)
	var points1=get_FOV()
	$VisionArea/visionpolygon.polygon=points1
	$VisionArea/collisionvision.polygon=points1
	#print(fov)
	#set_vision_area(fov)
	
func draw_vision_area():
	var pos = $/root/Node2D/Character.global_position
	var points = PackedVector2Array()
	#points.append(Vector2)
	#var fov=get_FOV($/root/Node2D/Character.global_position,300)
	#print(fov)
	#set_vision_area(fov)
	
func get_FOV():
	#var angle = FOV_increment
	
	var pointsref = $VisionArea/visionpolygonref.polygon
	var points1 = $VisionArea/visionpolygon.polygon
	points1=pointsref
	
	#print(global_position)
	#print(points1)
	#var points2 = $VisionArea/collisionvision.polygon
	#var angle: float
	var rot = -orientation # The rotation to apply.
	trnsform1.x.x = cos(rot)
	trnsform1.y.y = cos(rot)
	trnsform1.x.y = sin(rot)
	trnsform1.y.x = -sin(rot)
	#var transform1 = trnsform1

	# Rotation
	var rot2 = +orientation # The rotation to apply.
	trnsform2.x.x = cos(rot2)
	trnsform2.y.y = cos(rot2)
	trnsform2.x.y = sin(rot2)
	trnsform2.y.x = -sin(rot2)
	#var transform2 = t2
	var inc=0
	for point in pointsref:
		
		var query = PhysicsRayQueryParameters2D.create((global_position), (global_position+ point*trnsform1) ,1)
		#var query = PhysicsRayQueryParameters2D.create(POS, POS + point,1)
		var collision = get_world_2d().direct_space_state.intersect_ray(query)
		if collision == {}:
			points1[inc]= pointsref[inc] 
	#		points2[inc]= pointsref[inc] 
		else:
			var newpoint= collision["position"]-global_position
			#print([(global_position),(point),  collision["position"]-global_position])
			
			points1[inc]= newpoint*trnsform2
	#		points2[inc]= newpoint
			
		inc+=1
	#print(points1)
	
	#if ray_cast1.is_colliding():
	#var col_point1=round(ray_cast1.get_collision_point())
	#points1[1]= round(col_point1-global_position)
	##if ray_cast2.is_colliding():
	#var col_point2=round(ray_cast2.get_collision_point())
	#points1[2]= round((col_point2)-global_position)
	##if ray_cast3.is_colliding():
	#var col_point3=round(ray_cast3.get_collision_point())
	#points1[3]= round((col_point3)-global_position)
	#if ray_cast4.is_colliding():
		#var col_point4=round(ray_cast4.get_collision_point())
		#points1[4]= round((col_point4)-global_position)
	#if ray_cast1.is_colliding():
		#var col_point5=round(ray_cast5.get_collision_point())
		#points1[5]= round((col_point5)-global_position)
	#if ray_cast6.is_colliding():
		#var col_point6=round(ray_cast6.get_collision_point())
		#points1[6]= round((col_point6)-global_position)
	#if ray_cast7.is_colliding():
		#var col_point7=round(ray_cast7.get_collision_point())
		#points1[7]= round((col_point7)-global_position)
	#if ray_cast8.is_colliding():
		#var col_point8=round(ray_cast8.get_collision_point())
		#points1[8]= round((col_point8)-global_position)
	#if ray_cast9.is_colliding():
		#var col_point9=round(ray_cast9.get_collision_point())
		#points1[9]= round((col_point9)-global_position)
		
	#print(points1)	
	return points1
		
func set_vision_area(points: PackedVector2Array):
	var godot_blue : Color = Color("478cbf")
	#$VisionArea/visionpolygon.draw_polygon(points,[godot_blue])
	$VisionArea/visionpolygon.set("polygon",points)
#	$VisionArea/collisionvision.draw_polygon(points)
	


func _on_vision_timer_timeout():
	var overlaps = $VisionArea.get_overlapping_areas()
	
	# modify polygon
	if len(overlaps) > 0:
		print(overlaps)
		
	var data_to_send = {'long': 23.0,'lat': 324.0,'userinfo': '24' }
	var json = JSON.stringify(data_to_send)
	var headers = ["Content-Type: application/json"]

