extends Node

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func log(txt):
	$UI/ConsolePanel.log(txt)

func _on_GPSCoordsPanel_generate_pressed(coords):
	self.log('Got GPS Coordinates:')
	self.log('  N: %f' % coords['n'])
	self.log('  S: %f' % coords['s'])
	self.log('  E: %f' % coords['e'])
	self.log('  W: %f' % coords['w'])
	
	$Logic/OpenMapsApi.GetHighwaysInGpsRect(coords)

func _on_error(txt):
	self.log("ERROR:")
	self.log(txt)


func _on_info(txt):
	self.log(txt)
