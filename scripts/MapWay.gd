extends Node2D
class_name MapWay

static func node_to_vec(node: Dictionary) -> Vector2:
	return Vector2(node['lon'], node['lat'])

static func create_from_way(
		way: Dictionary, 
		nodes: Dictionary, 
		map_min: Vector2,
		map_max: Vector2,
		map_scale: Vector2,
		line_width: float):
	var new_way = load("res://scripts/MapWay.gd").new()
	new_way.set_name('way %d' % way['id'])
	var way_nodes: Array = way['nodes']
	
	var prev_node = nodes[way_nodes[0]]
	var prev_pos = node_to_vec(prev_node)
	for cur_node_id in way_nodes.slice(1, way_nodes.size() - 1):
		var cur_node = nodes[cur_node_id]
		var cur_pos = node_to_vec(cur_node)

		var segment = MapSegment.new()
		segment.set_name('segment %d - %d' % [prev_node['id'], cur_node_id])
		segment.segment_width = line_width
		segment.segment_begin = prev_pos
		segment.segment_end = cur_pos
		new_way.add_child(segment)

		prev_node = cur_node
		prev_pos = cur_pos
	
	return new_way

func _ready():
	pass

