
@onready var httpreq = $/root/HTTPRequest
const url = "http://127.0.0.1:8000"
func ready():
	# Create an HTTP request node and connect its completion signal.
	httpreq.request(url)
	#$/root/socktconn/HTTPRequest.request("http://127.0.0.1:8000")
	

func _on_http_request_request_completed(result, response_code, headers, body):
	print(body.get_string_ftom_Utf8()) # Replace with function body.
