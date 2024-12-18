extends Node2D
# VECTOR MATH METHOD
# Based on: https://lodev.org/cgtutor/raycasting.html

# Screen dimensions where the walls will be drawn.
var screenwidth := 640
var screenheight := 400

@export var player : Player
@export var map : TileMapLayer

# Map dimensions.
@onready var mapwidth = map.get_used_rect().size.x
@onready var mapheight = map.get_used_rect().size.y


func _draw():
	draw_rect(Rect2(0, 0, 640, 200), Color.SKY_BLUE) # CEILING (TBD: TEXT
	draw_rect(Rect2(0, 200, 640, 200), Color.GRAY) # FLOOR
	renderWalls()


func _process(delta):
	# Fix the perspective view to top left of screen.
	self.global_position = Vector2.ZERO - get_canvas_transform().origin
	# Update screen with drawing.
	queue_redraw()


var atlas_textures: Dictionary
func make_or_get_atlas_texture(source: TileSetAtlasSource, tile_id: int) -> AtlasTexture:
	if !atlas_textures.has(tile_id):
		var atlas_texture := AtlasTexture.new()
		atlas_texture.atlas = source.texture
		atlas_textures[tile_id] = atlas_texture
	
	return atlas_textures[tile_id]


func renderWalls():
	
	# Map the player's position in the global space.
	var posX:float = player.global_position.x / 64.0
	var posY:float = player.global_position.y / 64.0
	var canvasItem:RID = get_canvas_item()
	var column_width := 1.0
	
	# Start running through every X column on the screen.
	for x in range(0, screenwidth, column_width):
		
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
		var side:int
		var hit_tile:Vector2
		
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
		while !hit_tile: # While there has been no detected hit...
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
				hit_tile = Vector2(mapX, mapY)
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
		var drawEnd:int = (lineHeight / 2) + (screenheight / 2) # End point.
		
		# Clip and limit column height to viewrect
		var drawStartSrc := 0.0
		var drawEndSrc := 64.0
		if drawStart < 0:
			var fraction_clipped := -float(drawStart) / float(lineHeight)
			drawStartSrc = fraction_clipped * 64.0
			drawStart = 0
		if drawEnd >= screenheight:
			var fraction_clipped := float(drawEnd - screenheight) / float(lineHeight)
			drawEndSrc = (1.0 - fraction_clipped) * 64.0
			drawEnd = screenheight - 1
		
		# Locate the X coordinate of the tile sprite to slice from.
		var texWidth := 64
		var texNum := hit_tile
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
		
		
		var source_id = map.get_cell_source_id(hit_tile)
		var source:TileSetAtlasSource = map.tile_set.get_source(source_id) as TileSetAtlasSource
		var atlas_coord = map.get_cell_atlas_coords(hit_tile)
		var atlas_texture := make_or_get_atlas_texture(source, source_id)
		atlas_texture.region = Rect2(texX, drawStartSrc, 1, drawEndSrc - drawStartSrc)
		#atlas_texture.region = Rect2(texX, 0, 1, 64)
		var texture_rid := atlas_texture.get_rid()
		var rectColumn := Rect2(x, drawStart, column_width, drawEnd - drawStart)
		var color := Color.WHITE
		if side == 1:
			color = Color(0.5, 0.5, 0.5, 1.0)
		RenderingServer.canvas_item_add_texture_rect_region(canvasItem, rectColumn, texture_rid, atlas_texture.region, color)
