extends CharacterBody2D
@onready var llm = $LLM
@onready var llmsonnet = $LLMsonnet
#var IDENTITY = """My name is Momo, I am an engineer (a human character/agent in a game). I have an identity, a character, 
#  memory, personality, vitals, a mission life, and a set of values and principles I live by. I have a network 
#  of friends and family. I have a Job and a home. I take decisions in the game based on my past experiences, normally 
#  I follow a calender and a routine. I get inputs from the game regarding my current situation and I choose a decision
#  from my list of actions. The actions sent are in the shape of tuples as provided by the ACTIONS_LIST. Only some of 
#  the actions are available in a specific situation (depending on the situation). You will use the stored list of friends,
#  places and objects to fill the action tuples. Time is also passed so it can be used along with the schedule.
#  Below is the list of actions, rules_to_read_vitals_vector, list of friends and places, schedule and routine, and memory.  
#  Please, return your answer as a JSON dictionary so it can be parsed with the game (only JSON and no headers). 
#  The dictionary fields are -action, -comments (optional: incase if you have explanation or requests from the game deveolper),
#  -new_schedule (optional: in case an update to the schedule or calender is planned),
#  -new_peopleList (optional: incase you want to update known peoples' list) 
#Please, return your answer as a JSON dictionary so it can be parsed with the game (only JSON output and no headers or footers in the response)
#Don't even say: Here is a JSON dictionary with the requested information
#Also, can you output the current schedule of the current day 23rd of september(dont write for the whole week!) in the result JSON, you can make changes ofcourse?"""
# , as shown in the following example: ()
var rules_to_read_vitals_vector = """
Vitals on a scale of 1 to 10 will be feed from the game. there is a set of thresholds based on which you will perceive 
the following:
NeedforFood: {1: full, 6: hungry, 10:super hungry can't focus}
NeedforSleep: {1: awake and fully focused, 5: tired, 7: Sleepy, 10:dizzy and almost fainting}
Endorphins: {1: Depressed, 3:sad, 5:regular, 7:happy, 10: euphoric }
Anger: {3: calm, 8:angry}
"""

var ACTIONS_LIST="""
#Actions are in the form of tuples. It should be a tuple! 
don't leave info like "location" outside the tuple!
what comes after '#' is a comment 

("move to", "location")  #Locations: from list of locations"
("pick up", "item") # item: from list of objects
("say to", "character", "message") # character from list of known people, message is an arbitrary sentence and can be a question
("Note to myself") # this action is used to summarize notes or findings
("buy", "item", "from", "character")
("sell", "item", "to", "character")
("eat", "food")
("sleep at", "location") #location can be bed or desk at office for example
("sit on", "location")  #location can be desk at office for example
("wake up")
("change", "schedule", "to", "new_schedule")
("set", "alarm", "for", "time")
("pay", "amount", "for", "item/service/character")
("work")  # this action can be taken when setting on desk to get thing done
("enjoy") # this action can be taken when setting in front of TV for entertainment
"""

#var PEOPLE_LIST="""
#BELOW IS A LIST OF PEOPLE WITH FIELDS AS FOLLOWS 
#[{"name":"Bob","description":"friend","address":"unknown"},
#{"name":"karen","description":"wife","address":"unknown"},
#{"name":"Mario","description":"boss","address":"unknown"}]
#"""

var PLACEs_LIST="""
[{"home": "apt2"}, {"work":"company1"}, {"Pizza place":"restaurant1"}, {"Barber":"Shop 32"} ]
"""
#var Schedule = {
#  "schedule": {
#	"Monday 23 September": {
#	  "09:00 AM - 12:00 PM": "Work",
#	  "12:00 PM - 01:00 PM": "Break",
#	  "01:00 PM - 06:00 PM": "Work",
#	  "11:00 PM - 06:00 AM": "Sleep"
#	}
#  }
#}
var SUMTask = """ In the context of the following identity I want to summarize 
the below interaction thread in JSON output, so I can keep feeding it to the LLM
, because the thread gets  long and I don't want to lose the details of what happened
 during my day. Please create the output as a JSON with fields:
	 summary, latest schedule, comments, critisizim and evaluationof any unresonable
	 actions, and the last actions taken (in tuple format).
I am planning to parse the new schedule from your response, so also please make it a proper JSON. 
Please, return your answer as a JSON dictionary so it can be parsed with the game (only JSON output and no headers or footers in the response)
Don't even say: Here is a JSON dictionary with the requested information"""
var IDENTITY
var PEOPLE_LIST
var Schedule
var SummaryTask
var TASK_SPECIFIC_INSTRUCTIONS 
@onready var messages 
@onready var summarizationheader
var headers
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
@onready var mytime=get_parent().globaltime
@onready var mytime_hour=get_parent().hours
@onready var mytime_mints=get_parent().minutes
@onready var mytime_ampm=get_parent().am_pm
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
var previousreminder={}
var reminder=""
var reminderringing=0
var UCbuffer=[]
var visarray=[]
var alias
var tau=30
#var man = preload("res://Man.gd")
var closebypeople=[]
signal embedding_completed(embedding: Array)
signal embedding_failed(error: String)
var api_key: String
var vectors: Dictionary = {}  # text -> vector
var metadata: Dictionary = {}  # text -> metadata
signal search_completed(results: Array)
var is_waiting_for_search: bool = false 


func setup(openai_api_key: String):
	api_key =  "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"
func get_embedding(text: String) -> void:
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + api_key
	]
	
	var body = JSON.stringify({
		"model": "text-embedding-3-small",
		"input": text
	})
	#$HTTPRequest.request("https://api.openai.com/v1/embeddings")

	var error = $HTTPRequest.request(
		"https://api.openai.com/v1/embeddings",
		headers,
		HTTPClient.METHOD_POST,
		body
	)
	
	if error != OK:
		embedding_failed.emit("HTTP Request failed")


func import_data(nodename):
	#var filename= "res://"+str(nodename)
	var file = FileAccess.open("res://mypeople.csv",FileAccess.READ)
	
	while !file.eof_reached():
		var data_set = Array(file.get_csv_line())
		if data_set.size()>16:
			if  data_set[16] == nodename:
				IDENTITY=data_set[17]
				PEOPLE_LIST=data_set[18]
				Schedule=data_set[19]
				alias=data_set[2]

	file.close()
	print("crowd loaded")
	
func _on_http_request_request_completed(result, response_code, headers, body):
	#print(body.get_string_from_utf8()) # Replace with function body.
	##parse_command_(body.get_string_from_utf8())
	#man.parse(body.get_string_from_utf8())
	if result != HTTPRequest.RESULT_SUCCESS:
		embedding_failed.emit("Request failed")
		return
		
	if response_code != 200:
		embedding_failed.emit("API returned error: " + str(response_code))
		return
	
	var json = JSON.parse_string(body.get_string_from_utf8())
	if json.has("error"):
		embedding_failed.emit(json["error"]["message"])
		return
	
	var embedding = json["data"][0]["embedding"]
	embedding_completed.emit(embedding)
func _on_search_completed(results: Array):
	print("Search completed with ", results.size(), " results")
	for result in results:
		print("Match: ", result.text, " Score: ", result.score)
func _test_vector_store():
	# Add some texts with metadata
	$VectorStore.add_text("A fun game about space exploration", {"type": "game", "genre": "space"})
	await get_tree().create_timer(2.0).timeout

func _ready():
	# These values need to be adjusted for the actor's speed
	# and the navigation layout.
	#httpreq.request(url)
	
	var nodename =name
	import_data(nodename)
	SummaryTask= ' '.join([SUMTask,IDENTITY])
	TASK_SPECIFIC_INSTRUCTIONS = ' '.join([IDENTITY, ACTIONS_LIST, PEOPLE_LIST, PLACEs_LIST,Schedule])
	messages = [{'role': "user", "content": TASK_SPECIFIC_INSTRUCTIONS},{'role': "assistant", "content": "Understood"}]
	summarizationheader=[{'role': "user", "content": SummaryTask},{'role': "assistant", "content": "Understood"}]
	headers = ["Content-Type: application/json"]
	
	#var parent_node = get_parent()
	modify_vision_area()
	var api_key = "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"
	$VectorStore.setup(api_key)
	$VectorStore.search_completed.connect(_on_search_completed)
	_test_vector_store()
	#var mytime_hour=get_parent().hours
	#var mytime_mints=get_parent().minutes
	var objectsnode = $/root/Node2D/objects
	for object in objectsnode.get_children():
		objeks[object.name] = object.position
		
	var markers_node = $/root/Node2D/Markers
	for child in markers_node.get_children():
		if child is Marker2D:
			areas[child.name] = child.position	#navigation_agent.path_desired_distance = 2.0
			##print(areas)
	#navigation_agent.target_desired_distance = 2.0
	#navigation_agent.debug_enabled = true
	#'time now is':"%02d:%02d" % [mytime_hour, mytime_mints]
	var wake = {'agent_id':agentid,'heartbeat': 60,'post_type': 'wakeup','home': 'homeB','job':'companyB', 'money':2010}
	var wakeup = JSON.stringify(wake)
	
	#httpreq.request(url, headers, HTTPClient.METHOD_POST, wakeup)
	if (messages[-1]["role"])=="assistant":
		llmprocess_user_input(JSON.stringify(wake))
	#if len(schedule)>0:
		#setnexttimer(schedule)
	#else:
		#$ReminderTimer.wait_time=2
		
func llmsummarizer_():
	summarizationheader.append(messages.subarray(1,messages.size()-1))
	var response = await llmsonnet.generate_response(JSON.stringify(summarizationheader))
	var response_text = response.content[0].text
	messages=messages[0]
	messages.append(
			{"role": "assistant", "content": response_text})
			
func llmsummarizer():
	var mzgs
	#summarizationheader.merge(messages.slice(1))
	var sum_messages = summarizationheader + messages
	var response = await llmsonnet.generate_response(JSON.stringify(sum_messages))
	if response.has("Error"):
		print("error, so, waiting " +str(tau) +" secs...")
		get_parent().delay(tau)
		response = await llmsonnet.generate_response(JSON.stringify(sum_messages)) #retry
		var response_json = JSON.parse_string(response.content[0].text)
		var newmsg= {"role": "assistant","connect":JSON.stringify(response_json)}
		mzgs = [messages[0]]+[newmsg]
	else:
		var response_json = JSON.parse_string(response.content[0].text)
		var newmsg= {"role": "assistant","connect":JSON.stringify(response_json)}
		mzgs = [messages[0]]+[newmsg]
	#messages = messages[0]
	#messages.append({"role": "assistant", "content": JSON.stringify(response_text)})
	
	#newmsg.merge(response_json)
	
	#messages.append({"role": "assistant", "content": (response_json["summary"])})
	return mzgs
	
func llmprocess_user_input(input):
	#messages.append({"role":"user", "content":input})
	mytime=get_parent().globaltime
	mytime_hour=get_parent().hours
	mytime_mints=get_parent().minutes
	mytime_ampm=get_parent().am_pm
	if mytime==null:
		return
	messages.append({"role":"user","content":input})
	#messages.append({"role":"user","content":"".join([input," time now is ",str(mytime_hour),":" ,str(mytime_mints),mytime_ampm])})
	
	var msg=JSON.stringify(messages)
	print(msg)
	var response = await llm.generate_response(msg)
	print(response)
	
	while true:
		
		if response.has("Error"):
			# wait 2 seconds
			
			var mzgs=await llmsummarizer()
			
			llm.clear_message_history()
			print("waiting " +str(tau) +" secs...")
			get_parent().delay(tau)
			var responsez = await llm.generate_response(JSON.stringify(mzgs))
			#response = await llm.generate_response(JSON.stringify(JSON.parse_string(JSON.stringify(messages))))
			#print(response)
			#if response.has("Error"):
				#var response2 = await llmsonnet.generate_response(JSON.stringify(messages))
				#print(response2)
				#response=response2
			
			response=responsez
			tau = tau+10
			messages=mzgs
		
		else:
			
			break
		#print("Error: 'content' key not found in response")

	var full_text=(response["content"][0]["text"])
	print(full_text)
	full_text = full_text.replace("(", "[").replace(")", "]")
	var json_data = JSON.parse_string(full_text)
	parse_action(json_data["action"])
	var response_text__= full_text.replace("(", "").replace(")", "")
	#var json_databack=json_data
	if json_data.action is Array:
		json_data.action="".join(json_data.action)
	
	
	
	
	if json_data:
		print("Parsed action:", json_data["action"])
	else:
		print("Failed to parse JSON")
	
	
	
	var response_text = response.content[0].text
	
	messages.append({"role": "assistant", "content": JSON.stringify(json_data)})
	#messages.append({"role": "assistant", "content": response.content[0]})
	#var dict1= {"role": "assistant"}
	#var dict2= response.content[0]
	#dict1.merge(dict2)
	#messages.append(dict1)
	#print(dict1)
	
		
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

func parse_action(command):
	if command[0]=="move" and command[1]=="to":
		go_to_area(command[2]) 
	elif command[0]=="move to":
		go_to_area(command[1]) 
	elif command[0]=="say to":
		if command.size()==3:
			var targetagent= command[1]
			var aliastocharacter={"Karen":"Character2","Bob":"Character1","Mario":"Character3",
			"karen":"Character2","bob":"Character1","mario":"Character3"}
			var agnt = aliastocharacter[targetagent]
			get_parent().get_node(agnt).somebody_talkingto_you(agentid,command[2])
			for person in closebypeople:
				get_parent().get_node(aliastocharacter[person]).youhearsomebody_talking(alias,person,command[2])
			

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
	$Soundarea.global_rotation = orientation
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
	
	var soundoverlaps = $Soundarea.get_overlapping_bodies()
	if soundoverlaps.size()>1:
		
		for obj in soundoverlaps:
			if obj is CharacterBody2D and obj != self:
				closebypeople.append(obj.alias)
		#print(closebypeople)
	

		
	var visuals = {} # should not be used
	var headers = ["Content-Type: application/json"]
	
	var actionsdic={}
	var A={} # fordebugging
	var B={}
	var C={}
	var D={}
	if reminderringing==1:
		D=get_parent().pull_reminder_related_actions(reminder)
		reminderringing=0
	
	if len(overlaps)==0 && len(overlappeople)==0:
		mytime=get_parent().globaltime
		mytime_hour=get_parent().hours
		mytime_mints=get_parent().minutes
		mytime_ampm=get_parent().am_pm
		#beat = {'agent_id':agentid,'heartbeat': 60,'post_type': 'heartbeat','hunger_level':hunger,'sleep_level':sleep}
		C = get_parent().pull_place_related_actions(place)
		actionsdic[str(dic_idx)]=C
		dic_idx+=1
		actionsdic[str(dic_idx)]=D
		#beat = {'agent_id':agentid,'heartbeat': 60,'post_type': 'heartbeat',"actions":  JSON.stringify(actionsdic), "position_name":place,'hunger_level':hunger,'sleep_level':sleep}
		beat = {'agent_id':agentid,'heartbeat': 60,'time':mytime,'post_type': 'heartbeat', "position_name":place,'hunger_level':hunger,'sleep_level':sleep}
		if len(pushtoheartbeat)>0:
			buf= pushtoheartbeat.pop_front()
			for k in buf:
				beat[k]=buf.get(k)
		else:
			pass
		#visuals = JSON.stringify(beat)
		##httpreq.request("http://127.0.0.1:"+port, headers, HTTPClient.METHOD_POST, JSON.stringify(beat))
		#if (messages[-1]["role"])=="assistant":
		
			#llmprocess_user_input(JSON.stringify(beat))
		
	else:
		mytime=get_parent().globaltime
		mytime_hour=get_parent().hours
		mytime_mints=get_parent().minutes
		mytime_ampm=get_parent().am_pm
		if len(overlappeople)>0:
			for person in overlappeople:
				#visarray =  visarray + person.get_name()
				B = add_to_buffers(person)
				#visarray.push_back(person.get_name())
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
				#visarray.push_back(object.get_name().left(-2))
				B = add_to_buffers(object)
				#B = get_parent().pull_object_related_actions(object.get_name().left(-2))
				
				dic_idx+=1
				actionsdic[str(dic_idx)]=B
				C = get_parent().pull_place_related_actions(place)
				dic_idx+=1
				actionsdic[str(dic_idx)]=C
				dic_idx+=1
				actionsdic[str(dic_idx)]=D
				

		var visarray_string = ", ".join(visarray)
		#beat = {'agent_id':agentid,'heartbeat': 60 ,'post_type': 'UC','you_see':visarray_string,"actions":  JSON.stringify(actionsdic), "position_name":place}
		#beat = {'agent_id':agentid,'heartbeat': 60 ,'time now is':"%02d:%02d %s" % [mytime_hour, mytime_mints, mytime_ampm],'post_type': 'UC','you_see':visarray_string, "position_name":place}
		beat= {'info':"".join([" time now is ",str(mytime_hour),":" ,str(mytime_mints),mytime_ampm, ', and you see ', visarray_string,'. Your position is ', place])}
		if len(pushtoheartbeat)>0:
			buf= pushtoheartbeat.pop_front()
			for k in buf:
				beat[k]=buf.get(k)
		else:
			pass
		visuals = JSON.stringify(beat)
		##httpreq.request("http://127.0.0.1:"+port, headers, HTTPClient.METHOD_POST, JSON.stringify(beat))
		if (messages[-1]["role"])=="assistant":
			#llmprocess_user_input(JSON.stringify(beat))
			var report_items = []
			for item in UCbuffer:
				if item[1] == 5:
					item[1] -= 1
					var charname= str(item[0])
					if is_instance_valid(get_parent().get_node(charname)):
						var Alias=get_parent().get_node(charname).alias
						report_items.append(Alias) 
					else:
						report_items.append(item[0])
			if report_items.size()>0:
				print("you see: "+", ".join(report_items))
				print("waiting " +str(tau) +" secs...")
				get_parent().delay(tau)
				llmprocess_user_input("you see: "+", ".join(report_items))
			
func add_to_buffers(object):
	var object_name = object.get_name()#.left(-2)
	
	# Handle visarray buffer
	if object_name not in visarray:
		visarray.append(object_name)
	
	# Handle UCbuffer
	var existing_item = null
	for item in UCbuffer:
		if item[0] == object_name:
			existing_item = item
			break
	
	if existing_item == null:
		UCbuffer.append([object_name, 5])
	
	# Existing functionality
	var B = get_parent().pull_object_related_actions(object_name)
	return B
		
func somebody_talkingto_you(talkingagentid,msg):
	
	var Alias=(get_parent().get_node("Character"+str(talkingagentid)).alias)
	var situation=Alias+" is talking to you."+"You hear "+(msg)
	print("somebody talking and you hear ... waiting " +str(tau) +" secs...")
	get_parent().delay(tau)
	llmprocess_user_input(situation)
	
func youhearsomebody_talking(talkingagent_alias,hearingagent_alias,msg):
	
	#var Alias=(get_parent().get_node("Character"+str(talkingagentid)).alias)
	var situation=talkingagent_alias+" is talking to "+hearingagent_alias+". You hear "+(msg)
	print(situation +" ... waiting " +str(tau) +" secs...")
	get_parent().delay(tau)
	llmprocess_user_input(situation)
	get_parent().delay(tau)
	
func detect_characters_in_range__(radius: float, num_vertices: int = 12) -> Array:
	# Create the circular polygon
	var polygon = PackedVector2Array()
	for i in range(num_vertices):
		var angle = i * 2 * PI / num_vertices
		var point = Vector2(cos(angle), sin(angle)) * radius
		polygon.append(point)
	
	# Create a shape for collision detection
	var shape = CollisionPolygon2D.new()
	shape.polygon = polygon
	
	# Create a temporary Area2D for overlap detection
	var area = Area2D.new()
	area.add_child(shape)
	add_child(area)
	
	# Get all overlapping bodies
	var overlapping_bodies = area.get_overlapping_bodies()
	
	# Filter for CharacterBody2D instances (excluding self)
	var characters_in_range = []
	for body in overlapping_bodies:
		if body is CharacterBody2D and body != self:
			characters_in_range.append(body)
	
	# Clean up
	area.queue_free()
	
	return characters_in_range
	
func setnexttimer(schedule):
	mytime=get_parent().globaltime
	if mytime == null:
		print("we have a problem")
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
	#$ReminderTimer.stop()
	#$ReminderTimer.start()
	
	#if (messages[-1]["role"])=="assistant":
		
		#if messages.size()>30:
		#	var mzgs=await llmsummarizer()
		#	messages=mzgs
		
		llmprocess_user_input("".join(["I am looking at my watch to decide what to do next, time now is ",str(mytime_hour),":" ,str(mytime_mints),mytime_ampm]))

	#reminderbuffer= setnexttimer(schedule) # Replace with function body.
	#if previousreminder != reminderbuffer:
		
	#	llmprocess_user_input(reminderbuffer)
	#	previousreminder = reminderbuffer
	#	print(reminderbuffer)
	#	reminderringing=1
