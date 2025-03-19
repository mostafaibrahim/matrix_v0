extends RigidBody2D
class_name SpeechBody2

# Physics properties
@export var float_speed: float = 20.0  # Speed at which balloons float up
@export var repulsion_strength: float = 10.0  # How strongly balloons push each other
@export var horizontal_dampening: float = 5.0  # Reduces horizontal movement

# Original customizable properties
@export var text_color: Color = Color.GREEN
@export var background_color: Color = Color.TRANSPARENT
@export var border_color: Color = Color.TRANSPARENT
@export var padding: float = 10.0
@export var border_width: float = 2.0
@export var balloon_height: float = 40.0
@export var display_time: float = 3.0

# Node references
var label: Label
var timer: Timer
var balloon_polygon: Polygon2D
var border_polygon: Polygon2D
var collision_shape: CollisionShape2D

func _ready():
	# Lock rotation and set physics properties
	lock_rotation = true
	gravity_scale = 0.0
	linear_damp = horizontal_dampening
	contact_monitor = true
	max_contacts_reported = 4
	
	# Create collision shape
	collision_shape = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = balloon_height * 0.75
	collision_shape.shape = shape
	add_child(collision_shape)
	
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
	if visible:
		# Keep rotation at 0
		rotation = 0
		
		# Apply constant upward force
		apply_central_force(Vector2.UP * float_speed)
		
		# Dampen horizontal velocity
		var current_velocity = linear_velocity
		if abs(current_velocity.x) > 0.1:
			linear_velocity.x = move_toward(current_velocity.x, 0, horizontal_dampening * delta)
		
		# Handle repulsion from other balloons
		for body in get_colliding_bodies():
			if body is SpeechBalloon:
				var repulsion_dir = global_position - body.global_position
				var repulsion_force = repulsion_strength / max(repulsion_dir.length(), 10.0)
				apply_central_force(repulsion_dir.normalized() * repulsion_force)

func show_message(message: String):
	# Position at camera center
	#var camera = get_viewport().get_camera_2d()
	var camera = get_node("/root/Node2D/Camera2D")
	if camera:
		global_position = camera.get_screen_center_position()
	
	# Original show_message code
	label.text = message
	await get_tree().process_frame
	
	var text_size = label.size
	var balloon_width = text_size.x + padding * 2
	
	var points = PackedVector2Array([
		Vector2(-balloon_width/2, -balloon_height/2),
		Vector2(balloon_width/2, -balloon_height/2),
		Vector2(balloon_width/2, balloon_height/2),
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
	
	show()
	timer.start(display_time)

func _on_timer_timeout():
	# Optional: Add fade out effect
	hide()
	queue_free()  # Remove the balloon completely when done
