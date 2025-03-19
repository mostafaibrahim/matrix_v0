extends Node

# The port we will listen to
const PORT = 9080
# Our WebSocketServer instance
var crowd = {}
@onready var globaltime = 360 #make increments of 60
var hours =4
var minutes =50
var am_pm ="am"
var onetimesaved=false
var onetimesaved2=false
var json = JSON.new()
@onready var holdAPI_1=false
# Dictionary to track how many times each agent has been denied
var denial_counts = {}
# Queue of waiting agents sorted by denial count
var waiting_queue = []
var holdingagent
var onetime=false
func holdapi_request(agentid):
	if not agentid in denial_counts:
		denial_counts[agentid] = 0
	if agentid==holdingagent and onetime==false:
		onetime=true
		return true
	if holdAPI_1==false:
		#holdingagent=agentid
		#holdAPI_1=true
		#denial_counts[agentid] = 0
		#OS.delay_msec(10000)
		grant_access(agentid)
		return true
		
	else:
		# Add to waiting queue if not already waiting
		if not agentid in waiting_queue:
			waiting_queue.append(agentid)
			# Sort queue by denial count (highest first)
			waiting_queue.sort_custom(Callable(self, "sort_by_denial_count"))
		
		# Increment denial count
		denial_counts[agentid] += 1
		return false


# Custom sort function for the waiting queue
func sort_by_denial_count(a, b):
	return denial_counts[a] > denial_counts[b]
func grant_access(agentid):
	holdingagent = agentid
	holdAPI_1 = true
	# Reset denial count when access is granted
	denial_counts[agentid] = 0
	OS.delay_msec(10000)
# Helper function to get queue status (for debugging)
func get_queue_status():
	var status = "Current holder: " + str(holdingagent) + "\n"
	status += "Waiting queue: " + str(waiting_queue) + "\n"
	status += "Denial counts: " + str(denial_counts)
	print("Queue Status:   "+ status)
	return status
func unholdapi_request(agentid):
	if holdAPI_1==true and holdingagent==agentid:
		onetime=false
		holdAPI_1 = false
		holdingagent = null
		OS.delay_msec(10000)
		#get_tree().paused = false
		if waiting_queue.size() > 0:
			var next_agent = waiting_queue.pop_front()
			grant_access(next_agent)
	
		if globaltime>900 and onetimesaved==false:
			$Character1.POS=$Character1.global_position
			$Character2.POS=$Character2.global_position
			$Character3.POS=$Character3.global_position
			create_global_checkpoint("fthcheckPT")
			$Character1.create_checkpoint("fthcheckPT")
			$Character2.create_checkpoint("fthcheckPT")
			$Character3.create_checkpoint("fthcheckPT")
			$L2assistant.create_checkpoint("fthcheckPT")
			$L3assistant.create_checkpoint("fthcheckPT")
			onetimesaved=true
			"""
		if globaltime>7000 and onetimesaved2==false:
			$Character1.POS=$Character1.global_position
			$Character2.POS=$Character2.global_position
			$Character3.POS=$Character3.global_position
			create_global_checkpoint("fivthcheckPT")
			$Character1.create_checkpoint("fivthcheckPT")
			$Character2.create_checkpoint("fivthcheckPT")
			$Character3.create_checkpoint("fivthcheckPT")
			onetimesaved2=true
		if globaltime>900 and onetimesaved2==false:
			$Character1.POS=$Character1.global_position
			$Character2.POS=$Character2.global_position
			$Character3.POS=$Character3.global_position
			create_global_checkpoint("sixthcheckPT")
			$Character1.create_checkpoint("sixthcheckPT")
			$Character2.create_checkpoint("sixthcheckPT")
			$Character3.create_checkpoint("sixthcheckPT")
			onetimesaved2=true """
		
		
		

func _ready():
	#$Player1.init_network(12345)  # Assign unique ports to each player
	#$Player2.init_network(12346)
	# Add more players as needed
	var agents=["Character1","Character2","Character3"]
	var bagofactions= {"go to":"$place","sleep on":"$bed","eat":"$food","say to":"$agent $scentence","buy":"$itemlist" ,\
	"cook":"dinner","order":"$itemlist","talk with":"$agent","operate":"$tool"}
	#$Character1/Camera2D/Label.text=str(globaltime)
	import_data()
	print(crowd.size())
	#print(crowd[0]["hunger"])
	print(crowd[1][1])
	
	var inc=0
	for agent in agents:
		inc +=1
		get_node(agent).agentid = int(crowd[inc][0])
		get_node(agent).port = crowd[inc][1]
		#get_node(agent).name = crowd[inc][2]
		get_node(agent).speed = float(crowd[inc][3])
		get_node(agent).money = (crowd[inc][4])
		get_node(agent).hunger = int(crowd[inc][5])
		get_node(agent).sleep = int(crowd[inc][6])
		get_node(agent).sickness = int(crowd[inc][7])
		get_node(agent).home = crowd[inc][8]
		get_node(agent).job = crowd[inc][9]
		get_node(agent).hobbies = crowd[inc][10]
		get_node(agent).friends = crowd[inc][11]
		get_node(agent).family = crowd[inc][12]
		#print((crowd[inc][14]))
		#var sched_line=(crowd[inc][14])
		#print(parse_list_(line))
		get_node(agent).listofplaces = parse_dic_(crowd[inc][13])
		get_node(agent).schedule = parse_list_(crowd[inc][14])
		get_node(agent).myitems = parse_dic_(crowd[inc][15])
		get_node(agent).bagofactions = bagofactions
	
	
func parse_list_(line):
	var list=[]
	var parts = line.split(",")
	for p in parts:
		#print(p)
		list.append(JSON.parse_string(p))
	return list
	
func parse_dic_(line):
	var dic={}
	var jsonstr
	var parts = line.split(",")
	for p in parts:
		jsonstr=JSON.parse_string(p)
		dic.merge(jsonstr)
	return dic
	
func import_data():
	var file = FileAccess.open("res://mypeople.csv",FileAccess.READ)
	
	while !file.eof_reached():
		var data_set = Array(file.get_csv_line())
		crowd[crowd.size()]= data_set
	file.close()
	print("crowd loaded")
	
func pull_tasks_tree(action):
	var tree={}
	match action:
		"go to work":
			tree={"0":"operate mydesk",\
			 "1":{"0":"walk to work_address","1":"drive to work_address","2":"taxi to work_address"},\
			"2":{ "0":"finish_current_task","1":"interrupt_current_task"} }
		"go eat":
			tree = {"0":"eat","1":{"0":"cook","1":"order_from_list","2":"take prepared food"},\
			"2":{"0":"go to home" , "1":"go to restaurant"},\
			"3":{ "0":"finish_current_task","1":"interrupt_current_task"}}
		"go sleep":
			tree = {"0":"sleep","1":"findbed","2":{"0":"walk to home_address","1":"drive to home_address"},\
			"3":{ "0":"finish_current_task","1":"interrupt_current_task"}}
		"go fun":
			tree = {"0":"enjoy"}
			
	return tree
func pull_reminder_related_actions(reminder):
	var object_actions={}
	match reminder:
		"work":
			object_actions={"go to work":"fom x to y"}
		"wakeup":
			object_actions={"wake up routine":"fom x to y"}
		"sleep":
			object_actions={"sleep routine":"fom x to y"}
	return object_actions
func pull_person_related_actions():
	var person_actions={"say to":"talk to, mention something or ask about something",\
	 "buy": "take something he owns for money",\
	"sell": "give something you own for money"}
	return person_actions
	
func pull_object_related_actions(object):
	var object_actions={}
	match object:
		"bed":
			object_actions={"sleep":"fom x to y"}
		"desk":
			object_actions={"sit and work":"fom x to y"}
		"door":
			object_actions={"open":"if authorized"}
			
	return object_actions
					
		
func pull_place_related_actions(place):
	var place_actions={}
	match place:
		"restaurant", "cafe":
			place_actions={"order":"from menue and pay", "pull menue":"it will send a list with prices and calories", "go to":"place"}
		"shop", "grocery", "market":
			place_actions={"order":"from list and pay","go to":"place"}
		"work" , "company":
			place_actions={"work":"from x to y","go to":"place"}
		"apartement" , "home":
			place_actions={"go to bed":"same as sleep","cook":"use ingradients you have",\
		 "watch TV":"from x to y","go to":"place"}
		"street":
			place_actions={"call a friend":"from list of friends", "go to":"place", "call 911":"call goes to ppolice"}
		
	return place_actions


func resedentialcount():
	var koko=$places/resedential_areas.get_overlapping_bodies()  # Replace with function body.
	var karlist=[]
	for ko in koko:
		if ko.get_class() ==  "CharacterBody2D":
			karlist.push_back(ko.get_name())
			ko.place="apartement"
	if len(karlist)>0:
		print("people in resedential area:" + str(karlist))
		
func companycount(node):
	var koko=node.get_overlapping_bodies()  # Replace with function body.
	var karlist=[]
	for ko in koko:
		if ko.get_class() ==  "CharacterBody2D":
			karlist.push_back(ko.get_name())
			ko.place=node.get_name()
	if len(karlist)>0:
		print("people in company area:" + str(karlist))
func streetcount(node):
	var koko=node.get_overlapping_bodies()  # Replace with function body.
	var karlist=[]
	for ko in koko:
		if ko.get_class() ==  "CharacterBody2D":
			karlist.push_back(ko.get_name())
			ko.place=node.get_name()
	if len(karlist)>0:
		print("people in the street:" + str(karlist))

func _on_cityclock_timeout():
	globaltime+=30
	hours = floor(globaltime / 60)
	minutes = int(globaltime) % 60
	if hours<12:
		am_pm="am"
	elif hours==12:
		am_pm="pm"
	else:
		am_pm="pm"
		hours=hours-12
		
	if globaltime == 1440:
		globaltime=0
		
	
		
	
		
	
	$Camera2D/Label.text = "%02d:%02d" % [hours, minutes]
	#$Character1/Camera2D/Label.text=str(globaltime)

func _on_resedential_areas_body_entered(body):
	resedentialcount()
func _on_company_2_body_entered(body):
	companycount($places/company2)
func _on_company_1_body_entered(body):
	companycount($places/company1)
func _on_street_body_entered(body):
	streetcount($places/street)
	
func delay(tau):
	print("delaycanceled")
	#get_tree().paused = true
	#await get_tree().create_timer(tau).timeout 
	#get_tree().paused = false
	
	
## Creates a checkpoint of the current global state with a custom name.
## Returns true if successful, false otherwise.
##
## [param checkpoint_name] The name of the checkpoint.
func create_global_checkpoint(checkpoint_name: String) -> bool:
	var checkpoint_path = "res://savedcheckpoints/global_" + checkpoint_name + ".save"
	
	# Create the save data dictionary
	var save_data = {
		# Time-related variables
		"globaltime": globaltime,
		"hours": hours,
		"minutes": minutes,
		"am_pm": am_pm,
		
		# Agent holding states
		"holdAPI_1": holdAPI_1,
		"holdingagent": holdingagent,
		
		# Add timestamp for reference
		"timestamp": Time.get_unix_time_from_system()
	}
	
	# Convert to JSON string
	var json_string = JSON.stringify(save_data)
	
	# Save to file
	var file = FileAccess.open(checkpoint_path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open file for saving: " + checkpoint_path)
		return false
	
	file.store_string(json_string)
	print("Global state checkpoint created: ", checkpoint_name)
	return true

## Loads a specific global checkpoint by name.
## Returns true if successful, false otherwise.
##
## [param checkpoint_name] The name of the checkpoint to load.
func load_global_checkpoint(checkpoint_name: String) -> bool:
	var checkpoint_path = "res://savedcheckpoints/global_" + checkpoint_name + ".save"
	
	# Check if file exists
	if not FileAccess.file_exists(checkpoint_path):
		push_error("Global checkpoint file does not exist: " + checkpoint_path)
		return false
	
	# Read file
	var file = FileAccess.open(checkpoint_path, FileAccess.READ)
	if file == null:
		push_error("Failed to open checkpoint file for loading: " + checkpoint_path)
		return false
	
	var json_string = file.get_as_text()
	
	# Parse JSON
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		push_error("Failed to parse checkpoint file")
		return false
	
	var save_data = json.get_data()
	
	# Restore state
	globaltime = save_data.get("globaltime", globaltime)
	hours = save_data.get("hours", hours)
	minutes = save_data.get("minutes", float(minutes))
	am_pm = save_data.get("am_pm", am_pm)
	holdAPI_1 = save_data.get("holdAPI_1", holdAPI_1)
	holdingagent = save_data.get("holdingagent", holdingagent)
	
	print("Global checkpoint loaded: ", checkpoint_name)
	return true

## Lists all available global checkpoints.
## Returns an array of checkpoint names.
func list_global_checkpoints() -> Array:
	var checkpoints = []
	var dir = DirAccess.open("user://")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.begins_with("global_") and file_name.ends_with(".save"):
				checkpoints.append(file_name.trim_prefix("global_").trim_suffix(".save"))
			file_name = dir.get_next()
	return checkpoints

## Deletes a global checkpoint by name.
## Returns true if successful, false otherwise.
##
## [param checkpoint_name] The name of the checkpoint to delete.
func delete_global_checkpoint(checkpoint_name: String) -> bool:
	var checkpoint_path = "user://global_" + checkpoint_name + ".save"
	if FileAccess.file_exists(checkpoint_path):
		var err = DirAccess.remove_absolute(checkpoint_path)
		if err == OK:
			print("Global checkpoint deleted: ", checkpoint_name)
			return true
		else:
			push_error("Failed to delete global checkpoint: " + checkpoint_name)
	return false

## Creates a checkpoint with the current time as name.
## Returns the checkpoint name if successful, empty string otherwise.
func quick_save() -> String:
	var timestamp = Time.get_datetime_string_from_system().replace(":", "-")
	var checkpoint_name = "quicksave_" + timestamp
	if create_global_checkpoint(checkpoint_name):
		return checkpoint_name
	return ""

## Gets information about a specific checkpoint.
## Returns a dictionary with checkpoint info or an empty dictionary if checkpoint doesn't exist.
func get_checkpoint_info(checkpoint_name: String) -> Dictionary:
	var checkpoint_path = "user://global_" + checkpoint_name + ".save"
	
	if not FileAccess.file_exists(checkpoint_path):
		return {}
	
	var file = FileAccess.open(checkpoint_path, FileAccess.READ)
	if file == null:
		return {}
	
	var json = JSON.new()
	var parse_result = json.parse(file.get_as_text())
	if parse_result != OK:
		return {}
	
	var save_data = json.get_data()
	
	return {
		"name": checkpoint_name,
		"time": str(save_data.hours) + ":" + str(save_data.minutes) + " " + save_data.am_pm,
		"globaltime": save_data.globaltime,
		"created": Time.get_datetime_string_from_unix_time(save_data.timestamp),
		"has_held_agent": save_data.holdingagent != null
	}


func _on_loadtimer_timeout():
	pass
	#load_global_checkpoint("fivthcheckPT")
	#$Character1.load_checkpoint("fivthcheckPT")
	#$Character2.load_checkpoint("fivthcheckPT")
	#$Character3.load_checkpoint("fivthcheckPT")# Replace with function body.
