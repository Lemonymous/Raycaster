extends Sprite2D
# VECTOR MATH METHOD
# Based on: https://lodev.org/cgtutor/raycasting.html

# Screen dimensions where the walls will be drawn.
var screenwidth := 640
var screenheight := 400
var screenbuffer : PackedByteArray
var texturebuffers : Dictionary
var image : Image

@export var player : Player
@export var map : TileMapLayer

# Map dimensions.
@onready var mapwidth = map.get_used_rect().size.x
@onready var mapheight = map.get_used_rect().size.y


func _ready() -> void:
	# Fix the perspective view to top left of screen.
	global_position.x = -screenwidth / 2
	global_position.y = -screenheight / 2
	
	var bytes : PackedByteArray
	bytes.resize(screenwidth * screenheight * 4)
	screenbuffer.resize(screenwidth * screenheight * 4)
	
	## Image method
	#texture = ImageTexture.new()
	#image = Image.create_from_data(screenwidth, screenheight, false, Image.FORMAT_RGBA8, bytes)
	#var image_texture = texture as ImageTexture
	#image_texture.set_image(image)
	
	## Rendering device method
	texture = Texture2DRD.new()
	var rd := RenderingServer.get_rendering_device()
	var texture_format := RDTextureFormat.new()
	texture_format.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	texture_format.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
	texture_format.width = screenwidth
	texture_format.height = screenheight
	texture_format.usage_bits =\
		+ RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT\
		+ RenderingDevice.TEXTURE_USAGE_STORAGE_BIT\
		+ RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT\
		+ RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT
	
	# Create texture on the GPU
	var texture_rid := rd.texture_create(texture_format, RDTextureView.new(), [bytes])
	
	# Read Sprite texture as Texture2DRD
	var texture2DRD := texture as Texture2DRD
	
	# Link texture on GPU to Texture2DRD
	texture2DRD.texture_rd_rid = texture_rid


func _process(delta):
	# Fix the perspective view to top left of screen.
	renderWalls()


func to_color_array(bytes: PackedByteArray) -> PackedVector3Array:
	var colors : PackedVector3Array
	colors.resize(bytes.size() / 3)
	
	for i in range(0, bytes.size(), 3):
		# Extract the RGBA values from the array
		var r = bytes[i]
		var g = bytes[i + 1]
		var b = bytes[i + 2]
		
		# Create a Color object and convert it to a PackedColor
		# Normalize to 0-1 range
		var color = Vector3(r, g, b)
		colors[i/3] = color
	
	return colors


func get_texture_data(tile_id: int) -> PackedVector3Array:
	if !texturebuffers.has(tile_id):
		var source := map.tile_set.get_source(tile_id) as TileSetAtlasSource
		var bytes := source.texture.get_image().get_data()
		texturebuffers[tile_id] = to_color_array(bytes)
	
	return texturebuffers[tile_id]


func renderWalls():
	
	# Map the player's position in the global space.
	var posX:float = player.global_position.x / 64.0
	var posY:float = player.global_position.y / 64.0
	var canvasItem:RID = get_canvas_item()
	
	# Start running through every X column on the screen.
	for x in range(0, screenwidth):
		
		# Set up perspective camera plane and raycast direction.
		var cameraX:float = 2.0 * x / float(screenwidth) - 1.0
		var rayDirX:float = player.dirX + player.planeX * cameraX
		var rayDirY:float = player.dirY + player.planeY * cameraX
		
		# The player's map coordinate, based on global coordinate.
		var mapX:int = map.local_to_map(player.global_position).x
		var mapY:int = map.local_to_map(player.global_position).y
		
		# The distance from player's position to the first X and Y sides.
		var sideDistX:float
		var sideDistY:float
		
		# The overall change in distance between each X and Y side.
		var deltaDistX:float = 1e30 if rayDirX == 0.0 else abs(1.0/rayDirX)
		var deltaDistY:float = 1e30 if rayDirY == 0.0 else abs(1.0/rayDirY)
		
		# Step units for traversing the tilemap.
		var stepX:int
		var stepY:int
		
		# Detect if a tile is hit, which side, and which type.
		var hit := 0
		var side:int
		
		# Determine ray direction to set defaults.
		if rayDirX < 0: # RAY POINTING LEFT
			stepX = -1
			sideDistX = (posX - mapX) * deltaDistX
		else: # RAY POINTING RIGHT
			stepX = 1
			sideDistX = (mapX + 1.0 - posX) * deltaDistX
		if rayDirY < 0: # RAY POINTING UP
			stepY = -1
			sideDistY = (posY - mapY) * deltaDistY
		else: # RAY POINTING DOWN
			stepY = 1
			sideDistY = (mapY + 1.0 - posY) * deltaDistY
			
		# DDA Algorithm
		while hit == 0: # While there has been no detected hit...
			# Iterate and increment the ray until a tile is found or it goes out of bounds.
			if sideDistX < sideDistY:
				sideDistX += deltaDistX
				mapX += stepX
				side = 0
			else:
				sideDistY += deltaDistY
				mapY += stepY
				side = 1
			# Test if tile has a wall.
			if map.get_cell_source_id(Vector2(mapX, mapY)) != -1:
				hit = 1
			# OUT-OF-BOUNDS CATCH
			# This is for testing only, so the game doesn't get stuck in an infinite loop.
			# What we really should do is make it so if it goes past the map boundaries,
			# return the distance to that boundary, but don't draw the wall anyway.
			elif mapX > mapwidth \
			or mapY > mapheight \
			or mapX < 0 \
			or mapY < 0:
				break
		
		# The distance between the camera plane point and the wall collision point.
		var perpWallDist:float
		if side == 0: # The side is in the horizontal direction (E/W).
			perpWallDist = (sideDistX - deltaDistX);
		else: # The side is in the vertical direction (N/S).
			perpWallDist = (sideDistY - deltaDistY);
		
		# Prepare to draw the line representing the wall in the display.
		var lineHeight:int = int(screenheight / perpWallDist)
		
		# Map the coordinates on the rendering surface to draw the walls on.
		var drawStart:int = (-lineHeight / 2) + (screenheight / 2) # Start point.
		if drawStart < 0:
			drawStart = 0
		var drawEnd:int = (lineHeight / 2) + (screenheight / 2) # End point.
		if drawEnd >= screenheight:
			drawEnd = screenheight - 1
		
		# Locate the X coordinate of the tile sprite to slice from.
		var texHeight := 64
		var texWidth := 64
		var texNum := Vector2(mapX, mapY)
		var wallX:float
		if side == 0:
			wallX = posY + perpWallDist * rayDirY
		else:
			wallX = posX + perpWallDist * rayDirX
		wallX -= floor(wallX)
		var texX:int = int(wallX * float(texWidth))
		if side == 0 and rayDirX > 0:
			texX = texWidth - texX - 1
		if side == 1 and rayDirY < 0:
			texX = texWidth - texX - 1
		
		var source_id = map.get_cell_source_id(texNum)
		var tex := get_texture_data(source_id)
		
		# How much to increase the texture coordinate per screen pixel
		var step := 1.0 * texHeight / lineHeight
		# Starting texture coordinate
		var texPos := (drawStart - screenheight / 2 + lineHeight / 2) * step
		for y in range(drawStart, drawEnd):
			# Cast the texture coordinate to integer, and mask with (texHeight - 1) in case of overflow
			var texY := int(texPos) & (texHeight - 1)
			texPos += step
			var texIndex := texX + texY * texHeight
			var color := tex[texIndex]
			# make color darker for y-sides: R, G and B byte each divided through two with a "shift" and an "and"
			if side == 1:
				color *= 0.5
			
			var screenIndex := (x + y * 640) * 4
			screenbuffer[screenIndex] = color.x
			screenbuffer[screenIndex+1] = color.y
			screenbuffer[screenIndex+2] = color.z
			screenbuffer[screenIndex+3] = 255.0
	
	## Image method
	#image.set_data(screenwidth, screenheight, false, Image.FORMAT_RGBA8, screenbuffer)
	#var image_texture = texture as ImageTexture
	#image_texture.update(image)
	#screenbuffer.fill(0)
	
	## Rendering device method
	var rd := RenderingServer.get_rendering_device()
	var texture2DRD := texture as Texture2DRD
	rd.texture_update(texture2DRD.texture_rd_rid, 0, screenbuffer)
	screenbuffer.fill(0)
