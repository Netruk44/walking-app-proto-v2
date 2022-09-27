extends PanelContainer

signal generate_pressed;

# Called when the node enters the scene tree for the first time.
func _ready():
	# Never show error label on startup, even if viewing it in the editor.
	$ContainerHBox/ControlsVBox/LabelsHBox/ErrorLabel.hide()


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

func _on_GenerateButton_pressed():
	# Check for unexpected characters
	var regex = RegEx.new()
	regex.compile('^([+-])?\\d+(\\.\\d*)?$')

	var latEdit = $ContainerHBox/ControlsVBox/CoordsEditHBox/LatitudeHBox/LatitudeEdit
	var latText = latEdit.text
	if not regex.search(latText):
		showError("Latitude isn't a valid number.")
		return

	var longEdit = $ContainerHBox/ControlsVBox/CoordsEditHBox/LongitudeHBox/LongitudeEdit
	var longText = longEdit.text
	if not regex.search(longText):
		showError("Longitude isn't a valid number.")
		return

	var rangeEdit = $ContainerHBox/ControlsVBox/RangeHBox/RangeEdit
	var rangeText = rangeEdit.text
	if not regex.search(rangeText):
		showError("Range isn't a valid number.")
		return

	# Get center GPS coordinate & range
	# TODO: Verify these calculations are consistent with the words lol
	var center_latitude = float(latText)
	var center_longitude = float(longText)
	var r = float(rangeText) / 2.0

	# Get extents
	var e = center_longitude + 1.25 * r # The world isn't square.
	var w = center_longitude - 1.25 * r # It's wider than it is tall.

	var n = center_latitude + r
	var s = center_latitude - r

	# OpenMaps OverPass API expects 
	emit_signal("generate_pressed", {
		"n": n,
		"s": s,
		"e": e,
		"w": w
	})

func _on_ErrorTimer_timeout():
	$ContainerHBox/ControlsVBox/LabelsHBox/ErrorLabel.hide()


func showError(text):
	var label = $ContainerHBox/ControlsVBox/LabelsHBox/ErrorLabel
	label.text = "ERROR: %s" % text
	label.add_color_override("font_color", Color.red)

	if not label.visible:
		label.show()

	var timer = $ContainerHBox/ControlsVBox/LabelsHBox/ErrorTimer
	timer.start()

func showMessage(text):
	var label = $ContainerHBox/ControlsVBox/LabelsHBox/ErrorLabel
	label.remove_color_override("font_color")
	label.text = text

	if not label.visible:
		label.show()

	var timer = $ContainerHBox/ControlsVBox/LabelsHBox/ErrorTimer
	timer.start()

func showPermanentMessage(text):
	# Stop timer if running
	var timer = $ContainerHBox/ControlsVBox/LabelsHBox/ErrorTimer
	timer.stop()

	var label = $ContainerHBox/ControlsVBox/LabelsHBox/ErrorLabel
	label.remove_color_override("font_color")
	label.text = text

	if not label.visible:
		label.show()
