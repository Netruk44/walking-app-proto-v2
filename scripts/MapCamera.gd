extends Camera2D

var dragging = false


# Called when the node enters the scene tree for the first time.
func _ready():
	self.offset = get_viewport().size / 2.0

func _unhandled_input(event):
	var handled = false
	
	# Left click - drag
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT:
		dragging = event.pressed
		handled = true
	# Mouse wheel up - zoom in
	elif event is InputEventMouseButton and event.button_index == BUTTON_WHEEL_UP:
		self.zoom *= 1.1
		handled = true
	# Mouse wheel down - zoom out
	elif event is InputEventMouseButton and event.button_index == BUTTON_WHEEL_DOWN:
		self.zoom *= 0.9
		handled = true
	# Touch pad scroll - zoom
	elif event is InputEventPanGesture:
		self.zoom *= (1.0 + event.delta.y)
	# Mouse moved - drag
	elif event is InputEventMouseMotion and self.dragging:
		# Move in the opposite direction as the motion for dragging effect
		self.offset -= event.relative * self.zoom
		handled = true
	
	if handled:
		self.get_tree().set_input_as_handled()
		
	# TODO: Touch screen dragging

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
