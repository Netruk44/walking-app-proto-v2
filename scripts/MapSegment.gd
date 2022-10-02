extends Area2D
class_name MapSegment

export var segment_begin: Vector2 setget update_segment_begin
export var segment_end: Vector2 setget update_segment_end

export var segment_width: float = 3.0
export var untraversed_color: Color = '#e74f4f'#Color.red
export var traversed_color: Color = Color.green

export var map_segments_collision_layer: int = 1 # 1 is the 'map_segments' layer
export var map_segments_collision_mask: int = 2 # 2 is the 'traversed_points' layer

var segment_line: AntialiasedLine2D
var collision_shape: CollisionShape2D

var traversed_points_in_area: int = 0
var points_needed_for_completion: int = 0

func _ready():
	# Set Area2D properties
	self.collision_layer = self.map_segments_collision_layer
	self.collision_mask = self.map_segments_collision_mask
	self.monitoring = true
	self.monitorable = false
	# TODO: Hook up area_entered/area_exited
	self.connect("area_entered", self, "on_area_entered")
	# TODO: Hook up gps points' tree_exiting to a method on us to remove them from our count

	# Create line
	segment_line = AntialiasedLine2D.new()
	segment_line.default_color = untraversed_color
	segment_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	segment_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	segment_line.width = segment_width
	add_child(segment_line)
	self.update_line_points()

	# Add Collision Shape
	collision_shape = CollisionShape2D.new()
	collision_shape.shape = SegmentShape2D.new()
	add_child(collision_shape)
	self.update_collision_shape_points()

func update_line_points():
	if self.segment_line == null:
		return

	var points := PoolVector2Array()
	points.append(segment_begin)
	points.append(segment_end)
	segment_line.points = points

func update_collision_shape_points():
	if self.collision_shape == null:
		return

	self.collision_shape.shape.a = self.segment_begin
	self.collision_shape.shape.b = self.segment_end

func refresh():
	# TODO: This is implicitly based on screen size, since the map scale is
	# based off that.
	self.points_needed_for_completion = max(self.segment_begin.distance_to(self.segment_end), 1)
	self.update_line_points()
	self.update_collision_shape_points()

func refresh_color():
	var progress = float(min(self.traversed_points_in_area, self.points_needed_for_completion)) / float(self.points_needed_for_completion)
	var color: Color = self.untraversed_color.linear_interpolate(self.traversed_color, progress)
	self.segment_line.default_color = color

func update_segment_begin(new_val: Vector2):
	segment_begin = new_val
	self.refresh()

func update_segment_end(new_val: Vector2):
	segment_end = new_val
	self.refresh()

func on_area_entered(other: Area2D):
	self.traversed_points_in_area += 1
	#self.segment_line.default_color = self.traversed_color
	other.connect("tree_exiting", self, "on_traverse_point_removed")
	self.refresh_color()

func on_traverse_point_removed():
	self.traversed_points_in_area -= 1
	self.refresh_color()
