extends Node

signal on_info
signal on_error
signal on_map_data

export var overpass_api_url = "https://overpass-api.de/api/interpreter"
var request_running = false
var request_coords = null
#var current_closure = null


func on_info(txt):
	emit_signal("on_info", txt)
	
func on_error(txt):
	emit_signal("on_error", txt)


func _init():
	self.request_running = false;
	self.request_coords = null;
	#self.current_closure = null;

func GetHighwaysInGpsRect(rect):
	if self.request_running:
		self.on_error("Request already running. Wait for current request to complete.")
		return

	for d in ['n', 's', 'e', 'w']:
		if not d in rect:
			self.on_error("%s missing from rect." % d)
			return null

	# OpenMaps Overpass API query
	# Simple query to:
	# 1. Specify output to json
	# 2. Return all ways (paths) within the given coordinates [filter that to highways only]
	# 3. For each item in the path
	#      '>' - Get its node details (gps coords)
	# 4. Return only the skeleton of data that should be used to render a map
	var query_text = '[out:json];(way(%3.3f,%3.3f,%3.3f,%3.3f)[highway];);(._;>;);out skel;' % [rect['s'], rect['w'], rect['n'], rect['e']]
	var query_url = '%s?data=%s' % [overpass_api_url, query_text.percent_encode()]
	self.on_info("Sending request to: %s" % query_url)
	self.request_running = true
	self.request_coords = rect
	#self.current_closure = closure
	$HTTPRequest.request(query_url)

func _on_HTTPRequest_request_completed(result, response_code, headers, body):
	self.on_info("Result: %s" % result)
	self.on_info("Response Code: %s" % response_code)
	self.request_running = false
	
	var json_parse_result = JSON.parse(body.get_string_from_utf8())
	
	if json_parse_result.error != OK:
		self.on_error("Error parsing JSON response from OpenMaps: %s" % json_parse_result.error_string)
	else:
		emit_signal("on_map_data", json_parse_result.result, self.request_coords)
	
	self.request_coords = null
		
	#assert(self.current_closure != null)
	#self.current_closure(result_object)
	#self.current_closure = null
