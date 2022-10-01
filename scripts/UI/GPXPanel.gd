extends PanelContainer

signal gpx_opened;
signal render_gps_toggled;

func _on_OpenGpxButton_pressed():
	$FileDialog.show()

func _on_FileDialog_files_selected(paths):
	emit_signal("gpx_opened", paths)

func _on_RenderPositions_toggled(button_pressed):
	emit_signal("render_gps_toggled", button_pressed)
