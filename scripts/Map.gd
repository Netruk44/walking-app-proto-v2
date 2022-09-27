extends Node2D

signal on_info
signal on_error

enum ZoomType {Fit_Request, Fit_All_Returned_Data}

export var mapLineColor = Color.orange
export var mapStrokeColor = Color.black
export var mapLineWidth = 3.5
export var mapStrokeWidth = 1.0
export(ZoomType) var zoomToFit = ZoomType.Fit_Request

# OpenMaps data
var nodes = {} # "id": int64:  {"lat": float, "lon": float}
var ways = {} # "id": int64: {"nodes": list<int64>}

func on_info(txt):
	emit_signal("on_info", txt)
	
func on_error(txt):
	emit_signal("on_error", txt)


func _ready():
	pass # Replace with function body.
	
func _draw():
	pass
	#draw_multiline(self.requested_window_list, Color.green)
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

func reset():
	self.nodes = {}
	self.ways = {}
	
	# Remove all child nodes
	for n in get_children():
		n.queue_free()

func addFromOpenMapsApi(map_data, requested_window):
	self.reset()
	self.on_info("Got maps data containing %d object(s)." % map_data['elements'].size())
	self.on_info("Parsing...")

	var screen_size = get_viewport().size
	var window_aspect_ratio = screen_size.x / screen_size.y
	self.on_info("Window aspect ratio (%d / %d): %f" % [screen_size.x, screen_size.y, window_aspect_ratio])

	for obj in map_data['elements']:
		# Add the object to the appropriate dictionary, nodes or ways
		if obj['type'] == 'node':
			self.nodes[obj['id']] = obj
		elif obj['type'] == 'way':
			self.ways[obj['id']] = obj
		else:
			self.on_error('Unknown object type "%s", ignoring.' % obj['type'])
	
	# Calculate node world positions
	var lat_min = 999.0
	var lat_max = -999.0
	var long_min = 999.0
	var long_max = -999.0
	if self.zoomToFit == ZoomType.Fit_All_Returned_Data:
		# Calculate bounding box for nodes
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
	else:
		lat_min = requested_window['s']
		lat_max = requested_window['n']
		long_min = requested_window['w']
		long_max = requested_window['e']
	
	# Square off the window
	var coordinates_aspect_ratio = (long_max - long_min) / (lat_max - lat_min)
	
	if is_equal_approx(coordinates_aspect_ratio, 1.0):
		pass
	elif coordinates_aspect_ratio > 1.0:
		# Add to latitude
		var lat_center = (lat_min + lat_max) / 2.0
		var long_diff = (long_max - long_min) / 2.0
		self.on_info("lat_max from: %f to %f" % [lat_max, lat_center + long_diff])
		self.on_info("lat_min from: %f to %f" % [lat_min, lat_center - long_diff])
		lat_max = lat_center + long_diff
		lat_min = lat_center - long_diff
	else:
		# Add to longitude
		var long_center = (long_min + long_max) / 2.0
		var lat_diff = (lat_max - lat_min) / 2.0
		self.on_info("long_max from: %f to %f" % [long_max, long_center + lat_diff])
		self.on_info("long_min from: %f to %f" % [long_min, long_center - lat_diff])
		long_max = long_center + lat_diff
		long_min = long_center - lat_diff
	
	for node_id in self.nodes:
		var n = self.nodes[node_id]
		var x = (n['lon'] - long_min) / (long_max - long_min)
		var y = 1.0 - (n['lat'] - lat_min) / (lat_max - lat_min)
		n['pos'] = Vector2(x, y)
	
	# Add lines
	var scale = min(screen_size.x, screen_size.y)
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
		
		# Create line & stroke objects in the scene
		var line = AntialiasedLine2D.new()
		add_child(line)
		line.set_name('way %d' % way_id)
		line.default_color = self.mapLineColor
		line.width = self.mapLineWidth
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		line.joint_mode = Line2D.LINE_JOINT_BEVEL
		
		var stroke = AntialiasedLine2D.new()
		add_child(stroke)
		stroke.set_name('way %d stroke' % way_id)
		stroke.z_index = -1
		stroke.z_as_relative = true
		stroke.default_color = self.mapStrokeColor
		stroke.width = self.mapLineWidth + self.mapStrokeWidth
		stroke.begin_cap_mode = Line2D.LINE_CAP_ROUND
		stroke.end_cap_mode = Line2D.LINE_CAP_ROUND
		stroke.joint_mode = Line2D.LINE_JOINT_BEVEL

		var points = PoolVector2Array()
		for i in range(src_ids.size()):
			var src_node = self.nodes[src_ids[i]]
			var dst_node = self.nodes[dst_ids[i]]
			points.push_back(src_node['pos'] * scale)
			points.push_back(dst_node['pos'] * scale)
			
			#points.push_back(Vector2(src_node['lon'], src_node['lat']))
			#points.push_back(Vector2(dst_node['lon'], dst_node['lat']))

		line.points = points
		stroke.points = points

func _on_OpenMapsApi_on_map_data(result_object, requested_window):
	self.addFromOpenMapsApi(result_object, requested_window)
