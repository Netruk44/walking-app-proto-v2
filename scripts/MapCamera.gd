extends Camera2D

var dragging = false


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func _unhandled_input(event):
	#if event.type == InputEvent.MOUSE_BUTTON and event.buton_index == BUTTON_LEFT:
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT:
		dragging = event.pressed
		print("Handled input!")
		self.get_tree().set_input_as_handled()
	elif event is InputEventMouseMotion and self.dragging:
		# Move in the opposite direction as the motion for dragging effect
		self.offset -= event.relative
		self.get_tree().set_input_as_handled()
		
	# TODO: Touch screen dragging

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
