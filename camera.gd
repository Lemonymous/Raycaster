class_name Camera2DExt
extends Camera2D


@export var camera_params : CameraParams

## How far you can zoom out.
## The smallest number we can multiply the canvas size with.
@export var min_zoom_factor := 0.01

## How far you can zoom in.
## The largest number we can multiply the canvas size with.
@export var max_zoom_factor := 10.0

## How fast you can zoom in and out
@export var zoom_speed := 0.10

var reset_position : Vector2
var reset_zoom : float


func _ready() -> void:
	reset_position = camera_params.offset
	reset_zoom = camera_params.zoom


func _unhandled_input(event: InputEvent):
	if event is InputEventMouseButton and is_zooming_camera():
		zoom_camera(event)
	
	if event is InputEventMouseMotion and is_panning_camera():
		pan_camera(event)
	
	var window_mode := DisplayServer.window_get_mode()
	if event.is_action_pressed("escape"):
		if window_mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
			window_mode = DisplayServer.WINDOW_MODE_WINDOWED
		DisplayServer.window_set_mode(window_mode)
	
	if event.is_action_pressed("fullscreen"):
		if window_mode != DisplayServer.WINDOW_MODE_FULLSCREEN:
			window_mode = DisplayServer.WINDOW_MODE_FULLSCREEN
		else:
			window_mode = DisplayServer.WINDOW_MODE_WINDOWED
		DisplayServer.window_set_mode(window_mode)
	
	if event.is_action_pressed("reset_camera"):
		camera_params.offset = reset_position
		camera_params.zoom = reset_zoom


func _process(_delta):
	position.x = camera_params.offset.x
	position.y = camera_params.offset.y
	zoom.x = camera_params.zoom
	zoom.y = camera_params.zoom


func zoom_camera(event: InputEventMouseButton):
	if event.is_pressed():
		var zoom_change = event.get_action_strength("zoom_in", true) - event.get_action_strength("zoom_out", true)
		zoom_change *= camera_params.zoom
		camera_params.zoom = clamp(camera_params.zoom + zoom_change * zoom_speed, min_zoom_factor, max_zoom_factor)
		camera_params.offset = get_global_mouse_position() - (get_global_mouse_position() - position) * zoom.x / camera_params.zoom


func is_zooming_camera():
	return Input.get_action_strength("zoom_in", true) - Input.get_action_strength("zoom_out", true) != 0.0


func is_panning_camera():
	var is_panning_with_toggle = Input.is_action_pressed("toggle_pan_camera") and Input.is_action_pressed("pan_camera_while_toggled")
	var is_panning_directly = Input.is_action_pressed("pan_camera")
	return is_panning_with_toggle or is_panning_directly


func pan_camera(event: InputEventMouseMotion):
	camera_params.offset -= event.relative / zoom.x
