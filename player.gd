class_name Player
extends CharacterBody2D

var speed := 400.0  # move speed in pixels/sec
var rotation_speed := 2.0  # turning speed in radians/sec

# ANGLE MATH
var eyeheight := 32.0 # Default should be half of tile dimension.
var fov := 60.0 # Should be adjustable.

# VECTOR MATH
var dirX:float = 1.0
var dirY:float = 0.0
var planeX:float = 0.0
var planeY:float = 0.66

func _physics_process(delta):
	# Pick up the input.
	var move_input = Input.get_axis("move_backward", "move_forward")
	var strafe_input = Input.get_axis("strafe_left", "strafe_right")
	var rotation_direction = Input.get_axis("turn_left", "turn_right")
	# Make the transformations.
	
	# Change the direction and plane vectors.
	# FOR VECTOR MATH METHOD
	# THIS IS UNDER TESTING; DO NOT REMOVE THIS OR THE DIRVEC/PLANEVEC NODES
	if rotation_direction < 0: # Turning Left
		var oldDirX:float = dirX
		dirX = dirX * cos(deg_to_rad(-rotation_speed)) - dirY * sin(deg_to_rad(-rotation_speed))
		dirY = oldDirX * sin(deg_to_rad(-rotation_speed)) + dirY * cos(deg_to_rad(-rotation_speed))
		var oldPlaneX:float = planeX
		planeX = planeX * cos(deg_to_rad(-rotation_speed)) - planeY * sin(deg_to_rad(-rotation_speed))
		planeY = oldPlaneX * sin(deg_to_rad(-rotation_speed)) + planeY * cos(deg_to_rad(-rotation_speed))
	elif rotation_direction > 0: # Turning Right
		var oldDirX:float = dirX
		dirX = dirX * cos(deg_to_rad(rotation_speed)) - dirY * sin(deg_to_rad(rotation_speed))
		dirY = oldDirX * sin(deg_to_rad(rotation_speed)) + dirY * cos(deg_to_rad(rotation_speed))
		var oldPlaneX:float = planeX
		planeX = planeX * cos(deg_to_rad(rotation_speed)) - planeY * sin(deg_to_rad(rotation_speed))
		planeY = oldPlaneX * sin(deg_to_rad(rotation_speed)) + planeY * cos(deg_to_rad(rotation_speed))
	
	# Ensure player movement direction and camera is in perfect sync
	self.rotation = atan2(dirY, dirX)
	self.velocity = self.transform.x * move_input * speed + self.transform.y * strafe_input * speed
	
	# Complete the movement.
	move_and_slide()
