extends Node

func _ready():
	if not OS.is_debug_build():
		# Don't show console for release builds.
		$UI/ConsolePanel.hide()

func log(txt):
	$UI/ConsolePanel.log(txt)

func _on_GPSCoordsPanel_generate_pressed(coords):
	if $Logic/OpenMapsApi.is_running():
		$UI/GPSCoordsPanel.showError("Request already in progress!")
		return

	self.log('Downloading map data for GPS boundaries:')
	self.log('  N: %f' % coords['n'])
	self.log('  S: %f' % coords['s'])
	self.log('  E: %f' % coords['e'])
	self.log('  W: %f' % coords['w'])

	if $UI/ZoomContainer/ZoomCheckbox.pressed:
		$Map.zoomToFit = $Map.ZoomType.Fit_Request
	else:
		$Map.zoomToFit = $Map.ZoomType.Fit_All_Returned_Data

	$UI/GPSCoordsPanel.showMessage("Querying for map...")
	$Logic/OpenMapsApi.GetHighwaysInGpsRect(coords)

func _on_OpenMapsApi_on_map_data(result_object, requested_window):
	$UI/GPSCoordsPanel.showMessage("Successfully retrieved map!")
	$Map.addFromOpenMapsApi(result_object, requested_window)

func _on_error(txt):
	self.log("ERROR:")
	self.log(txt)

func _on_info(txt):
	self.log(txt)

