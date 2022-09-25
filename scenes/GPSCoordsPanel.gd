extends PanelContainer


# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

func _on_GenerateButton_pressed():
	setError("Not Implemented!")
	pass

func setError(text):
	var label = $HBoxContainer/VBoxContainer/HBoxContainer2/ErrorLabel
	label.text = "ERROR: %s" % text
	
	if not label.visible:
		label.show()
	
	var timer = $HBoxContainer/VBoxContainer/HBoxContainer2/ErrorTimer
	timer.start()


func _on_ErrorTimer_timeout():
	$HBoxContainer/VBoxContainer/HBoxContainer2/ErrorLabel.hide()
