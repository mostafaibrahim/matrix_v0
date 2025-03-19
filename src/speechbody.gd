extends RigidBody2D  # Changed from Node2D to RigidBody2D
class_name SpeechBody

# Physics properties
@export var follow_strength: float = 10.0  # How strongly the balloon follows its target
@export var repulsion_strength: float = -10.0  # How strongly balloons push each other away
@export var max_distance: float = 1.0  # Maximum distance balloon can drift from target

# Original customizable properties
@export var text_color: Color = Color.BLACK
@export var text_background_color: Color = Color.WEB_GRAY
@export var background_color: Color = Color.WHITE
@export var border_color: Color = Color.BLACK
@export var padding: float = 10.0
@export var border_width: float = 2.0
@export var balloon_height: float = 40.0
@export var display_time: float = 3.0
@export var line_color: Color = Color.BLACK  # Color for the connection line
@export var line_width: float = 2.0  # Width of the connection line

# Node references
var label: Label
var timer: Timer
var balloon_polygon: Polygon2D
var border_polygon: Polygon2D
var connection_line: Line2D  # New line node
var collision_shape: CollisionShape2D
var target_position: Vector2
var initial_offset: Vector2 = Vector2(0, -50)  # Offset above character

func _ready():
	# Set up physics properties
	lock_rotation = true  # This prevents the balloon from rotating
	gravity_scale =1.0  # Disable gravity
	linear_damp =10.0  # Add some damping to prevent excessive movement
	contact_monitor = true
	max_contacts_reported = 4  # Monitor collisions with other balloons
	
	# Create collision shape
	collision_shape = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = balloon_height * 0.75  # Adjust based on balloon size
	collision_shape.shape = shape
	add_child(collision_shape)
	 # Create connection line
	connection_line = Line2D.new()
	connection_line.width = line_width
	connection_line.default_color = line_color
	connection_line.z_index = -1  # Ensure line appears behind the balloon
	add_child(connection_line)
	
	# Original setup code
	timer = Timer.new()
	timer.one_shot = true
	timer.timeout.connect(_on_timer_timeout)
	add_child(timer)
	
	balloon_polygon = Polygon2D.new()
	balloon_polygon.color = background_color
	add_child(balloon_polygon)
	
	border_polygon = Polygon2D.new()
	border_polygon.color = border_color
	add_child(border_polygon)
	
	label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", text_color)
	add_child(label)
	
	hide()

func _physics_process(delta):
	rotation = 0
	if visible:
		# Get the character's position (assuming the balloon is a child of the character)
		var character_pos = get_parent().global_position
		target_position = character_pos + initial_offset
		
		# Calculate direction to target position
		var direction = target_position - global_position
		var distance = direction.length()
		
		# Apply force to move toward target position
		if distance > max_distance:
			apply_central_force(direction.normalized() * follow_strength * distance)
		
		# Handle repulsion from other balloons
	
		for body in get_colliding_bodies():
			if body is SpeechBody:
				var repulsion_dir = global_position - body.global_position
				var repulsion_force = repulsion_strength / max(repulsion_dir.length(), 10.0)
				apply_central_force(repulsion_dir.normalized() * repulsion_force)
		# Update connection line
		update_connection_line()
func update_connection_line():
	# Convert character position to local coordinates
	var local_char_pos = to_local(get_parent().global_position)
	
	# Set the line points
	connection_line.clear_points()
	connection_line.add_point(Vector2(0, balloon_height/2))  # Bottom of balloon
	connection_line.add_point(local_char_pos)  # Character position

func show_message(message: String):
	# Original show_message code
	label.text = message
	await get_tree().process_frame
	
	var text_size = label.size
	var balloon_width = text_size.x + padding * 2
	
	var points = PackedVector2Array([
		Vector2(-balloon_width/2, -balloon_height/2),
		Vector2(balloon_width/2, -balloon_height/2),
		Vector2(balloon_width/2, balloon_height/2),
		Vector2(0, balloon_height/2),
		Vector2(-10, balloon_height/2 + 15),
		Vector2(-20, balloon_height/2),
		Vector2(-balloon_width/2, balloon_height/2)
	])
	
	balloon_polygon.polygon = points
	
	var border_points = PackedVector2Array()
	for point in points:
		border_points.append(point + Vector2(border_width, border_width))
	border_polygon.polygon = border_points
	
	label.position = Vector2(-text_size.x/2, -text_size.y/2)
	
	# Update collision shape size based on balloon size
	var shape = collision_shape.shape as CircleShape2D
	shape.radius = max(balloon_width, balloon_height) * 0.5
	connection_line.show()
	show()
	timer.start(display_time)

func _on_timer_timeout():
	hide()
