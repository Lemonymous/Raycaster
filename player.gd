class_name Player
extends CharacterBody2D

var speed := 400.0  # move speed in pixels/sec
var rotation_speed := 3.0  # turning speed in radians/sec
var mouse_sensitivity := 0.005

# ANGLE MATH
var eyeheight := 32.0 # Default should be half of tile dimension.
var fov := 60.0 # Should be adjustable.

# VECTOR MATH
var dirX:float = 1.0
var dirY:float = 0.0
var planeX:float = 0.0
var planeY:float = 0.66
var mouse_prev := Vector2.ZERO


func _ready() -> void:
	#Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseMotion
	if mouse_event:
		if mouse_event.relative.x != 0.0:
			var rotation_direction := mouse_event.relative.x * mouse_sensitivity
			var new_dir := Vector2(dirX, dirY).rotated(rotation_direction)
			var new_plane := Vector2(planeX, planeY).rotated(rotation_direction)
			dirX = new_dir.x
			dirY = new_dir.y
			planeX = new_plane.x
			planeY = new_plane.y
			
			# Ensure player movement direction and camera is in perfect sync
			transform.x = new_dir
			transform.y = Vector2(-dirY, dirX)


func _physics_process(delta):
	# Pick up the input.
	var move_input = Input.get_axis("move_backward", "move_forward")
	var strafe_input = Input.get_axis("strafe_left", "strafe_right")
	
	# Make the transformations.
	self.velocity = self.transform.x * move_input * speed + self.transform.y * strafe_input * speed
	
	# Complete the movement.
	move_and_slide()
