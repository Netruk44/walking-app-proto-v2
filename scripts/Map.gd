extends Node2D

signal on_info
signal on_error

# OpenMaps data
var nodes = {} # "id": int64:  {"lat": float, "lon": float}
var ways = {} # "id": int64: {"nodes": list<int64>}

# Calculated data
var window_bottom = 999.0
var window_top = -999.0
var window_left = 999.0
var window_right = -999.0

# Precalculated drawing lines
var line_list = PoolVector2Array()
var requested_window_list = PoolVector2Array()

func on_info(txt):
	emit_signal("on_info", txt)
	
func on_error(txt):
	emit_signal("on_error", txt)


func _ready():
	pass # Replace with function body.
	
func _draw():
	draw_multiline(self.line_list, Color.red)
	draw_multiline(self.requested_window_list, Color.green)
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

func reset():
	self.nodes = {}
	self.ways = {}
	self.window_bottom = 999.0
	self.window_top = -999.0
	self.window_left = 999.0
	self.window_right = -999.0
	self.line_list = PoolVector2Array()
	self.requested_window_list = PoolVector2Array()

func addFromOpenMapsApi(map_data, requested_window):
	self.reset()
	self.on_info("Got maps data containing %d object(s)." % map_data['elements'].size())
	self.on_info("Parsing...")
	
	var screen_size = get_viewport().size
	var window_aspect_ratio = screen_size.x / screen_size.y
	self.on_info("Window aspect ratio (%d / %d): %f" % [screen_size.x, screen_size.y, window_aspect_ratio])
	
	#var coordinates_aspect_ratio = (requested_window['e'] - requested_window['w']) / (requested_window['n'] - requested_window['s'])
	#self.on_info("Coordinates aspect ratio (%d / %d): %f" % [requested_window['e'] - requested_window['w'], requested_window['n'] - requested_window['s'], coordinates_aspect_ratio])
	
	for obj in map_data['elements']:
		# Add the object to the appropriate dictionary, nodes or ways
		if obj['type'] == 'node':
			self.nodes[obj['id']] = obj
		elif obj['type'] == 'way':
			self.ways[obj['id']] = obj
		else:
			self.on_error('Unknown object type "%s", ignoring.' % obj['type'])
	
	# Calculate bounding box for nodes
	var lat_min = 999.0
	var lat_max = -999.0
	var long_min = 999.0
	var long_max = -999.0
	for node_id in self.nodes:
		var n = self.nodes[node_id]
		if n['lat'] < lat_min:
			lat_min = n['lat']
		if n['lat'] > lat_max:
			lat_max = n['lat']
			
		if n['lon'] < long_min:
			long_min = n['lon']
		if n['lon'] > long_max:
			long_max = n['lon']
	
	var coordinates_aspect_ratio = (long_max - long_min) / (lat_max - lat_min)
	self.on_info("Coordinates aspect ratio (%f / %f): %f" % [long_max - long_min, lat_max - lat_min, coordinates_aspect_ratio])
	
	if coordinates_aspect_ratio > window_aspect_ratio:
		self.on_info("Coordinates are wider than our window is, clamping width.")
		# Clamp width-wise
		self.window_left = long_min
		self.window_right = long_max
		
		var lat_ctr = (requested_window['n'] + requested_window['s']) / 2.0
		var window_width = self.window_right - self.window_left
		self.window_top = lat_ctr + (window_width / window_aspect_ratio / 2.0)
		self.window_bottom = lat_ctr - (window_width / window_aspect_ratio / 2.0)
	else:
		self.on_info("Coordinates are taller than our window is, clamping height.")	
		# Clamp height-wise
		self.window_top = lat_max
		self.window_bottom = lat_min
		
		var long_ctr = (requested_window['w'] + requested_window['e']) / 2.0
		# Calculate window_left/right by using current aspect ratio
		var window_height = self.window_top - self.window_bottom
		self.window_left = long_ctr - (window_aspect_ratio * window_height / 2.0)
		self.window_right = long_ctr + (window_aspect_ratio * window_height / 2.0)
	
	#self.window_right = requested_window['e']
	#self.window_left = requested_window['w']
	
	# Calculate node vertex position
	for node_id in self.nodes:
		var n = self.nodes[node_id]
		var x = (n['lon'] - self.window_left) / (self.window_right - self.window_left)
		var y = 1.0 - (n['lat'] - self.window_bottom) / (self.window_top - self.window_bottom)
		n['pos'] = Vector2(x, y)
	
	# Precalculate vertex positions for line rendering
	for way_id in self.ways:
		var w = self.ways[way_id]
		
		# Generate the line list for the way
		var src_ids = w['nodes']
		
		# To create the destination node ids, shift right by one.
		var dst_ids = src_ids.slice(1, src_ids.size() - 1)
		
		# Last element of src_ids doesn't connect to anything, it ends the way.
		# (The last element *may* be the same as the first, but it also may not be.)
		# Slice the last element off to make the arrays the same length
		src_ids = src_ids.slice(0, src_ids.size() - 2)
		
		assert(src_ids.size() == dst_ids.size())
		for i in range(src_ids.size()):
			var src_node = self.nodes[src_ids[i]]
			var dst_node = self.nodes[dst_ids[i]]
			
			#var a = Line2D()
			#self.line_list.append([src_node['pos'], dst_node['pos']])
			#var screen_size = get_viewport().size
			
			self.line_list.push_back(src_node['pos'] * screen_size)
			self.line_list.push_back(dst_node['pos'] * screen_size)
	
	# Calculate requested window vertex positions
	var w = (requested_window['w'] - self.window_left) / (self.window_right - self.window_left) * screen_size.x
	var e = (requested_window['e'] - self.window_left) / (self.window_right - self.window_left) * screen_size.x
	var n = (requested_window['n'] - self.window_bottom) / (self.window_top - self.window_bottom) * screen_size.y
	var s = (requested_window['s'] - self.window_bottom) / (self.window_top - self.window_bottom) * screen_size.y
	
	self.requested_window_list.push_back(Vector2(w, n))
	self.requested_window_list.push_back(Vector2(w, s))
	
	self.requested_window_list.push_back(Vector2(w, s))
	self.requested_window_list.push_back(Vector2(e, s))
	
	self.requested_window_list.push_back(Vector2(e, s))
	self.requested_window_list.push_back(Vector2(e, n))
	
	self.requested_window_list.push_back(Vector2(e, n))
	self.requested_window_list.push_back(Vector2(w, n))
	update()

func _on_OpenMapsApi_on_map_data(result_object, requested_window):
	self.addFromOpenMapsApi(result_object, requested_window)
