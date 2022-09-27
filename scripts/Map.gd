extends Node2D

signal on_info
signal on_error

enum ZoomType {Fit_Request, Fit_All_Returned_Data}

export var mapLineColor = Color.orange
export var mapStrokeColor = Color.black
export var mapLineWidth = 3.5
export var mapStrokeWidth = 1.0
export var mapAspectRatio = 1.0
export(ZoomType) var zoomToFit = ZoomType.Fit_Request

# OpenMaps data
var nodes = {} # "id": int64:  {"lat": float, "lon": float}
var ways = {} # "id": int64: {"nodes": list<int64>}

var oob_size = 5.0

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
	var map_lat_min_s = requested_window['s']
	var map_lat_max_n = requested_window['n']
	var map_long_min_w = requested_window['w']
	var map_long_max_e = requested_window['e']
	
	# Fix up the map aspect ratio if the requested area isn't correct
	var coordinates_aspect_ratio = (map_long_max_e - map_long_min_w) / (map_lat_max_n - map_lat_min_s)
	
	if is_equal_approx(coordinates_aspect_ratio, mapAspectRatio):
		pass
	elif coordinates_aspect_ratio > mapAspectRatio:
		# Add to latitude/horizontal
		var lat_center = (map_lat_min_s + map_lat_max_n) / 2.0
		var long_diff = (map_long_max_e - map_long_min_w) / 2.0
		map_lat_max_n = lat_center + long_diff / mapAspectRatio
		map_lat_min_s = lat_center - long_diff / mapAspectRatio
	else:
		# Add to longitude/vertical
		var long_center = (map_long_min_w + map_long_max_e) / 2.0
		var lat_diff = (map_lat_max_n - map_lat_min_s) / 2.0
		map_long_max_e = long_center + lat_diff * mapAspectRatio
		map_long_min_w = long_center - lat_diff * mapAspectRatio
	
	for node_id in self.nodes:
		var n = self.nodes[node_id]
		var x = (n['lon'] - map_long_min_w) / (map_long_max_e - map_long_min_w)
		var y = 1.0 - (n['lat'] - map_lat_min_s) / (map_lat_max_n - map_lat_min_s)
		n['pos'] = Vector2(x, y)
	
	# Add "out of bounds" area
	var min_points = Vector2(
		(requested_window['w'] - map_long_min_w) / (map_long_max_e - map_long_min_w), 
		(requested_window['s'] - map_lat_min_s) / (map_lat_max_n - map_lat_min_s))
	var max_points = Vector2(
		(requested_window['e'] - map_long_min_w) / (map_long_max_e - map_long_min_w), 
		(requested_window['n'] - map_lat_min_s) / (map_lat_max_n - map_lat_min_s))
	
	# TODO: Precalculate instead of recreating every time.
	
	var scale = min(screen_size.x, screen_size.y)
	
	# Raw GPS coordinates need to be scaled if they're appearing on a map
	# or else the aspect ratio looks wrong due to the fact that 1 degree latitude
	# is not the same distance as 1 degree longitude.
	scale *= Vector2(1.0/1.25, 1.0) # Experimentally arrived at, probably not correct
	
	var oob_area = Polygon2D.new()
	add_child(oob_area)
	oob_area.set_name('out of bounds')
	oob_area.z_index = 1
	oob_area.color = Color.black
	oob_area.color.a = 0.25
	var oob_points = PoolVector2Array()
	# Inner window points
	oob_points.append(Vector2(min_points.x, min_points.y) * scale)
	oob_points.append(Vector2(max_points.x, min_points.y) * scale)
	oob_points.append(Vector2(max_points.x, max_points.y) * scale)
	oob_points.append(Vector2(min_points.x, max_points.y) * scale)
	
	# Back to top left corner
	oob_points.append(Vector2(min_points.x, min_points.y) * scale)
	
	# OOB window points, starting at top left corner
	oob_points.append(Vector2(-oob_size, -oob_size) * scale)
	oob_points.append(Vector2(-oob_size, max_points.y + oob_size) * scale)
	oob_points.append(Vector2(max_points.x + oob_size, max_points.y + oob_size) * scale)
	oob_points.append(Vector2(max_points.x + oob_size, -oob_size) * scale)
	
	# Back to top left corner, shape will auto-close and connect back to (0,0)
	oob_points.append(Vector2(-oob_size, -oob_size) * scale)
	oob_area.polygon = oob_points
	
	# Add out of bounds line
	var oob_line = AntialiasedLine2D.new()
	add_child(oob_line)
	oob_line.set_name('out of bounds line')
	oob_line.z_index = 2
	oob_line.default_color = Color.black
	oob_line.default_color.a = 0.5
	oob_line.joint_mode = Line2D.LINE_JOINT_BEVEL
	
	var oob_line_points = PoolVector2Array()
	# To bevel all 4 corners, we have to start/end mid-line
	oob_line_points.append(Vector2((min_points.x + max_points.x) / 2.0, min_points.y) * scale)
	
	oob_line_points.append(Vector2(max_points.x, min_points.y) * scale)
	oob_line_points.append(Vector2(max_points.x, max_points.y) * scale)
	oob_line_points.append(Vector2(min_points.x, max_points.y) * scale)
	oob_line_points.append(Vector2(min_points.x, min_points.y) * scale)
	
	oob_line_points.append(Vector2((min_points.x + max_points.x) / 2.0, min_points.y) * scale)
	oob_line.points = oob_line_points
	
	# Add lines
	for way_id in self.ways:
		var w = self.ways[way_id]
		var node_ids = w['nodes']
		
		# Create line & stroke objects in the scene
		var line = AntialiasedLine2D.new()
		add_child(line)
		line.set_name('way %d' % way_id)
		line.default_color = self.mapLineColor
		line.width = self.mapLineWidth
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		line.joint_mode = Line2D.LINE_JOINT_BEVEL
		line.round_precision = 4
		
		var stroke = AntialiasedLine2D.new()
		add_child(stroke)
		stroke.set_name('way %d stroke' % way_id)
		stroke.z_index = -1
		stroke.z_as_relative = true
		stroke.default_color = self.mapStrokeColor
		stroke.width = self.mapLineWidth + self.mapStrokeWidth
		stroke.begin_cap_mode = Line2D.LINE_CAP_ROUND
		stroke.end_cap_mode = Line2D.LINE_CAP_ROUND
		stroke.joint_mode = Line2D.LINE_JOINT_SHARP
		stroke.round_precision = 4

		var points = PoolVector2Array()
		for node_id in node_ids:
			points.push_back(self.nodes[node_id]['pos'] * scale)

		line.points = points
		stroke.points = points

func _on_OpenMapsApi_on_map_data(result_object, requested_window):
	self.addFromOpenMapsApi(result_object, requested_window)
