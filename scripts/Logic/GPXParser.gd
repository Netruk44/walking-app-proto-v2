extends Node

signal error
signal info

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func on_error(message):
	emit_signal("error", message)

func on_info(message):
	emit_signal("info", message)

export var verbose_parsing = false

func on_verbose(message):
	if self.verbose_parsing:
		emit_signal("info", message)

#func GetGpsSegmentsFromGpxFile(gpx_path: String) -> [PoolVector2Array]: # GDScript 2.0 / Godot 4.0
func GetGpsSegmentsFromGpxFile(gpx_path: String):
	#var segments: [PoolVector2Array] = []
	var segments = []

	# GPX is just an xml file. We're interested in the tree under <gpx><trk>
	# <trk> contains a list of <trkseg> elements.
	# Each <trkseg> is a separate, contiguous 'segment' of the overall route
	# <trkseg> contains one or more <trkpt> inside
	# <trkpt> has properties "lat" and "lon" (i.e. <trkpt lat="" lon="">)
	# <trkpt> has its own elements inside it as well, but we're not interested (yet, anyway)

	var current_segment = null
	var parser = XMLParser.new()
	var error = parser.open(gpx_path)
	if error != OK:
		self.on_error("Couldn't open gpx as xml file: Error %d" % error)
		return segments

	while parser.read() == OK:
		# We're only interested in node elements themselves.
		# (Ignore raw text, comments, element end, cdata, etc.)
		match parser.get_node_type():
			XMLParser.NODE_ELEMENT:
				# What kind of element are we looking at?
				var node_name: String = str(parser.get_node_name())
				self.on_verbose("Got node '%s'" % node_name)
				match node_name:
					"trkseg":
						# <trkseg> begin new segment
						self.on_verbose("Starting new segment")
						current_segment = PoolVector2Array()
						#segments.append(current_segment) # This doesn't work, class is passed by value...

					"trkpt":
						# <trkpt> append new point to current segment
						assert(current_segment != null, "Found <trkpt> before <trkseg>?")

						var lat_y: float = float(parser.get_named_attribute_value("lat"))
						var lon_x: float = float(parser.get_named_attribute_value("lon"))

						self.on_verbose("Adding track point to segment (%f, %f)" % [lon_x, lat_y])
						current_segment.append(Vector2(lon_x, lat_y))

					_:
						# Default case, ignore
						self.on_verbose("Ignored.")
						pass

			XMLParser.NODE_ELEMENT_END:
				# If we've reached the end of a trkseg, save the list of points
				if parser.get_node_name() == "trkseg":
					self.on_verbose("Reached <trkseg> end. Saving segment.")
					segments.append(current_segment)
				else:
					self.on_verbose("Ignoring end element for %s" % parser.get_node_name())

			_:
				var node_type_str = ""
				match int(parser.get_node_type()):
					XMLParser.NODE_CDATA:
						node_type_str = "NODE_CDATA"
					XMLParser.NODE_COMMENT:
						node_type_str = "NODE_COMMENT"
					XMLParser.NODE_ELEMENT_END:
						node_type_str = "NODE_ELEMENT_END"
					XMLParser.NODE_NONE:
						node_type_str = "NODE_NONE"
					XMLParser.NODE_TEXT:
						node_type_str = "NODE_TEXT"
					XMLParser.NODE_UNKNOWN:
						node_type_str = "NODE_UNKNOWN"
					_:
						node_type_str = "__Unknown"

				self.on_verbose("Ignoring element of type '%s'" % node_type_str)

	self.on_verbose("Reached end of XML file.")
	var total_points = 0
	for s in segments:
		total_points += s.size()
	self.on_info("Created %d segment(s) with %d points created in total" % [segments.size(), total_points])
	
	return segments
