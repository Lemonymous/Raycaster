extends Node2D
# ANGLE MATH METHOD
# Based on: https://permadi.com/1996/05/ray-casting-tutorial-table-of-contents/

# Screen dimensions where the walls will be drawn.
var screenwidth = 320
var screenheight = 200

# Screen Center
var screenwcenter = 160
var screenhcenter = 100

@onready var dist_to_proj = screenwcenter / tan(deg_to_rad($"../Player".fov/2))
@onready var angle_bw_rays = $"../Player".fov / screenwidth # IN DEGREES

# Map dimensions.
@onready var mapwidth = $"../Map".get_used_rect().size[0]
@onready var mapheight = $"../Map".get_used_rect().size[1]

func _draw():
	renderWalls()

func _process(delta):
	queue_redraw()

func renderWalls():
	pass
