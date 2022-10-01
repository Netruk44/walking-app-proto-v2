extends Node

func _ready():
	if not OS.is_debug_build():
		# Don't show console for release builds.
		$UI_CanvasLayer/UI/ConsolePanel.hide()
	
	get_tree().connect("files_dropped", self, "_on_files_dropped")

func log(txt):
	$UI_CanvasLayer/UI/ConsolePanel.log(txt)

func _on_GPSCoordsPanel_generate_pressed(coords):
	if $Logic/OpenMapsApi.is_running():
		$UI_CanvasLayer/UI/GPSCoordsPanel.showError("Request already in progress!")
		return

	self.log('Downloading map data for GPS boundaries:')
	self.log('  N: %f' % coords['n'])
	self.log('  S: %f' % coords['s'])
	self.log('  E: %f' % coords['e'])
	self.log('  W: %f' % coords['w'])

	if $UI_CanvasLayer/UI/ZoomContainer/ZoomCheckbox.pressed:
		$Map.zoomToFit = $Map.ZoomType.Fit_Request
	else:
		$Map.zoomToFit = $Map.ZoomType.Fit_All_Returned_Data

	$UI_CanvasLayer/UI/TabContainer/GPS.showPermanentMessage("Querying for map...")
	$Logic/OpenMapsApi.GetHighwaysInGpsRect(coords)

func _on_OpenMapsApi_on_map_data(result_object, requested_window):
	$UI_CanvasLayer/UI/TabContainer/GPS.showMessage("Successfully retrieved map!")
	$Map.createNewFromOpenMapsApi(result_object, requested_window)

func _on_OpenMapsApi_on_map_error(response_code, body):
	$UI_CanvasLayer/UI/TabContainer/GPS.showError("Request failed, status code %d." % response_code)
	
func _on_files_dropped(files: PoolStringArray, screen: int):
	for f in files:
		if f.ends_with('.gpx'):
			self._open_gpx(f)
		else:
			self._on_error('Cannot open dragged file %s, not a .gpx file.' % f)
	
func _open_gpx(file_path):
	$Map.add_traversed_paths($Logic/GpxParser.GetGpsSegmentsFromGpxFile(file_path))

func _on_error(txt):
	self.log("ERROR:")
	self.log(txt)

func _on_info(txt):
	self.log(txt)


func _on_ConsoleToggle_toggled(button_pressed):
	if button_pressed:
		$UI_CanvasLayer/UI/ConsolePanel.show()
	else:
		$UI_CanvasLayer/UI/ConsolePanel.hide()


func _on_GPX_gpx_opened(files):
	for f in files:
		self._open_gpx(f)
