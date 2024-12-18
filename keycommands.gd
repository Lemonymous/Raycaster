extends Node


@export var ui : Node


func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("vsync"):
		if not DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_ENABLED:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
		else:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	if event.is_action_pressed("toggle_ui"):
		ui.visible = !ui.visible
