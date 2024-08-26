extends CharacterBody2D

var headers = ["Content-Type: application/json"]
@onready var httpreq = $HTTPRequest
@onready var space_state = get_world_2d().direct_space_state
var agentid 
var POS = global_position
# The port we will listen to
# Our WebSocketServer instance
var port=""
var url = "http://127.0.0.1:"+port
var speed: float = 200.0
var target_position = Vector2()
var moving = false
var areas = {} 
var objeks = {}
var myitems = {}
var listofplaces = {}
var bagofactions = {}
var orientation = 0
var FOV_increment = PI/30
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@onready var objectsnode = $/root/Node2D/objects
@onready var markers_node = $/root/Node2D/Markers
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
var schedule=[]
var beat={}
var buf={}
#var myitems= [{"mydesk":"deskxx","mybed":"bedxx"}]
#var myitems= []
var pushtoheartbeat=[]
var taskruning=0
var taskslist=[]
var place = "street"
var reminderbuffer={}
var reminder=""
var reminderringing=0

#var man = preload("res://Man.gd")
func _on_http_request_request_completed(result, response_code, headers, body):
	#print(body.get_string_from_utf8()) # Replace with function body.
	parse_command_(body.get_string_from_utf8())
	#man.parse(body.get_string_from_utf8())

func _ready():
	# These values need to be adjusted for the actor's speed
	# and the navigation layout.
	#httpreq.request(url)
	
	#var parent_node = get_parent()
	modify_vision_area()
	var objectsnode = $/root/Node2D/objects
	for object in objectsnode.get_children():
		objeks[object.name] = object.position
		
	var markers_node = $/root/Node2D/Markers
	for child in markers_node.get_children():
		if child is Marker2D:
			areas[child.name] = child.position	#navigation_agent.path_desired_distance = 2.0
			print(areas)
	#navigation_agent.target_desired_distance = 2.0
	#navigation_agent.debug_enabled = true
	var wake = {'agent_id':agentid,'heartbeat': 60,'post_type': 'wakeup','home': 'homeB','job':'companyB', 'money':2010}
	var wakeup = JSON.stringify(wake)
	#httpreq.request(url, headers, HTTPClient.METHOD_POST, wakeup)
	if len(schedule)>0:
		setnexttimer(schedule)
	else:
		$ReminderTimer.wait_time=2
		
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
	print(objeks)
	if area in areas:
		#target_position = areas[area_name]
		print(areas[area])
		set_movement_target(areas[area])
		#moving = true
	elif area in objeks:
		
		set_movement_target(objeks[area])
	elif listofplaces.has(area)== true:
		if listofplaces[area] in areas:
			set_movement_target(areas[listofplaces[area]])
		else:
			print("Area not found in your list of places: " + area)
	elif myitems.has(area)== true:
		if objeks.has(myitems[area]) ==true:
			#if objeks[myitems[area]]  in areas:
			set_movement_target(objeks[myitems[area]])
		else:
			print("Area not found in your list items: " + area)		
		
	else:
		print("Area not found: " + area)

func parse_command_(command):
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
		get_parent().get_node(targetagent).somebody_talkingto_you(agentid,msg)
	elif parts[0].to_lower() == "\"operate":
		var machine = parts[1]
		operate(machine.left(machine.length()-1))
		
	elif parts[0].to_lower() == "\"sleep":
		print("finish sleep method")
	elif parts[0].to_lower() == "\"order":
		print("finish order method")
	elif parts[0].to_lower() == "\"eat":
		print("finish eat method")
	elif parts[0].to_lower() == "\"talk":
		print("finish talk method")
	elif parts[0].to_lower() == "\"call":
		print("finish call method")
	elif parts[0].to_lower() == "\"buy":
		print("finish buy method")
	elif parts[0].to_lower() == "\"ask":
		print("finish ask method")
	elif parts[0].to_lower() == "\"find":
		print("finish find method")
	elif parts[0].to_lower() == "\"follow":
		print("finish follow method")
	elif parts[0].to_lower() == "\"train":
		print("finish find method")
	elif parts[0].to_lower() == "\"kill":
		print("finish kill method")
	elif parts[0].to_lower() == "\"steel":
		print("finish steel method")
	elif parts[0].to_lower() == "\"lie":
		print("finish lie method")
	elif parts[0].to_lower() == "\"break":
		print("finish break method")
	elif parts[0].to_lower() == "\"yell":
		print("finish yell method")
	elif parts[0].to_lower() == "\"write":
		print("finish write method")
	elif parts[0].to_lower() == "\"announce":
		print("finish announce method")
		
	elif command=="\"\"":
		pass
	else:
		print("Invalid command: " + command)
		
func operate(machine_name):
	print(myitems[machine_name])
	match machine_name:
		"mydesk":
			latch_to(myitems[machine_name])
		
	


func latch_to(item):
	if item in objeks:
		
		set_movement_target(objeks[item])
	#print("here we should attempt to move on top of the area of the item")
	#pass

						
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

	return points1
		
func _on_vision_timer_timeout():
	var overlaps = $VisionArea.get_overlapping_areas()
	var overlappeople= $VisionArea.get_overlapping_bodies()
	var dic_idx=0
	# modify polygon
	if len(overlaps) > 0:
		print(overlaps)

	if len(overlappeople) >0:
		print(overlappeople)
		
	var visuals = {} # should not be used
	var headers = ["Content-Type: application/json"]
	var visarray=[]
	var actionsdic={}
	var A={} # fordebugging
	var B={}
	var C={}
	var D={}
	if reminderringing==1:
		D=get_parent().pull_reminder_related_actions(reminder)
		reminderringing=0
	
	if len(overlaps)==0 && len(overlappeople)==0:
		#beat = {'agent_id':agentid,'heartbeat': 60,'post_type': 'heartbeat','hunger_level':hunger,'sleep_level':sleep}
		C = get_parent().pull_place_related_actions(place)
		actionsdic[str(dic_idx)]=C
		dic_idx+=1
		actionsdic[str(dic_idx)]=D
		beat = {'agent_id':agentid,'heartbeat': 60,'post_type': 'heartbeat',"actions":  JSON.stringify(actionsdic), "position_name":place,'hunger_level':hunger,'sleep_level':sleep}
		if len(pushtoheartbeat)>0:
			buf= pushtoheartbeat.pop_front()
			for k in buf:
				beat[k]=buf.get(k)
		else:
			pass
		#visuals = JSON.stringify(beat)
		httpreq.request("http://127.0.0.1:"+port, headers, HTTPClient.METHOD_POST, JSON.stringify(beat))
		
	else:
		if len(overlappeople)>0:
			for person in overlappeople:
				#visarray =  visarray + person.get_name()
				visarray.push_back(person.get_name())
			A = get_parent().pull_person_related_actions()
			C = get_parent().pull_place_related_actions(place)
			actionsdic[str(dic_idx)]=A
			dic_idx+=1
			actionsdic[str(dic_idx)]=C
			dic_idx+=1
			actionsdic[str(dic_idx)]=D
			

		if len(overlaps)>0:
			for object in overlaps:
				#visarray =  visarray + object.get_name()
				visarray.push_back(object.get_name().left(-2))
				B = get_parent().pull_object_related_actions(object.get_name().left(-2))
				dic_idx+=1
				actionsdic[str(dic_idx)]=B
				C = get_parent().pull_place_related_actions(place)
				dic_idx+=1
				actionsdic[str(dic_idx)]=C
				dic_idx+=1
				actionsdic[str(dic_idx)]=D
				

		var visarray_string = ", ".join(visarray)
		beat = {'agent_id':agentid,'heartbeat': 60,'post_type': 'UC','you_see':visarray_string,"actions":  JSON.stringify(actionsdic), "position_name":place}
		if len(pushtoheartbeat)>0:
			buf= pushtoheartbeat.pop_front()
			for k in buf:
				beat[k]=buf.get(k)
		else:
			pass
		visuals = JSON.stringify(beat)
		httpreq.request("http://127.0.0.1:"+port, headers, HTTPClient.METHOD_POST, JSON.stringify(beat))
	
func somebody_talkingto_you(talkingagentid,msg):
	
	
	var headers = ["Content-Type: application/json"]
	var situation="Character"+str(talkingagentid)+" is talking to you"
	var talk = {'agent_id':agentid,'heartbeat': 60,'post_type':'comm' ,'situation':situation,'you_hear':msg}
	pushtoheartbeat.push_back({'post_type':'comm' ,'situation':situation,'you_hear':msg})
	#httpreq.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify( {'agent_id':agentid,'heartbeat': 60,'post_type':'comm' ,'situation':situation,'you_hear':msg}))

func setnexttimer(schedule):
	var mytime=get_parent().globaltime
	var nextreminder=1400
	var candidate=0
	var timedef=0
	var c=0
	var cnt=0
	var candidatidx=0
	print(schedule)
	for s in schedule:
		c=int(s.keys()[0])
		timedef= c-mytime
		if timedef<nextreminder && timedef>0:
			candidate = c
			nextreminder=timedef
			candidatidx=cnt
		cnt+=1
	$ReminderTimer.wait_time=(nextreminder)*2
	reminder = schedule[candidatidx][str(candidate)]
	return schedule[candidatidx]

func _on_reminder_timer_timeout():
	reminderbuffer= setnexttimer(schedule) # Replace with function body.
	print(reminderbuffer)
	reminderringing=1
