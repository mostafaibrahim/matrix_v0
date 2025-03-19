# VectorStore.gd
#class_name VectorStore
extends Node
#var embeddings_service: OpenAIEmbeddings
var vectors: Dictionary = {}  # text -> vector
var metadata: Dictionary = {}  # text -> metadata
signal search_completed(results: Array)
var is_waiting_for_search: bool = false 
var is_processing: bool = false  
var current_text: String = "" 

func _ready():
	#embeddings_service = get_node("../OpenAIEmbeddings")
	#add_child(embeddings_service)
	get_parent().embedding_completed.connect(_on_embedding_received)
	get_parent().embedding_failed.connect(_on_embedding_failed)
func setup(api_key: String):
	get_parent().setup(api_key)

func add_text(text: String, meta: Dictionary = {}) -> void:
	get_parent().embedding_completed.connect(_on_embedding_received)
	#metadata[text] = meta
	if is_processing:
		print("Still processing previous text, please wait")
		return
		
	print("Adding text: ", text)
	is_processing = true
	current_text = text
	get_parent().get_embedding(text)

func _on_embedding_received(embedding: Array) -> void:
	if current_text.is_empty():
		print("Error: No text being processed")
		return
		
	vectors[current_text] = embedding
	print("Added embedding for: ", current_text)
	
	# Reset state
	is_processing = false
	current_text = ""

func _on_embedding_failed(error: String) -> void:
	print("Failed to get embedding: ", error)

func cosine_similarity(vec1: Array, vec2: Array) -> float:
	var dot_product = 0.0
	var mag1 = 0.0
	var mag2 = 0.0
	
	for i in range(len(vec1)):
		dot_product += vec1[i] * vec2[i]
		mag1 += vec1[i] * vec1[i]
		mag2 += vec2[i] * vec2[i]
	
	mag1 = sqrt(mag1)
	mag2 = sqrt(mag2)
	
	if mag1 == 0 or mag2 == 0:
		return 0.0
	
	return dot_product / (mag1 * mag2)
func _on_search_embedding_received(embedding: Array) -> void:
	_process_search_results(embedding)
	# Disconnect after processing
	#if get_parent().embedding_completed.is_connected(_on_search_embedding_received):
	#	get_parent().embedding_completed.disconnect(_on_search_embedding_received)
	if get_parent().embedding_completed.is_connected(_on_embedding_received):
		get_parent().embedding_completed.disconnect(_on_embedding_received)
	if get_parent().embedding_completed.is_connected(_on_search_embedding_received):
		get_parent().embedding_completed.disconnect(_on_search_embedding_received)

func search_similar(query_text: String, k: int = 5) -> void:
	# Disconnect any existing connections to avoid duplicates
	if get_parent().embedding_completed.is_connected(_on_embedding_received):
		get_parent().embedding_completed.disconnect(_on_embedding_received)
	if get_parent().embedding_completed.is_connected(_on_search_embedding_received):
		get_parent().embedding_completed.disconnect(_on_search_embedding_received)
	# Store k value for this search
	#if is_waiting_for_search:
	#	print("Warning: Another search is still in progress")
	#	return
		
	#is_waiting_for_search = true
	#var search_k = k
	get_parent().embedding_completed.connect(_on_search_embedding_received)
	get_parent().get_search_embedding(query_text)
	
	#get_parent().embedding_completed.connect(
	#	func(embedding: Array):
	#		is_waiting_for_search = false
	#		_process_search_results(embedding, search_k, query_text)
			# Make sure to disconnect after processing
	#		if get_parent().embedding_completed.is_connected(_process_search_results):
	#			get_parent().embedding_completed.disconnect(_process_search_results), 
	#	CONNECT_ONE_SHOT
	#)
			
	

#func _process_search_results(query_embedding: Array, k: int, query_text: String) -> void:
func _process_search_results(query_embedding: Array) -> void:
	var results = []
	
	# Make sure we have vectors to compare
	if vectors.is_empty():
		print("No vectors in database to search")
		search_completed.emit([])
		return
		
	# Build results array
	for text in vectors:
		var similarity = cosine_similarity(query_embedding, vectors[text])
		results.append({
			"text": text,
			"score": similarity})
	
	# Sort results
	results.sort_custom(func(a, b): return a["score"] > b["score"])
	# Sort results
	results.sort_custom(func(a, b): return a["score"] > b["score"])
	
	# Get top k results
	#if k < results.size():
	#	results = results.slice(0, k)
	
	# Print results
	#print("\nTop ", k, " results for: ", query_text)
	print("\nSearch results:")
	for result in results:
		print("Text: ", result["text"])
		print("Similarity: ", result["score"])
		print("---")
	search_completed.emit(results)
	







#func _on_character_embedding_completed(embedding):
#	var text = metadata.keys()[metadata.size() - 1]  # Get last added text
#	vectors[text] = embedding
#	print("Added embedding for: ", text)


func _on_character_embedding_failed(error):
	print("Failed to get embedding: ", error)


func _on_character_search_completed(results):
	# Do something with the results
	print("Got ", results.size(), " search results")
