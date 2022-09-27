extends PanelContainer

signal gpx_opened;

# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass


func _on_OpenGpxButton_pressed():
	$FileDialog.show()


func _on_FileDialog_files_selected(paths):
	emit_signal("gpx_opened", paths)
