extends PanelContainer

export var max_lines = 100
var lines = []

# Called when the node enters the scene tree for the first time.
func _ready():
	$ConsoleText.text = ''
	self.lines = []

func log(txt):
	txt = txt.split('\n')
	for i in txt:
		self.lines.append(i)
	
	if self.lines.size() > self.max_lines:
		var end = self.lines.size() - 1
		var begin = end - self.max_lines
		
		self.lines = self.lines.slice(begin, end)
	
	$ConsoleText.text = '\n'.join(self.lines)
	$ConsoleText.scroll_vertical = self.lines.size()
