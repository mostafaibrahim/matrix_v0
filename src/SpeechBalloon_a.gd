extends Node2D

# Speech balloon node that follows the character
class_name SpeechBalloona

# Customizable properties
@export var text_color: Color = Color.BLACK
@export var text_background_color: Color = Color.WEB_GRAY  # New export for text background
@export var background_color: Color = Color.WHITE
@export var border_color: Color = Color.BLACK
@export var padding: float = 10.0
@export var border_width: float = 2.0
@export var balloon_height: float = 40.0
@export var display_time: float = 3.0  # How long the balloon stays visible

# Node references
var label: Label
var timer: Timer
var balloon_polygon: Polygon2D
var border_polygon: Polygon2D

func _ready():
	# Create the timer for auto-hiding the balloon
	timer = Timer.new()
	timer.one_shot = true
	timer.timeout.connect(_on_timer_timeout)
	add_child(timer)
	
	# Create the balloon shape
	balloon_polygon = Polygon2D.new()
	balloon_polygon.color = background_color
	add_child(balloon_polygon)
	
	# Create the border
	border_polygon = Polygon2D.new()
	border_polygon.color = border_color
	add_child(border_polygon)
	
	# Create the text label
	label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", text_color)
	add_child(label)
	
	# Initially hide the balloon
	hide()

func show_message(message: String):
	# Update the label text
	label.text = message
	label.horizontal_alignment=0
	# Wait for the label to update its size
	await get_tree().process_frame
	
	# Calculate balloon dimensions based on text size
	var text_size = label.size
	var balloon_width = text_size.x + padding * 2
	
	# Create balloon points (rounded rectangle with tail)
	var points = PackedVector2Array([
		Vector2(-balloon_width/2, -balloon_height/2),  # Top left
		Vector2(balloon_width/2, -balloon_height/2),   # Top right
		Vector2(balloon_width/2, balloon_height/2),    # Bottom right
		Vector2(0, balloon_height/2),                  # Bottom middle (start of tail)
		Vector2(-10, balloon_height/2 + 15),          # Tail point
		Vector2(-20, balloon_height/2),               # Bottom middle (end of tail)
		Vector2(-balloon_width/2, balloon_height/2)    # Bottom left
	])
	
	# Update balloon shape
	balloon_polygon.polygon = points
	
	# Create border points (slightly larger)
	var border_points = PackedVector2Array()
	for point in points:
		border_points.append(point + Vector2(border_width, border_width))
	border_polygon.polygon = border_points
	
	# Position the label
	label.position = Vector2(-text_size.x/2+(250*get_parent().get_parent().agentid)-200, -text_size.y/2)
	
	# Show the balloon
	show()
	
	# Start the timer
	timer.start(display_time)

func _on_timer_timeout():
	hide()
