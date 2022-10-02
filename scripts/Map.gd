extends Node2D

signal on_info
signal on_error

const gpx_label = "gpx segment"

enum ZoomType {Fit_Request, Fit_All_Returned_Data}

export var mapLineColor = Color.orange
export var mapStrokeColor = Color.black
export var mapLineWidth = 3.5
export var mapStrokeWidth = 1.0
export var mapAspectRatio = 1.0
export(ZoomType) var zoomToFit = ZoomType.Fit_Request # TODO: Remove
export var oob_size = 5.0
export var renderSegmentGpsPositions = false setget setRenderSegmentGpsPositions

# OpenMaps data
var nodes = {} # id: int64 -> {"lat": float, "lon": float, "id": int64}
var ways = {} # id: int64 -> {"nodes": list<int64>, "id": int64}

var map_scale: Vector2
var gps_min: Vector2
var gps_max: Vector2
var traversed_segments = []

func on_info(txt):
	emit_signal("on_info", txt)
	
func on_error(txt):
	emit_signal("on_error", txt)


func _ready():
	pass # Replace with function body.
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

func reset():
	self.nodes = {}
	self.ways = {}
	self.traversed_segments = []
	
	# Remove all child nodes
	for n in get_children():
		n.queue_free()

func createNewFromOpenMapsApi(map_data, requested_window):
	self.reset()
	self.on_info("Got maps data containing %d object(s)." % map_data['elements'].size())
	self.on_info("Parsing...")

	var screen_size = get_viewport().size
	var min_side = min(screen_size.x, screen_size.y)
	self.map_scale = Vector2(min_side, min_side)
	
	# Raw GPS coordinates need to be scaled if they're appearing on a map
	# or else the aspect ratio looks wrong due to the fact that 1 degree latitude
	# is not the same distance as 1 degree longitude.
	map_scale *= Vector2(1.0/1.25, 1.0) # Experimentally arrived at, probably not correct

	# GPS is y+ upward | Godot is y+ downward
	map_scale.y *= -1.0

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
	
	# Save min/max values
	self.gps_min = Vector2(map_long_min_w, map_lat_min_s)
	self.gps_max = Vector2(map_long_max_e, map_lat_max_n)

	# Calculate node local x/y
	var local_node_pos = {}

	for node_id in self.nodes:
		var n = self.nodes[node_id]
		var pos = Vector2(n['lon'], n['lat'])
		pos -= self.gps_min
		pos /= (self.gps_max - self.gps_min)
		local_node_pos[node_id] = pos

	# Calculate "out of bounds" area local x/y
	var min_points = (Vector2(requested_window['w'], requested_window['s']) - gps_min) / (gps_max - gps_min)
	var max_points = (Vector2(requested_window['e'], requested_window['n']) - gps_min) / (gps_max - gps_min)

	var oob_area = Polygon2D.new()
	add_child(oob_area)
	oob_area.set_name('out of bounds')
	oob_area.z_index = 1
	oob_area.color = Color.black
	oob_area.color.a = 0.25
	var oob_points = PoolVector2Array()
	# Inner window points
	oob_points.append(Vector2(min_points.x, min_points.y) * self.map_scale)
	oob_points.append(Vector2(max_points.x, min_points.y) * self.map_scale)
	oob_points.append(Vector2(max_points.x, max_points.y) * self.map_scale)
	oob_points.append(Vector2(min_points.x, max_points.y) * self.map_scale)

	# Back to top left corner
	oob_points.append(Vector2(min_points.x, min_points.y) * self.map_scale)

	# OOB window points, starting at top left corner
	oob_points.append(Vector2(-oob_size, -oob_size) * self.map_scale)
	oob_points.append(Vector2(-oob_size, max_points.y + oob_size) * self.map_scale)
	oob_points.append(Vector2(max_points.x + oob_size, max_points.y + oob_size) * self.map_scale)
	oob_points.append(Vector2(max_points.x + oob_size, -oob_size) * self.map_scale)

	# Back to top left corner, shape will auto-close and connect back to (0,0)
	oob_points.append(Vector2(-oob_size, -oob_size) * self.map_scale)
	oob_area.polygon = oob_points

	# Add out of bounds line
	var oob_line = AntialiasedLine2D.new()
	add_child(oob_line)
	oob_line.set_name('out of bounds line')
	oob_line.z_index = 100
	oob_line.default_color = Color.black
	oob_line.default_color.a = 0.5
	oob_line.joint_mode = Line2D.LINE_JOINT_BEVEL

	var oob_line_points = PoolVector2Array()
	# To bevel all 4 corners, we have to start/end mid-line
	oob_line_points.append(Vector2((min_points.x + max_points.x) / 2.0, min_points.y) * self.map_scale)

	oob_line_points.append(Vector2(max_points.x, min_points.y) * self.map_scale)
	oob_line_points.append(Vector2(max_points.x, max_points.y) * self.map_scale)
	oob_line_points.append(Vector2(min_points.x, max_points.y) * self.map_scale)
	oob_line_points.append(Vector2(min_points.x, min_points.y) * self.map_scale)

	oob_line_points.append(Vector2((min_points.x + max_points.x) / 2.0, min_points.y) * self.map_scale)
	oob_line.points = oob_line_points

	# Add lines
	var root_node = Node.new()
	root_node.set_name('WayBackground')
	self.add_child(root_node)

	for way_id in self.ways:
		var w = self.ways[way_id]
		var node_ids = w['nodes']

		# Create line & stroke objects in the scene
		#var line = AntialiasedLine2D.new()
		#add_child(line)
		#line.set_name('way %d' % way_id)
		#line.default_color = self.mapLineColor
		#line.width = self.mapLineWidth
		#line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		#line.end_cap_mode = Line2D.LINE_CAP_ROUND
		#line.joint_mode = Line2D.LINE_JOINT_BEVEL
		#line.round_precision = 4
		var new_way = MapWay.create_from_way(w, self.nodes, gps_min, gps_max, map_scale, self.mapLineWidth)
		add_child(new_way)

		var stroke = AntialiasedLine2D.new()
		root_node.add_child(stroke)
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
			var pos = local_node_pos[node_id]
			points.push_back(pos * self.map_scale)

		#line.points = points
		stroke.points = points

#func add_many_traversed_paths(paths: [PoolVector2Array]): # GDScript 2.0,  Godot 4.0
# Also probably not needed.

func add_traversed_segment(segment: PoolVector2Array):
	self.traversed_segments.push_back(segment)
	
	var segment_root = Node.new()
	segment_root.set_name('%s %d' % [self.gpx_label, self.traversed_segments.size()])
	self.add_child(segment_root)

	for p in segment:
		# Calculate local x/y
		var local_position = Vector2(p)
		local_position -= self.gps_min
		local_position /= (self.gps_max - self.gps_min)
		local_position *= self.map_scale

		# TODO Encapsulate in class
		var traverse_point = Area2D.new()
		traverse_point.translate(local_position)
		traverse_point.collision_layer = 2 # 2 is the 'traversed_points' layer
		traverse_point.collision_mask = 0 # Traverse points don't care about intersections
		traverse_point.z_index = 1
		traverse_point.visible = self.renderSegmentGpsPositions
		segment_root.add_child(traverse_point)
		var traverse_point_size: float = 8.0
		
		var polygon = AntialiasedRegularPolygon2D.new()
		traverse_point.add_child(polygon)
		#polygon.z_index = 1
		polygon.size = Vector2(traverse_point_size, traverse_point_size)
		polygon.sides = 5
		polygon.stroke_width = 0.0
		#polygon.visible = self.renderSegmentGpsPositions
		polygon.color = Color.cornflower
		polygon.color.a = 0.5

		var collision = CollisionShape2D.new()
		collision.shape = CircleShape2D.new()
		collision.shape.radius = traverse_point_size
		traverse_point.add_child(collision)

		#polygon.translate(local_position)

func _on_OpenMapsApi_on_map_data(result_object, requested_window):
	self.createNewFromOpenMapsApi(result_object, requested_window)
	
func setRenderSegmentGpsPositions(val):
	self.on_info("Setting Render Segment GPS Positions to %s" % str(val))
	renderSegmentGpsPositions = val
	
	for c in get_children():
		if c.name.begins_with(self.gpx_label):
			for c2 in c.get_children():
				c2.visible = val
