class_name CameraParams
extends Resource


@export var window_size : Vector2i
@export var offset := Vector2.ZERO
@export var zoom := 1.0


func world_offset() -> Vector2:
	return screen_to_world(Vector2.ZERO)


func screen_to_world(screen_position: Vector2) -> Vector2:
	return offset + (screen_position - 0.5 * Vector2(window_size)) / zoom


func world_to_screen(world_position: Vector2) -> Vector2:
	return (world_position - offset) * zoom + 0.5 * Vector2(window_size)


func _to_string() -> String:
	return "Camera Params: offset: %s zoom: %s" % [offset, zoom]
