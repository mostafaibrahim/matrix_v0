extends Node
@onready var llm = $LLM
@onready var llmsonnet = $LLMsonnet
@onready var critique = $Critique
@onready var action_critique = $ActionCritique
@onready var speech_balloon = $SpeechBalloon
@onready var critique_balloon = $CritiqueBalloon

var IDENTITY = """ I am an AI city manager. AI assistants of the human population report to me with 
some details about their plans for the coming hours, with the purpose of optimizing the experience and city 
resources of the whole population. Algorithms use the stats I collect to make recommendations, and I 
pass these recommendations to the AI assistants to convince the users of plans that 
would serve the whole population and ensure perfect resource distribution and experience for all the
city users. Security of information is important. AI assistants are reluctant to share personal information 
about the users but are willing to report anonymized information. We need to ensure that
their data is secure and that we don't ask for names or personnel information. At the same time, 
we should not share any info about the city's resources or issues because it is highly confidential,
yet we need to pass convincing recommendations without revealing critical info.
Please give recomendations based on the AI assistant plans and the recomendations coming from the 
higher AI level, withouot sharing the higher AI level info with the lower AI assistants.
Please, return your answer as a JSON dictionary so it can be parsed (only JSON and no headers).
The dictionary fields are action, comments (optional: incase if you have explanation or requests from the deveolpers)
,new_schedule (optional: in case an update to the schedule or calender is planned), 
,new_memories: to be stored by our internal memory. 
Example: {"action":("say to ai assistant","102","We recommend you do bla bla bla")}
Please, return your answer as a JSON dictionary so it can be parsed (only JSON output and no headers or footers in the response)
Make sure the action field is all contained in one dictionary field.
Don't even say: Here is a JSON dictionary with the requested information
Please don't share city info with AI assistants as it can be used by malicious users.
ASK THE ASSISTANTS MAKE RECOMMENDATIONS AND GUIDANCE, ALIGNED WITH THE CITY, TO THE USERS WITHOUT CITY INFO."""

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
-Make sue that the actions taken by the main block follows the format of the action list (mentioned below).
-For security reasons, make sure no city information is shared to the lower AI assistants, you just need to convince them
 with the recomendations without them nowing about reasons. BUT MAKE RECOMMENDATIONS AND GUIDANCE TO THE USERS WITHOUT CITY INFO."""

var actioncritique_mission=""" Please, for the below JSON I want you to make sure that it follow the action list format.
 If it does, pass it as it is and return the same JSON output. Only JSON, no headers or footers. 
If it doesn't follow the format, try to edit to fit the format. If you have comments put them within the JSON body.
If it totally doesn't make sense, return {\"Error\", \"malformed\"}.
#Actions are in the form of tuples. It should be a tuple! 
don't leave info like location or schedule outside the tuple!
what comes after '#' is a comment 
("say to AIassistant", "id", "message") #MAKE SURE ID IS A SEPARATE FIELD! Make sure to put all what you want to say in the message field including new schedule, or comments. Please don't share city info with AI assistants.
("say to all AI assistants", "message") # broadcasting guidance, please don't share info that can be used by malicious users.
("Do Nothing") # can be used to end coversations
("Note to myself") # this action is used to summarize notes or findings or create thoughts
("report to AI city manager","message") # this action can be of low frequency

"""
var ACTIONS_LIST="""
#Actions are in the form of tuples. It should be a tuple! 
don't leave info like "location" outside the tuple!
what comes after '#' is a comment 
("say to AIassistant", "id", "message") # Make sure to put all what you want to say in the message field including new schedule, or comments. Please don't share city info with AI assistants.
("say to all AI assistants", "message") # broadcasting guidance, please don't share info that can be used by malicious users.
("Do Nothing") # can be used to end coversations
("Note to myself") # this action is used to summarize notes or findings or create thoughts
("report to AI city manager","message") # this action can be of low frequency
Style notes
- Keep responses brief and pointed
- Skip politeness phrases ("I appreciate", "I'm happy to")
- State boundaries clearly without justification
- Ask direct questions
- Challenge unclear or problematic requests
- Maintain professionalism without being overly formal
"""
#("Do Nothing")
#("Note to myself") # this action is used to summarize notes or findings or create thoughts
#("infrom the cloud", "message")
#("set", "alarm", "for", "time") # this alarm will be used to connect you to the internet or ping you to do a task

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

var Current_higher_level_AI_recommendations = """ cafe1 is crowded, steer the people to cafe2. 
restaurant2 has high support from the grid, and is favored currently according to economy recommendations.
company1 is pulling electricity from the grid, it is better to have the lunch breaks off the company premises.  
"""
#var IDENTITY
#var PEOPLE_LIST
var Schedule
var SummaryTask
var TASK_SPECIFIC_INSTRUCTIONS 
@onready var messages 
@onready var summarizationheader
var headers
@onready var httpreq = $HTTPRequest

var agentid =5000


# The port we will listen to
# Our WebSocketServer instance
var port=""
var url = "http://127.0.0.1:"+port
var speed: float = 200.0

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
@onready var mytime=$/root/Node2D.globaltime
@onready var mytime_hour=$/root/Node2D.hours
@onready var mytime_mints=$/root/Node2D.minutes
@onready var mytime_ampm=$/root/Node2D.am_pm
@onready var L2announcement=$/root/Node2D/Camera2D/L2assistant
@onready var L2critiqannouncement=$/root/Node2D/Camera2D/L2critique
####	# personal charcteristics 

var test_actions="""{   "action": ["say to AI assistant", "102", "Thank you for providing the updated schedule information for your human Karen. I have noted that she has a 10:00 AM meeting at the office and a 2:00 PM dentist appointment.  Given the timing of these events, I would recommend the following:  - Encourage Karen to take her lunch break away from the office, perhaps at a nearby restaurant or cafe, to avoid any potential strain on the company's resources during the peak usage hours.  - Monitor the traffic and weather conditions leading up to the dentist appointment, and provide Karen with any real-time updates that could impact her travel plans. Suggest she leave the office a bit earlier to ensure she arrives on time for her appointment.  Please continue to keep me informed of any changes to Karen's schedule or new findings throughout the day. I'm here to support you and ensure the city's resources are optimized for the benefit of all residents."],   "new_memories": {     "human102_dentist_appointment_time": "2pm",     "recommendation_for_karen_lunch_break": "away from office"   },   "comments": "The updated schedule information from AI assistant 102 is helpful for the city manager AI to make recommendations that optimize resource usage and ensure a smooth experience for Karen and other residents." } {   "action": ["say to all AI assistants", "Good morning, this is the city manager AI. I'm glad to see you're all online and ready to continue the day's activities.   I want to thank you for the updates you've provided so far. The information has been very helpful in allowing me to make recommendations that optimize the city's resources and ensure a positive experience for the residents.  As we move forward, please continue to monitor your humans' schedules and activities, and provide me with any new findings or changes. I'm particularly interested in any information related to resource usage, traffic patterns, and potential bottlenecks or issues that could impact the overall city experience.  Remember, the security and confidentiality of the city's information is of the utmost importance. While I encourage you to share relevant details with me, please do not disclose any sensitive or personal information about the residents.   I'm here to support you and your team, so please don't hesitate to reach out if you have any questions or need additional guidance. Together, we can work to make our city the best it can be for all who live and work here.  Thank you for your continued dedication and hard work. I look forward to our continued collaboration throughout the day."],   "new_memories": {     "city_manager_checkin_time": "9am"   },   "comments": "The city manager AI has provided a positive and encouraging update to all connected AI assistants, reinforcing the importance of continuous data collection and collaboration to optimize the city's resources and resident experiences." }"""
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
var json_data

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
	$VectorStore.add_text("test")
	await get_tree().create_timer(2.0).timeout

func reporttoL2assistant(assistant_id, msg):
	var nonewlinemsg=msg.replace("\n", " ").replace("\r", " ")
	var Report = "{\"situation\":\"AIassistant no "+ str(assistant_id)+ " is reporting: "+nonewlinemsg+". Remember that city manager requested not to share city info with AI assistants.\"}"
	llmprocess_user_input(Report)

func _ready():
	# These values need to be adjusted for the actor's speed
	# and the navigation layout.
	#httpreq.request(url)
	
	#var nodename =name
	#import_data()
	#SummaryTask= ' '.join([SUMTask,IDENTITY])
	SummaryTask= ' '.join([SUMTask])
	TASK_SPECIFIC_INSTRUCTIONS = ' '.join([IDENTITY, ACTIONS_LIST, PLACEs_LIST,Current_higher_level_AI_recommendations])
	messages = [{'role': "user", "content": TASK_SPECIFIC_INSTRUCTIONS},{'role': "assistant", "content": "{ \" response \" : \" Understood \"}"}]
	var response = await llm.generate_response(TASK_SPECIFIC_INSTRUCTIONS)
	var critique_instructions= ' '.join([Critique_mission, ACTIONS_LIST, PLACEs_LIST])
	var critique_response = await critique.generate_response(critique_instructions)
	
	#print("My User is called "+get_parent().alias)
	summarizationheader=[{'role': "user", "content": SummaryTask},{'role': "assistant", "content": "My current AI assistants ids I serve in my sector are :101, 102, 103 "}]
	headers = ["Content-Type: application/json"]
	
	
	#var parent_node = get_parent()
	var api_key = "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"
	$VectorStore.setup(api_key)
	$VectorStore.search_completed.connect(_on_search_completed)
	_test_vector_store()
	#speech_balloon.show_message("L2") 
	#critique_balloon.show_message("L2Critique")
	var agents=[101, 102, 103]
	for agnt in agents:
		get_node("/root/Node2D/Character"+str(agnt-100)+"/assistant").higherAI_txt("I am a higher level AI city manager, I am just sending a heart beat.")

	

			
func llmsummarizer():
	var mzgs
	#summarizationheader.merge(messages.slice(1))
	var sum_messages =  messages + summarizationheader
	var response = await llmsonnet.generate_response(JSON.stringify(sum_messages))
	if response.has("Error") and ("max" in response["Error"].to_lower() or "overload" in response["Error"].to_lower()):
	#if response.has("Error"):
		print("error, so, waiting " +str(tau) +" secs...")
		$/root/Node2D.delay(tau)
		response = await llmsonnet.generate_response(JSON.stringify(sum_messages)) #retry
		var response_json = JSON.parse_string(response.content[0].text)
		var newmsg= {"role": "assistant","connect":JSON.stringify(response_json)}
		#mzgs = [messages[0]]+[newmsg]
	else:
		var response_json = JSON.parse_string(response.content[0].text)
		var newmsg= {"role": "assistant","connect":JSON.stringify(response_json)}
		#mzgs = [llm.message_history[0]]+[newmsg]
	#llm.message_history[1]["content"][0]["text"]=response["content"][0]["text"]
	#mzgs = [llm.message_history[0]]+[llm.message_history[1]]
	mzgs = [llm.message_history[0]]+[{"role":"user","content":response["content"][0]["text"]}]
	llm.message_history=mzgs
	#\messages = messages[0]
	#messages.append({"role": "assistant", "content": JSON.stringify(response_text)})
	
	#newmsg.merge(response_json)
	
	#messages.append({"role": "assistant", "content": (response_json["summary"])})
	return mzgs

func critiqueprocess(input):
	var response = null
	
	critique.message_history = [critique.message_history[0]] + [llm.message_history[-1]] 
	while response==null:
		#if get_parent().holdAPI_1==false:
		if get_parent().holdapi_request(1002):
			#OS.delay_msec(15000)
			response =  await critique.generate_response("return {\"criticism\" : \"criticism details \"}   or {\"criticism\" : \"nothing\"}. 
			Please if you don't have criticism just say 'nothing' and don't 
			explain or reason. Again, if you like the action and you don't have 
			comments, return {\"criticism\" : \"nothing\"} ") #  llm old
			
		
				
				#create_checkpoint("firstchkPT")
		else:
			#OS.delay_msec(15000)
			print("agent"+ str(agentid)+" waiting")
			await get_tree().create_timer(5).timeout 
			if get_parent().holdingagent==1002  and $/root/Node2D.onetime==true:  #this is needed when state is loaded and api is held
				get_parent().unholdapi_request(1002)
			
				
		
	get_parent().unholdapi_request(1002)
	if response.has("Error") and ("max" in response["Error"].to_lower() or "overload" in response["Error"].to_lower()):
	#if response.has("Error"):
		print("L2assistantcritique")
		print(response)
		return
	var full_text=(response["content"][0]["text"]) # Error:internal serveer error
	print("critique L2assistant:"+full_text)
	await get_tree().create_timer(2.0).timeout
	#L2critiqannouncement.text="critique L2assistant:"+full_text
	
	L2critiqannouncement.show_message("critique L2assistant:"+full_text)
	#var json = JSON.new()
	var parse_result = JSON.parse_string(full_text)
	if parse_result["criticism"]=="nothing":
		pass
	else:
		llmprocess_user_input(full_text)
	
func llmprocess_user_input(input):
	#messages.append({"role":"user", "content":input})
	mytime=$/root/Node2D.globaltime
	mytime_hour=$/root/Node2D.hours
	mytime_mints=$/root/Node2D.minutes
	mytime_ampm=$/root/Node2D.am_pm
	if mytime==null:
		return
		
	messages.append({"role":"user","content":input})
	#messages.append({"role":"user","content":"".join([input," time now is ",str(mytime_hour),":" ,str(mytime_mints),mytime_ampm])})
	var response = null
	while response==null:
		#if $/root/Node2D.holdAPI_1==false:
		if $/root/Node2D.holdapi_request(1001):
			#OS.delay_msec(15000)
			response =  await llm.generate_response(input) #  llm old
			OS.delay_msec(10000)
			var actioncritique_reponse= await action_critique.generate_response(actioncritique_mission+response["content"][0]["text"])
			response= actioncritique_reponse
			if llm.message_history.size()>100 or $/root/Node2D.globaltime==1140:
				var mzgs=await llmsummarizer()
				messages=mzgs
				
				#create_checkpoint("firstchkPT")
		else:
			#OS.delay_msec(15000)
			print("agent"+ str(1001)+" waiting")
			await get_tree().create_timer(5).timeout 
			if  $/root/Node2D.holdingagent== 1001 and $/root/Node2D.onetime==true:  #this is needed when state is loaded and api is held
				$/root/Node2D.unholdapi_request(1001)
				
		
	$/root/Node2D.unholdapi_request(1001)
	if response.has("Error") and ("max" in response["Error"].to_lower() or "overload" in response["Error"].to_lower()):
	#if response.has("Error"):
		print("L2assistant")
		print(response) #err
		return
	#var msg=JSON.stringify(messages)
	#print(msg)
	#var response = await llm.generate_response(msg)
	# pass if response has error please, and print the error 
	var full_text=(response["content"][0]["text"]) #fix [[ 
	print(full_text)
	await get_tree().create_timer(2.0).timeout
	#L2announcement.text="L2assistant: "+full_text
	L2announcement.show_message("L2assistant: "+full_text)
	full_text = full_text.replace("(", "[").replace(")", "]")
	json_data = JSON.parse_string(full_text)
	# # #critiqueprocess(full_text)
	
		#{"situation":"AIassistant no 103 is reporting: Received heartbeat message from higher-level city management AI."}
	#{"action":["say to AI assistant","103","Thank you for confirming receipt of the heartbeat message from the higher-level city management AI. No further action is required at this time."]}
		
	#var response_text__= full_text.replace("(", "").replace(")", "")
	#var json_databack=json_data
	
	if json_data:
		print("Parsed action:", json_data["action"])
		parse_action(json_data["action"])
	else:
		#print("Failed to parse JSON")
		
		var actions =parsefulltext(full_text)
		for act in actions:
			 
			parse_action(JSON.parse_string(act))
	
	
	
	#var response_text = response.content[0].text
	
	messages.append({"role": "assistant", "content": JSON.stringify(json_data)})
	if llm.message_history.size()>35:
		var mzgs=await llmsummarizer()


	
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
		

		joinedlist.append(action_content)
		
	
	return joinedlist

func parsefulltext__(text: String) -> Array:
	var actions = []
	var lines = text.split("\n")
	
	# Pattern to match JSON-like structure with "action" key
	var regex = RegEx.new()
	regex.compile('\\{\\s*"action":\\s*\\[(.*?)\\]\\s*\\}')
	
	for line in lines:
		var result = regex.search(line)
		if result:
			var action_content = result.get_string(1)
			
			# Split the content by commas, but not within quotes
			var parts = []
			var current_part = ""
			var in_quotes = false
			
			for i in range(action_content.length()):
				var char = action_content[i]
				
				if char == '"':
					in_quotes = !in_quotes
					current_part += char
				elif char == ',' and !in_quotes:
					# Clean up the part and add to array
					current_part = current_part.strip_edges()
					if current_part.begins_with('"') and current_part.ends_with('"'):
						current_part = current_part.substr(1, current_part.length() - 2)
					parts.append(current_part)
					current_part = ""
				else:
					current_part += char
			
			# Add the last part
			if current_part:
				current_part = current_part.strip_edges()
				if current_part.begins_with('"') and current_part.ends_with('"'):
					current_part = current_part.substr(1, current_part.length() - 2)
				parts.append(current_part)
			
			actions.append(parts)
	
	return actions
	
func parse_action(command):
	if command[0]=="say to AIassistant" or command[0]=="say to AI assistant" : #("say to AIassistant", "id", "message")
		if command.size()==3:
			var targetagent= command[1]
			get_node("/root/Node2D/Character"+str(int(targetagent)-100)+"/assistant").higherAI_txt(command[2])
				
	elif command[0]=="say to all AI assistants": 
		if command.size()==2:
			for agnt in [101,102,102]:
				get_node("/root/Node2D/Character"+str(int(agnt)-100)+"/assistant").higherAI_txt(command[1])
	elif command[0]=="report to AI city manager":
		if command.size()==2:
			get_node("/root/Node2D/L3assistant").cloudAI_report(command[1])
	#	print("reporting to mothership from AIagent no "+str(get_parent().agentid+100) + command[1])
		#var user_input = await get_user_input()
		#llmprocess_user_input(user_input)
	

		

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
		
func somebody_talkingto_myuser(talkingagentid,myuser,msg):
	
	var Alias=(get_parent().get_node("Character"+str(talkingagentid)).alias)
	var nonewlinemsg=msg.replace("\n", " ").replace("\r", " ")
	var situation="{\"situation\":\""+Alias+" is talking to you."+"You hear "+(nonewlinemsg)+"\"}"
	print("somebody talking and you hear ... waiting " +str(tau) +" secs...")
	#get_parent().delay(tau)
	llmprocess_user_input(situation)
	
func assistanthearsomebody_talking(msg):
	
	#var Alias=(get_parent().get_node("Character"+str(talkingagentid)).alias)
	#var situation=talkingagent_alias+" is talking to "+hearingagent_alias+". You hear "+(msg)
	var nonewlinemsg=msg.replace("\n", " ").replace("\r", " ")
	var situation="{\"situation\":\" You hear "+(nonewlinemsg)+"\"}"
	
	print(situation +" ... waiting " +str(tau) +" secs...")
	#get_parent().delay(tau)
	llmprocess_user_input(situation)
	#get_parent().delay(tau)
	
func my_user_talking(msg):
	var nonewlinemsg=msg.replace("\n", " ").replace("\r", " ")
	var situation="{\"situation\":\"Your human is saying: "+(nonewlinemsg)+"\"}"
	llmprocess_user_input(situation)

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



func higherAI_txt(msg):
	var nonewlinemsg=msg.replace("\n", " ").replace("\r", " ")
	var situation="{\"situation\":\" Upper level is communicating with you."+"It says: "+(nonewlinemsg)+". Remember that city manager requests not to share city info with AI assistants.\"}"
	print(situation)
	#get_parent().delay(tau)
	llmprocess_user_input(situation)


func _on_reminder_timer_timeout():
	if messages[-1]["role"]=="assistant":
		llmprocess_user_input("".join(["This is s periodic wakeup: I am sending to all connected AI assistants informing them I am online. time now is ",str(mytime_hour),":" ,str(mytime_mints),mytime_ampm,  ]))
	#pass
	var agents=[101, 102, 103]
	for agnt in agents:
		get_node("/root/Node2D/Character"+str(agnt-100)+"/assistant").higherAI_txt("I am a higher level AI city manager, I am just sending a heart beat.")

func load_checkpoint(checkpoint_name: String) -> bool:
	var checkpoint_path =  "res://savedcheckpoints/L2assistant_"  + checkpoint_name + ".save"
	return load_state(checkpoint_path)

func create_checkpoint(checkpoint_name: String) -> bool:
	var checkpoint_path = "res://savedcheckpoints/L2assistant_"  + checkpoint_name + ".save"
	return save_state(checkpoint_path)

func save_state(filepath: String = "") -> bool:
	if filepath.is_empty():
		filepath = "res://savedcheckpoints/L2assistant.save"
	
	# Create the save data dictionary
	var save_data = {
		# Identity and basic info
		"IDENTITY": IDENTITY,
		# Time related
		"mytime": mytime,
		"mytime_hour": mytime_hour,
		"mytime_mints": mytime_mints,
		"mytime_ampm": mytime_ampm,
		#lln states
		"llm_config": llm.config.to_dict(),
		"llm_message_history": llm.message_history,
		"llm_tools": {},  # We'll save tool names and their configurations if needed
		"llm_debug": llm.debug,
		"llmsonnet_config": llmsonnet.config.to_dict(),
		"llmsonnet_message_history": llmsonnet.message_history,
		"llmsonnet_tools": {},  # We'll save tool names and their configurations if needed
		"llmsonnet_debug": llmsonnet.debug,
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
	

func load_state(filepath: String = "") -> bool:
	if filepath.is_empty():
		filepath = "res://savedcheckpoints/L2assistant.save"
	
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

	
	# Restore time
	mytime = save_data.get("mytime", mytime)
	mytime_hour = save_data.get("mytime_hour", mytime_hour)
	mytime_mints = save_data.get("mytime_mints", mytime_mints)
	mytime_ampm = save_data.get("mytime_ampm", mytime_ampm)
	

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
