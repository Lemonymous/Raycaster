extends Node2D

var screenwidth := 640
var screenheight := 360


func _ready() -> void:
	global_position.x = -screenwidth / 2
	global_position.y = -screenheight / 2


func _draw():
	draw_rect(Rect2(0, 0, screenwidth, screenheight / 2), Color.SKY_BLUE) # CEILING (TBD: TEXT
	draw_rect(Rect2(0, screenheight / 2, screenwidth, screenheight / 2), Color.GRAY) # FLOOR
