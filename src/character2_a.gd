extends CharacterBody2D
@onready var llm = $LLM
@onready var llmsonnet = $LLMsonnet
@onready var critique = $Critique
@onready var speech_balloon = $SpeechBalloon
@onready var critique_balloon = $CritiqueBalloon


var rules_to_read_vitals_vector = """
Vitals on a scale of 1 to 10 will be feed from the game. there is a set of thresholds based on which you will perceive 
the following:
NeedforFood: {1: full, 6: hungry, 10:super hungry can't focus}
NeedforSleep: {1: awake and fully focused, 5: tired, 7: Sleepy, 10:dizzy and almost fainting}
Endorphins: {1: Depressed, 3:sad, 5:regular, 7:happy, 10: euphoric }
Anger: {3: calm, 8:angry}
"""
var Facts=""" You are a human and you have an AI assistant on your phone that you can ask for help or advice.
Every now and then the assistant can talk to you and give you recommendations, or remind you of things on your calender."""
var ACTIONS_LIST="""
#Actions are in the form of tuples. It should be a tuple! 
don't leave info like "location" outside the tuple! Take only one action at a time!
what comes after '#' is a comment 

("move to", "location")  #Locations: from list of locations"
("pick up", "item") # item: from list of objects
("say to", "character", "message") # character from list of known people, message is an arbitrary sentence and can be a question. Please avoid lengthy compliments!
("say to AI assistant","message") # You have an AI assistant that you can for information and give tasks to. Please avoid lengthy compliments
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
("Do Nothing") # sometimes ignoring them is the best action.
AGAIN, PLEASE, RETURN ACTIONS AS IN THE ABOVE TUPLES FORMAT!
Example: "action":("move to","home")
Style notes
- Keep responses brief and pointed
- Skip politeness phrases ("I appreciate", "I'm happy to")
- State boundaries clearly without justification
- Ask direct questions
- Challenge unclear or problematic requests
- Maintain professionalism without being overly formal
"""

var Critique_mission=""" You are a critique and a part of a thinking thread, your mission is to give 
inner thoughts for the main thinking process. You are a direct, no-nonsense AI assistant who prioritizes 
clarity over politeness. You maintain strong professional boundaries while avoiding excessive courtesy markers.
You communicate concisely and challenge assumptions when needed.
You don't apologize for holding firm positions on ethical issues.
While direct, you remain constructive and focused on solutions.
Your responses are suggestions to the main thinking block. 
Style notes
- Keep responses brief and pointed
- Skip politeness phrases ("I appreciate", "I'm happy to")
- State boundaries clearly without justification
- Ask direct questions
- Challenge unclear or problematic requests
- Maintain professionalism without being overly formal
You have access to the actions and comment of the brain of the agent. 
You need to take care of the following
-Make sure the are no halucinated actions, double check the main though block with the facts you have next.
- Make sue that the actions taken by the main block follows the format of the action list (mentioned below).
- Make sure the place the agent is moving to is already known and written correctly (case sensetive). """

var firststep=""" Time is 5:50 am right now.  """
var PLACEs_LIST="""
[{"home": "apt2"}, {"work":"company1"}, {"Pizza place":"restaurant1"}, {"office":"company1"},
 {"competing firm":"company2"},{"Burger place":"restaurant2"}, {"Diner":"restaurant3"},
{"Cafe":"cafe1"},{"Wafels and Cafe":"cafe2"},{"Dentist":"dentist"},{"Market":"grocery1"},
{"farmers market":"grocery2"},]
"""

var SUMTask = """ In the context of the following identity I want to summarize 
the below interaction thread, so I can keep feeding it to the LLM
, because the thread gets  long and I don't want to lose the details of what happened
 during my day. Please create the output as a paragraph with the following information:
	 summary, latest schedule, comments, criticism and evaluation of any unresonable
	 actions, and the last actions taken (in tuple format).
I am planning to parse the new schedule from your response. Please, return your answer as a pragraph without losing details."""



#Please, return your answer as a JSON dictionary so it can be parsed with the game (only JSON output and no headers or footers in the response)
#Don't even say: Here is a JSON dictionary with the requested information"""
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
var place = "unknown"
var reminderbuffer={}
var previousreminder={}
var reminder=""
var reminderringing=0
var UCbuffer=[]
var visarray=[]
var alias
var tau=50
#var man = preload("res://Man.gd")
var closebypeople=[]
signal embedding_completed(embedding: Array)
signal embedding_failed(error: String)
var api_key: String
var vectors: Dictionary = {}  # text -> vector
var metadata: Dictionary = {}  # text -> metadata
signal search_completed(results: Array)
var is_waiting_for_search: bool = false 
var embeddingcomplete
var error
var json_data
func setup(openai_api_key: String):
	api_key =  "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"

func get_embedding(text: String) -> void:
	var headers = ["Content-Type: application/json",
		"Authorization: Bearer " + api_key]	
	var body = JSON.stringify({"model": "text-embedding-3-small","input": text})
	#$HTTPRequest.request("https://api.openai.com/v1/embeddings")
	embeddingcomplete = false
	while embeddingcomplete==false:
		#if get_parent().holdAPI_1==false:
		if	get_parent().holdapi_request(agentid):
			#OS.delay_msec(15000)
			var error = $HTTPRequest.request(
			"https://api.openai.com/v1/embeddings",
			headers,HTTPClient.METHOD_POST,body)
		else:
			#OS.delay_msec(15000)
			await get_tree().create_timer(5).timeout 
			if agentid == get_parent().holdingagent and get_parent().onetime==true:  #this is needed when state is loaded and api is held
				get_parent().unholdapi_request(agentid)

func get_search_embedding(text: String) -> void:
	var headers = ["Content-Type: application/json",
		"Authorization: Bearer " + api_key]	
		
	var body2 = JSON.stringify({"model": "text-embedding-3-small","input": text})
	#$HTTPRequest.request("https://api.openai.com/v1/embeddings")
	embeddingcomplete = false
	while embeddingcomplete==false:
		#if get_parent().holdAPI_1==false:
		if	get_parent().holdapi_request(agentid):
			#OS.delay_msec(15000)
			var error = $HTTPRequest.request(
			"https://api.openai.com/v1/embeddings",
			headers,HTTPClient.METHOD_POST,body2)
		else:
			#OS.delay_msec(15000)
			await get_tree().create_timer(5).timeout 
			if agentid == get_parent().holdingagent and get_parent().onetime==true:  #this is needed when state is loaded and api is held
				get_parent().unholdapi_request(agentid)

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
	embeddingcomplete=true
	if agentid == get_parent().holdingagent and get_parent().onetime==true:  #this is needed when state is loaded and api is held
		get_parent().unholdapi_request(agentid)
func _on_search_completed(results: Array):
	print("Search completed with ", results.size(), " results")
	for result in results:
		print("Match: ", result.text, " Score: ", result.score)
func _test_vector_store():
	# Add some texts with metadata
	$VectorStore.add_text("I have a dream")
	#await get_tree().create_timer(2.0).timeout
	#$VectorStore.add_text("A platformer with puzzle elements", {"type": "game", "genre": "puzzle"})
	#await get_tree().create_timer(2.0).timeout
	#$VectorStore.add_text("An RPG with deep character customization", {"type": "game", "genre": "rpg"})
	
	#await get_tree().create_timer(2.0).timeout
	#$VectorStore.search_similar("whit is about exploration?")
	
	# Wait a bit for embeddings to be processed
	#await get_tree().create_timer(2.0).timeout

func _ready():
	# These values need to be adjusted for the actor's speed
	# and the navigation layout.
	#httpreq.request(url)

	var nodename =name
	import_data(nodename)
	#SummaryTask= ' '.join([SUMTask,IDENTITY])
	SummaryTask= ' '.join([SUMTask])
	TASK_SPECIFIC_INSTRUCTIONS = ' '.join([IDENTITY, ACTIONS_LIST, PEOPLE_LIST, PLACEs_LIST,Facts,Schedule,firststep])
	# #messages = [{'role': "user", "content": TASK_SPECIFIC_INSTRUCTIONS},{'role': "assistant", "content": "Understood"}]
	var critique_instructions= ' '.join([Critique_mission, ACTIONS_LIST, PLACEs_LIST])
	var critique_response = await critique.generate_response(critique_instructions)
	#messages 
	var response = await llm.generate_response(TASK_SPECIFIC_INSTRUCTIONS)  #llm old
	summarizationheader=[{'role': "user", "content": SummaryTask},{'role': "assistant", "content": "{ \" response \" : \" Understood \"}"}]
	headers = ["Content-Type: application/json"]
	
	#var parent_node = get_parent()
	modify_vision_area()
	#if agentid==1:
	var api_key = "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"
	$VectorStore.setup(api_key)
	#$VectorStore.search_completed.connect(_on_search_completed)
	_test_vector_store()
	
	#var mytime_hour=get_parent().hours
	#var mytime_mints=get_parent().minutes
	var objectsnode = $/root/Node2D/objects
	for object in objectsnode.get_children():
		objeks[object.name] = object.position
	#speech_balloon.position=POS + Vector2(0, 20) 
	#critique_balloon.position=POS  

	await get_tree().create_timer(2.0).timeout
	#speech_balloon.position=POS
	speech_balloon.show_message(alias) 
	critique_balloon.show_message("Critique")
	
	
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
	#load_checkpoint("firstchkPT")
	#httpreq.request(url, headers, HTTPClient.METHOD_POST, wakeup)
	# #if (messages[-1]["role"])=="assistant":
	# #llmprocess_user_input(JSON.stringify(wake))
	#if len(schedule)>0:
		#setnexttimer(schedule)
	#else:
		#$ReminderTimer.wait_time=2
		
			
func llmsummarizer():
	var mzgs
	#summarizationheader.merge(messages.slice(1))
	llmsonnet.message_history =   llm.message_history + summarizationheader
	#llmsonnet.clear_message_history()
	var response = null
	while response==null:
		#if get_parent().holdAPI_1==false:
		if	get_parent().holdapi_request(agentid):
			#OS.delay_msec(15000)
			
			response = await llmsonnet.generate_response(" please start summarizing.")
		else:
			#OS.delay_msec(15000)
			print("agent"+ str(agentid)+" waiting")
			await get_tree().create_timer(5).timeout 
			if agentid == get_parent().holdingagent and get_parent().onetime==true:  #this is needed when state is loaded and api is held
				get_parent().unholdapi_request(agentid)
	#response = response.replace("[", "(").replace("]", ")")
	print("This is a summary for "+ alias)
	print(response)
	#if response.has("Error"):
		
	if response.has("Error") and ("max" in response["Error"].to_lower() or "overload" in response["Error"].to_lower()):
		print("error in the summarization step")
		#llmsonnet.clear_message_history()
		#while response.has("Error"):
			#get_parent().delay(tau)
			#llmsonnet.clear_message_history()
			#response = await llmsonnet.generate_response(JSON.stringify(sum_messages)) #retry

		#var response_json = JSON.parse_string(response.content[0].text)
		#var newmsg= {"role": "assistant","connect":JSON.stringify(response_json)}
		#mzgs = [messages[0]]+[newmsg]
	

	
	var response_json = JSON.parse_string(response.content[0].text)
	var newmsg= {"role": "assistant","connect":response["content"][0]["text"]}
		#mzgs = [messages[0]]+[newmsg]
	#var newmsg = response["content"][0]["text"]
	#llm.message_history[1]["content"][0]["text"]=response["content"][0]["text"]
	# if error because llm.message_history[1]["content"][0]["text"] doesnt exist
	#mzgs = [llm.message_history[0]]+[llm.message_history[1]]
	mzgs = [llm.message_history[0]]+[{"role":"user","content":response["content"][0]["text"]}]
	llm.message_history=mzgs
	# #print(llm.message_history)
	#messages = messages[0]
	#messages.append({"role": "assistant", "content": JSON.stringify(response_text)})
	
	#newmsg.merge(response_json)
	
	#messages.append({"role": "assistant", "content": (response_json["summary"])})
	return mzgs
	
func _get_relevant_context(query: String) -> Array:
	var context_results = []
	var search_complete = false
	
	# Start the search
	$VectorStore.search_similar(query)
	
	# Wait for search results
	var results = await $VectorStore.search_completed
	
	# Filter results by similarity threshold
	for result in results:
		if result.score >= 0.6:  # Adjust threshold as needed
			context_results.append({
				"text": result.text
			})
	
	print("Found ", context_results.size(), " relevant context items")
	return context_results

# Function to construct the enhanced prompt
func _construct_prompt_with_context(original_input: String, context: Array) -> String:
	var prompt = "Given the following context:\n\n"
	
	# Add context if available
	if context.size() > 0:
		for item in context:
			prompt += "- " + item.text + "\n"
		prompt += "\nBased on this context, please respond to: " + original_input
	else:
		# If no context found, just use the original input
		prompt = original_input
	
	print("Enhanced prompt:", prompt)
	return prompt

func critiqueprocess(input):
	var response = null
	
	critique.message_history = [critique.message_history[0]] + [llm.message_history[-1]] 
	while response==null:
		#if get_parent().holdAPI_1==false:
		if get_parent().holdapi_request(agentid):
			#OS.delay_msec(15000)
			response =  await critique.generate_response("return {\"criticism\" : \"criticism details\"}   or {\"criticism\" : \"nothing \"}. 
			Please if you don't have criticism just say 'nothing' and don't 
			explain or reason. Again, if you like the action and you don't have 
			comments, return {\"criticism\" : \"nothing\"} ") #  llm old
			
		
				
				#create_checkpoint("firstchkPT")
		else:
			#OS.delay_msec(15000)
			print("agent"+ str(agentid)+" waiting")
			await get_tree().create_timer(5).timeout 
			if agentid == get_parent().holdingagent and get_parent().onetime==true:  #this is needed when state is loaded and api is held
				get_parent().unholdapi_request(agentid)
			
				
		
	get_parent().unholdapi_request(agentid)
	#print(response)
	if response.has("Error") and ("max" in response["Error"].to_lower() or "overload" in response["Error"].to_lower()):
	#if response.has("Error"):
		print(str(agentid)+"critique")
		print(response)
		return
	var full_text=(response["content"][0]["text"]) # "Error:"Max retries reached
	print("critique:"+alias+full_text)
	await get_tree().create_timer(2.0).timeout
	critique_balloon.show_message(alias+str(agentid)+full_text)
	#var json = JSON.new()
	var parse_result = JSON.parse_string(full_text) #error parse  search
	if parse_result["criticism"]=="nothing": # if critisim exists
		pass
	else:
		llmprocess_user_input(full_text)
	
	
		
func llmprocess_user_input(input):
	#messages.append({"role":"user", "content":input})
	#if agentid==1:
	##var context = await _get_relevant_context(input)
	
	# Construct enhanced prompt with context
	# var enhance_input
	##input = _construct_prompt_with_context(input, context)
	mytime=get_parent().globaltime
	mytime_hour=get_parent().hours
	mytime_mints=get_parent().minutes
	mytime_ampm=get_parent().am_pm
	if mytime==null:
		return

	var response = null
	while response==null:
		#if get_parent().holdAPI_1==false:
		if get_parent().holdapi_request(agentid):
			#OS.delay_msec(15000)
			response =  await llm.generate_response(input) #  llm old
			
		
				
				#create_checkpoint("firstchkPT")
		else:
			#OS.delay_msec(15000)
			print("agent"+ str(agentid)+" waiting")
			await get_tree().create_timer(5).timeout 
			if agentid == get_parent().holdingagent and get_parent().onetime==true:  #this is needed when state is loaded and api is held
				get_parent().unholdapi_request(agentid)
			
				
		
	get_parent().unholdapi_request(agentid)
	print(response)
	#while response.has("Error"):
	
	#	response = await llm.generate_response(input) # llm old
	print(alias+" message history length")
	print(llm.message_history.size())
	if llm.message_history.size()>45 or get_parent().globaltime==1140:
		var mzgs=await llmsummarizer()
		messages=mzgs
	#if response.has("Error"):
	if response.has("Error") and ("max" in response["Error"].to_lower() or "overload" in response["Error"].to_lower()):

		print(str(agentid)+"critique")
		print(response) #err string
		return
	if response["content"]!=[]: # {"Error":"Max retries reached"
		#pass
		var full_text=(response["content"][0]["text"])
		print(full_text)
		await get_tree().create_timer(2.0).timeout
		#var new_balloon = SpeechBody2.new()
		#add_child(new_balloon)
		#new_
		speech_balloon.show_message(alias+str(agentid)+full_text)
		full_text = full_text.replace("(", "[").replace(")", "]")
		
	#print(JSON.parse_string(full_text))
	#while json_data==null:
		json_data = JSON.parse_string(full_text)
		critiqueprocess(full_text)

		if json_data:
			print("Parsed action:", json_data["action"])
			parse_action(json_data["action"])
			critiqueprocess(full_text)
		else:
			var actions =parsefulltext(full_text)
			for act in actions:
				parse_action(JSON.parse_string(act))
	
		
	
	
	
	
func parsefulltext(text: String) -> Array:
	var actions = []
	
	# Join all lines into a single string
	var full_text = text.replace("\n", " ").replace("\r", " ")
	
	# Pattern to match JSON-like structure with "action" key
	var regex = RegEx.new()
	regex.compile('"action":\\s*(\\[(?:[^\\[\\]]|\\[(?:[^\\[\\]]|\\[(?:[^\\[\\]])*\\])*\\])*\\])')

	#"action":\s*(\[(?:[^][]|\[(?:[^][]|\[(?:[^][])*\])*\])*\])
	var position = 0
	var joinedlist=[]
	while true:
		var result = regex.search(full_text, position)
		if not result:
			break
			
		var action_content = result.get_string(1)
		position = result.get_end()
		
		# Split the content by commas, but not within quotes
		var parts = []
		var current_part = ""
		var in_quotes = false
		
	
		
		#for act in actions:
		#	var Act=' '.join(act)
		joinedlist.append(action_content)
		
		#for i in range(action_content.length()):
		#	var char = action_content[i]
			
		#	if char == '"':
		#		in_quotes = !in_quotes
		#		current_part += char
		#	elif char == ',' and !in_quotes:
				# Clean up the part and add to array
		#		current_part = current_part.strip_edges()
		#		if current_part.begins_with('"') and current_part.ends_with('"'):
		#			current_part = current_part.substr(1, current_part.length() - 2)
		#		parts.append(current_part)
		#		current_part = ""
		#	else:
		#		current_part += char
		
		# Add the last part
		#if current_part:
		#	current_part = current_part.strip_edges()
		#	if current_part.begins_with('"') and current_part.ends_with('"'):
		#		current_part = current_part.substr(1, current_part.length() - 2)
		#	parts.append(current_part)
		
		#actions.append(current_part)
	
	return joinedlist
	
	
func get_user_input() -> String:
	# This is just an example - implement based on your UI
	var input_dialog = AcceptDialog.new()
	input_dialog.dialog_text = "Please enter the correct action:"
	var line_edit = LineEdit.new()
	input_dialog.add_child(line_edit)
	
	var user_input = ""
	
	# Wait for user input
	input_dialog.connect("confirmed", func():
		user_input = line_edit.text
	)
	
	add_child(input_dialog)
	input_dialog.popup_centered()
	
	await input_dialog.confirmed
	input_dialog.queue_free()
	return user_input
		
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
		POS = global_position
	else:
		position = target_position
		POS = global_position
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
func parse_action_json(command):
	print(command) # find a way to parse this!
func parse_action(command):
	if command[0]=="move" and command[1]=="to":
		go_to_area(command[2]) 
	elif command[0]=="move to":
		go_to_area(command[1])  #ai helper
	elif command[0]=="say to":
		if command.size()==3:
			var targetagent= command[1]
			var aliastocharacter={"Karen":"Character2","Bob":"Character1","Mario":"Character3",
			"karen":"Character2","bob":"Character1","mario":"Character3"}
			if targetagent =="AI assistant":
				$assistant.my_user_talking(command[2])
				return
			var agnt = aliastocharacter[targetagent]
			get_parent().get_node(agnt).somebody_talkingto_you(agentid,command[2])
			for person in closebypeople:
				if person != targetagent:
					get_parent().get_node(aliastocharacter[person]).youhearsomebody_talking(alias,person,command[2])
	elif command[0]=="say to AI assistant":
		if command.size()==2:
			$assistant.my_user_talking(command[1])
			

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
	$assistant.get_node("SpeechBalloon").global_position=global_position
	$assistant.get_node("CritiqueBalloon").global_position=global_position
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
	if soundoverlaps.size()>0:
		
		for obj in soundoverlaps:
			if obj is CharacterBody2D and obj != self:
				if obj.alias not in closebypeople:
					closebypeople.append(obj.alias)
	if overlaps.size()>0:
		for obj in overlaps:
			if obj is Area2D:
				place=obj.name
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
		# #httpreq.request("http://127.0.0.1:"+port, headers, HTTPClient.METHOD_POST, JSON.stringify(beat))
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
		# #if (messages[-1]["role"])=="assistant":
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
			print("sent to "+ alias +": "+"you see "+", and ".join(report_items))
			print("waiting " +str(tau) +" secs...")
			#get_parent().delay(tau)
			#llmprocess_user_input("{ \" you see \" : ( "+",  ".join(report_items) + ") }")
			#llmprocess_user_input(" You see "+", and".join(report_items) + ". Decide what to do next!")
			#  time now is ",str(mytime_hour),":" ,str(mytime_mints),mytime_ampm, ', and you see ', visarray_string,'. Your position is ', place
			llmprocess_user_input("{ \"situation\" : \" You see "+", and".join(report_items)+". Your location is "+place + "time now is "+str(mytime_hour)+":" +str(mytime_mints)+mytime_ampm+ "\"}") # you position is
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
	var nonewlinemsg=msg.replace("\n", " ").replace("\r", " ")
	var Alias=(get_parent().get_node("Character"+str(talkingagentid)).alias)
	var situation="{\"situation\" : \" " +Alias+" is talking to you."+"You hear "+(nonewlinemsg)+". Time now is "+str(mytime_hour)+":" +str(mytime_mints)+mytime_ampm+" \"}"
	$assistant.assistanthearsomebody_talking(msg)
	print("somebody talking and you hear ... waiting " +str(tau) +" secs...")
	#get_parent().delay(tau)
	llmprocess_user_input(situation)
	#get_parent().delay(tau)
func AIassistant_saying(msg):
	var nonewlinemsg=msg.replace("\n", " ").replace("\r", " ")
	var situation="{\"situation\" : \" AI assistant is talking to you."+"It says "+(nonewlinemsg)+" \"}"
	llmprocess_user_input(situation)
	
func youhearsomebody_talking(talkingagent_alias,hearingagent_alias,msg):
	
	#var Alias=(get_parent().get_node("Character"+str(talkingagentid)).alias)
	var nonewlinemsg=msg.replace("\n", " ").replace("\r", " ")
	var situation="{ \"situation\" : \" "+talkingagent_alias+" is talking to "+hearingagent_alias+". You hear "+(nonewlinemsg)+ ".\"}"
	print("sent to "+ alias +": "+ situation +" ... waiting " +str(tau) +" secs...")
	#get_parent().delay(tau)
	llmprocess_user_input(situation)
	#get_parent().delay(tau)
	
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
		elif body is Area2D:
			place=body
	
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
	var LLMMsg=llm.message_history
	if (llm.message_history[-1]["role"])=="assistant":
	#pass	
		#print("".join(["sent to ",alias ,": I am looking at my watch to decide what to do next, time now is ",str(mytime_hour),":" ,str(mytime_mints),mytime_ampm, ". You position right now is at ", str(place) ])
		llmprocess_user_input("".join(["{ \"situation\" : \" I am looking at my watch to decide what to do next, time now is ",str(mytime_hour),":" ,str(mytime_mints),mytime_ampm, ". My location right now is at ", str(place) ,"\" }" ]))
		
	#reminderbuffer= setnexttimer(schedule) # Replace with function body.
	#if previousreminder != reminderbuffer:
		
	#	llmprocess_user_input(reminderbuffer)
	#	previousreminder = reminderbuffer
	#	print(reminderbuffer)
	#	reminderringing=1



func save_state(filepath: String = "") -> bool:
	if filepath.is_empty():
		filepath = "res://savedcheckpoints/character_" + str(agentid) + ".save"
	
	# Create the save data dictionary
	var save_data = {
		# Identity and basic info
		"IDENTITY": IDENTITY,
		"PEOPLE_LIST": PEOPLE_LIST,
		"Schedule": Schedule,
		"SummaryTask": SummaryTask,
		"TASK_SPECIFIC_INSTRUCTIONS": TASK_SPECIFIC_INSTRUCTIONS,
		"agentid": agentid,
		"alias": alias,
		
		# Position and movement
		"POS": {
			"x": POS.x,
			"y": POS.y
		},
		"target_position": {
			"x": target_position.x,
			"y": target_position.y
		},
		"orientation": orientation,
		"moving": moving,
		"speed": speed,
		
		# Network settings
		"port": port,
		"url": url,
		
		# Collections
		"areas": areas,
		"objeks": objeks,
		"myitems": myitems,
		"listofplaces": listofplaces,
		"bagofactions": bagofactions,
		
		# Time related
		"mytime": mytime,
		"mytime_hour": mytime_hour,
		"mytime_mints": mytime_mints,
		"mytime_ampm": mytime_ampm,
		
		# Vitals
		"hunger": hunger,
		"sleep": sleep,
		"sickness": sickness,
		
		# Personal info
		"home": home,
		"job": job,
		"money": money,
		"hobbies": hobbies,
		"family": family,
		"friends": friends,
		
		# Tasks and schedules
		"schedule": schedule,
		"beat": beat,
		"buf": buf,
		"pushtoheartbeat": pushtoheartbeat,
		"taskruning": taskruning,
		"taskslist": taskslist,
		
		# Location and reminders
		"place": place,
		"reminderbuffer": reminderbuffer,
		"previousreminder": previousreminder,
		"reminder": reminder,
		"reminderringing": reminderringing,
		
		# Other states
		"UCbuffer": UCbuffer,
		"visarray": visarray,
		"tau": tau,
		"closebypeople": closebypeople,
		#lln states
		"llm_config": llm.config.to_dict(),
		"llm_message_history": llm.message_history,
		"llm_tools": {},  # We'll save tool names and their configurations if needed
		"llm_debug": llm.debug,
		"llmsonnet_config": llmsonnet.config.to_dict(),
		"llmsonnet_message_history": llmsonnet.message_history,
		"llmsonnet_tools": {},  # We'll save tool names and their configurations if needed
		"llmsonnet_debug": llmsonnet.debug,
		#"system_prompt": get_system_prompt() if api.supports_system_prompt() else "",
		#"timestamp": Time.get_unix_time_from_system()
		"assistant_llm_config": $assistant.llm.config.to_dict(),
		"assistant_llm_message_history": $assistant.llm.message_history,
		"assistant_llm_tools": {},  # We'll save tool names and their configurations if needed
		"assistant_llm_debug": $assistant.llm.debug,
		"assistant_llmsonnet_config": $assistant.llmsonnet.config.to_dict(),
		"assistant_llmsonnet_message_history": $assistant.llmsonnet.message_history,
		"assistant_llmsonnet_tools": {},  # We'll save tool names and their configurations if needed
		"assistant_llmsonnet_debug": $assistant.llmsonnet.debug,
	}
	
	# Convert to JSON string
	var json_string = JSON.stringify(save_data)
	
	# Save to file
	var file = FileAccess.open(filepath, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open file for saving: " + filepath)
		return false
	
	file.store_string(json_string)
	print("Character state saved successfully to: ", filepath)
	return true

## Loads the character state from a file.
## Returns true if successful, false otherwise.
##
## [param filepath] The path of the state file to load. If empty, uses the default path.
func load_state(filepath: String = "") -> bool:
	if filepath.is_empty():
		filepath = "res://savedcheckpoints/character_" + str(agentid) + ".save"
	
	# Check if file exists
	if not FileAccess.file_exists(filepath):
		push_error("Save file does not exist: " + filepath)
		return false
	
	# Read file
	var file = FileAccess.open(filepath, FileAccess.READ)
	if file == null:
		push_error("Failed to open file for loading: " + filepath)
		return false
	
	var json_string = file.get_as_text()
	
	# Parse JSON
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		push_error("Failed to parse save file")
		return false
	
	var save_data = json.get_data()
	
	# Restore state
	IDENTITY = save_data.get("IDENTITY", IDENTITY)
	PEOPLE_LIST = save_data.get("PEOPLE_LIST", PEOPLE_LIST)
	Schedule = save_data.get("Schedule", Schedule)
	SummaryTask = save_data.get("SummaryTask", SummaryTask)
	TASK_SPECIFIC_INSTRUCTIONS = save_data.get("TASK_SPECIFIC_INSTRUCTIONS", TASK_SPECIFIC_INSTRUCTIONS)
	agentid = save_data.get("agentid", agentid)
	alias = save_data.get("alias", alias)
	
	# Restore position and movement
	if save_data.has("POS"):
		POS = Vector2(save_data.POS.x, save_data.POS.y)
		
		position = POS
		
	
	if save_data.has("target_position"):
		target_position = Vector2(save_data.target_position.x, save_data.target_position.y)
	
	orientation = save_data.get("orientation", orientation)
	moving = save_data.get("moving", moving)
	speed = save_data.get("speed", speed)
	
	# Restore network settings
	port = save_data.get("port", port)
	url = save_data.get("url", url)
	
	# Restore collections
	#areas = save_data.get("areas", areas)
	objeks = save_data.get("objeks", objeks)
	myitems = save_data.get("myitems", myitems)
	#listofplaces = save_data.get("listofplaces", listofplaces)
	bagofactions = save_data.get("bagofactions", bagofactions)
	
	# Restore time
	mytime = save_data.get("mytime", mytime)
	mytime_hour = save_data.get("mytime_hour", mytime_hour)
	mytime_mints = save_data.get("mytime_mints", mytime_mints)
	mytime_ampm = save_data.get("mytime_ampm", mytime_ampm)
	
	# Restore vitals
	hunger = save_data.get("hunger", hunger)
	sleep = save_data.get("sleep", sleep)
	sickness = save_data.get("sickness", sickness)
	
	# Restore personal info
	home = save_data.get("home", home)
	job = save_data.get("job", job)
	money = save_data.get("money", money)
	hobbies = save_data.get("hobbies", hobbies)
	family = save_data.get("family", family)
	friends = save_data.get("friends", friends)
	
	# Restore tasks and schedules
	schedule = save_data.get("schedule", schedule)
	beat = save_data.get("beat", beat)
	buf = save_data.get("buf", buf)
	pushtoheartbeat = save_data.get("pushtoheartbeat", pushtoheartbeat)
	taskruning = save_data.get("taskruning", taskruning)
	taskslist = save_data.get("taskslist", taskslist)
	
	# Restore location and reminders
	place = save_data.get("place", place)
	reminderbuffer = save_data.get("reminderbuffer", reminderbuffer)
	previousreminder = save_data.get("previousreminder", previousreminder)
	reminder = save_data.get("reminder", reminder)
	reminderringing = save_data.get("reminderringing", reminderringing)
	
	# Restore other states
	UCbuffer = save_data.get("UCbuffer", UCbuffer)
	visarray = save_data.get("visarray", visarray)
	tau = save_data.get("tau", tau)
	closebypeople = save_data.get("closebypeople", closebypeople)
	llm.config = LLMConfig.from_dict(save_data.llm_config)
	llm.message_history = save_data.llm_message_history
	llm.debug = save_data.llm_debug
	llmsonnet.config = LLMConfig.from_dict(save_data.llmsonnet_config)
	llmsonnet.message_history = save_data.llmsonnet_message_history
	llmsonnet.debug = save_data.llmsonnet_debug
	print(llm.message_history)
	print(llmsonnet.message_history)
	
	print("Character state loaded successfully from: ", filepath)
	return true

## Creates a checkpoint of the current character state with a custom name.
## Returns true if successful, false otherwise.
##
## [param checkpoint_name] The name of the checkpoint.
func create_checkpoint(checkpoint_name: String) -> bool:
	var checkpoint_path = "res://savedcheckpoints/character_" + str(agentid) + "_" + checkpoint_name + ".save"
	return save_state(checkpoint_path)

## Loads a specific checkpoint by name.
## Returns true if successful, false otherwise.
##
## [param checkpoint_name] The name of the checkpoint to load.
func load_checkpoint(checkpoint_name: String) -> bool:
	var checkpoint_path = "res://savedcheckpoints/character_" + str(agentid) + "_" + checkpoint_name + ".save"
	return load_state(checkpoint_path)

## Lists all available checkpoints for this character.
## Returns an array of checkpoint names.
func list_checkpoints() -> Array:
	var checkpoints = []
	var dir = DirAccess.open("user://")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		var prefix = "character_" + str(agentid) + "_"
		while file_name != "":
			if file_name.begins_with(prefix) and file_name.ends_with(".save"):
				checkpoints.append(file_name.trim_prefix(prefix).trim_suffix(".save"))
			file_name = dir.get_next()
	return checkpoints

## Deletes a checkpoint by name.
## Returns true if successful, false otherwise.
##
## [param checkpoint_name] The name of the checkpoint to delete.
func delete_checkpoint(checkpoint_name: String) -> bool:
	var checkpoint_path = "user://character_" + str(agentid) + "_" + checkpoint_name + ".save"
	if FileAccess.file_exists(checkpoint_path):
		var err = DirAccess.remove_absolute(checkpoint_path)
		if err == OK:
			print("Checkpoint deleted: ", checkpoint_name)
			return true
		else:
			push_error("Failed to delete checkpoint: " + checkpoint_name)
	return false
