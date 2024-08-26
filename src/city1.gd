extends Node

# The port we will listen to
const PORT = 9080
# Our WebSocketServer instance
var crowd = {}
var globaltime = 0

var json = JSON.new()


func _ready():
	#$Player1.init_network(12345)  # Assign unique ports to each player
	#$Player2.init_network(12346)
	# Add more players as needed
	var agents=["Character1","Character2","Character3"]
	var bagofactions= {"go to":"$place","sleep on":"$bed","eat":"$food","say to":"$agent $scentence","buy":"$itemlist" ,\
	"cook":"dinner","order":"$itemlist","talk with":"$agent","operate":"$tool"}
	$Character1/Camera2D/Label.text=str(globaltime)
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
	if globaltime == 1440:
		globaltime=0
	$Character1/Camera2D/Label.text=str(globaltime)

func _on_resedential_areas_body_entered(body):
	resedentialcount()
func _on_company_2_body_entered(body):
	companycount($places/company2)
func _on_company_1_body_entered(body):
	companycount($places/company1)
func _on_street_body_entered(body):
	streetcount($places/street)
