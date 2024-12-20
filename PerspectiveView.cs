using Godot;
using System;
using System.Data.SqlTypes;

public partial class PerspectiveView : Godot.Sprite2D
{
	string renderingMethod;
	// Screen dimensions where the walls will be drawn.
	private int screenwidth;
	private int screenheight;
	private byte[] screenbuffer;
	private byte[][] texturebuffers;
	private int[] remap_id_2_index;
	private Image image;

	[Export] public CharacterBody2D player;
	[Export] public TileMapLayer map;
	[Export] public Node2D floorAndCeiling;

	// Map dimensions.
	private int mapwidth;
	private int mapheight;

	public override void _Ready()
	{
		// Arrange textures as bytes
		int source_count = map.TileSet.GetSourceCount();
		texturebuffers = new byte[source_count][];
		int source_id_max = 0;

		for (int i = 0; i < source_count; ++i) {
			int source_id = map.TileSet.GetSourceId(i);
			if (source_id > source_id_max) {
				source_id_max = source_id;
			}
		}

		remap_id_2_index = new int[source_id_max + 1];

		for (int i = 0; i < source_count; ++i)
		{
			int source_id = map.TileSet.GetSourceId(i);
			remap_id_2_index[source_id] = i;
			TileSetAtlasSource source = (TileSetAtlasSource)map.TileSet.GetSource(source_id);

			if (source != null && source.Texture != null) {
				texturebuffers[i] = source.Texture.GetImage().GetData();
			}
		}

		// texturebuffers.
		renderingMethod = (string)ProjectSettings.GetSetting("rendering/renderer/rendering_method");
		GD.Print("Using rendering method: ", renderingMethod);

		screenwidth = (int)floorAndCeiling.Get("screenwidth");
		screenheight = (int)floorAndCeiling.Get("screenheight");
		// Get map dimensions after TileMapLayer is ready
		mapwidth = (int)map.GetUsedRect().Size.X;
		mapheight = (int)map.GetUsedRect().Size.Y;

		// Fix the perspective view to the top left of the screen.
		GlobalPosition = new Vector2(-screenwidth / 2, -screenheight / 2);

		// Resize the screen buffer.
		screenbuffer = new byte[screenwidth * screenheight * 4];

		// Create texture on the GPU
		var bytes = new byte[screenwidth * screenheight * 4];
		var byteArray = new Godot.Collections.Array<byte[]> { bytes };

		if (renderingMethod == "forward_plus")
		{
			// Rendering device method
			Texture = new Texture2Drd();
			var rd = RenderingServer.GetRenderingDevice();
			var textureFormat = new RDTextureFormat
			{
				TextureType = RenderingDevice.TextureType.Type2D,
				Format = RenderingDevice.DataFormat.R8G8B8A8Unorm,
				Width = (uint)screenwidth,
				Height = (uint)screenheight,
				UsageBits = RenderingDevice.TextureUsageBits.SamplingBit
						  | RenderingDevice.TextureUsageBits.StorageBit
						  | RenderingDevice.TextureUsageBits.CanCopyToBit
						  | RenderingDevice.TextureUsageBits.CanUpdateBit
			};

			var texture_rid = rd.TextureCreate(textureFormat, new RDTextureView(), byteArray);

			// Read Sprite texture as Texture2DRD
			var texture2DRD = Texture as Texture2Drd;

			// Link texture on GPU to Texture2DRD
			texture2DRD.TextureRdRid = texture_rid;
		}
		else
		{
			// ImageTexture method
			Texture = new ImageTexture();
			image = Image.CreateFromData(screenwidth, screenheight, false, Image.Format.Rgba8, bytes);
			if (Texture is ImageTexture imageTexture)
			{
				imageTexture.SetImage(image);
			}
		}
	}

	public override void _Process(double delta)
	{
		// Fix the perspective view to the top left of the screen.
		RenderWalls();
	}

	private void RenderWalls()
	{
		// Get player data
		Vector2 playerPosition = (Vector2)player.Get("global_position");
		float playerX = playerPosition.X;
		float playerY = playerPosition.Y;
		float dirX = (float)player.Get("dirX");
		float dirY = (float)player.Get("dirY");
		float planeX = (float)player.Get("planeX");
		float planeY = (float)player.Get("planeY");

		// Map the player's position in the global space.
		float posX = playerPosition.X / 64.0f;
		float posY = playerPosition.Y / 64.0f;

		// Start running through every X column on the screen.
		for (int x = 0; x < screenwidth; x++)
		{
			// Set up perspective camera plane and raycast direction.
			float cameraX = 2.0f * x / screenwidth - 1.0f;
			float rayDirX = dirX + planeX * cameraX;
			float rayDirY = dirY + planeY * cameraX;

			// The player's map coordinate, based on global coordinate.
			Vector2I localToMap = map.LocalToMap(playerPosition);
			int mapX = (int)localToMap.X;
			int mapY = (int)localToMap.Y;

			// The distance from player's position to the first X and Y sides.
			float sideDistX;
			float sideDistY;

			// The overall change in distance between each X and Y side.
			float deltaDistX = rayDirX == 0 ? float.MaxValue : Math.Abs(1.0f / rayDirX);
			float deltaDistY = rayDirY == 0 ? float.MaxValue : Math.Abs(1.0f / rayDirY);

			// Step units for traversing the tilemap.
			int stepX, stepY;

			// Detect if a tile is hit, which side, and which type.
			bool hit = false;
			int side = 0;

			// Determine ray direction to set defaults.
			if (rayDirX < 0)
			{
				stepX = -1;
				sideDistX = (posX - mapX) * deltaDistX;
			}
			else
			{
				stepX = 1;
				sideDistX = (mapX + 1.0f - posX) * deltaDistX;
			}

			if (rayDirY < 0)
			{
				stepY = -1;
				sideDistY = (posY - mapY) * deltaDistY;
			}
			else
			{
				stepY = 1;
				sideDistY = (mapY + 1.0f - posY) * deltaDistY;
			}

			// DDA Algorithm
			while (!hit)
			{
				if (sideDistX < sideDistY)
				{
					sideDistX += deltaDistX;
					mapX += stepX;
					side = 0;
				}
				else
				{
					sideDistY += deltaDistY;
					mapY += stepY;
					side = 1;
				}

				if (map.GetCellSourceId(new Vector2I(mapX, mapY)) != -1)
				{
					hit = true;
				}
				// else if (mapX > mapwidth || mapY > mapheight || mapX < 0 || mapY < 0)
				// {
				// 	break;
				// }
			}

			// The distance between the camera plane point and the wall collision point.
			float perpWallDist = (side == 0) ? (sideDistX - deltaDistX) : (sideDistY - deltaDistY);

			// Prepare to draw the line representing the wall in the display.
			int lineHeight = (int)(screenheight / perpWallDist);

			// Map the coordinates on the rendering surface to draw the walls on.
			int drawStart = (-lineHeight / 2) + (screenheight / 2);
			if (drawStart < 0) drawStart = 0;
			int drawEnd = (lineHeight / 2) + (screenheight / 2);
			if (drawEnd >= screenheight) drawEnd = screenheight - 1;

			// Locate the X coordinate of the tile sprite to slice from.
			int texHeight = 64;
			int texWidth = 64;
			Vector2I texNum = new Vector2I(mapX, mapY);
			float wallX = (side == 0) ? (posY + perpWallDist * rayDirY) : (posX + perpWallDist * rayDirX);
			wallX -= Mathf.Floor(wallX);

			int texX = (int)(wallX * texWidth);
			if (side == 0 && rayDirX > 0) texX = texWidth - texX - 1;
			if (side == 1 && rayDirY < 0) texX = texWidth - texX - 1;

			int source_id = map.GetCellSourceId(texNum);
			int source_index = remap_id_2_index[source_id];

			// How much to increase the texture coordinate per screen pixel
			float step = 1.0f * texHeight / lineHeight;
			// Starting texture coordinate
			float texPos = (drawStart - screenheight / 2 + lineHeight / 2) * step;

			for (int y = drawStart; y < drawEnd; y++)
			{
				int texY = (int)texPos & (texHeight - 1);
				texPos += step;
				int texIndex = (texX + texY * texHeight) * 3;
				int shading = (side == 1) ? 1 : 0;

				int screenIndex = (x + y * screenwidth) * 4;
				screenbuffer[screenIndex] = (byte)(texturebuffers[source_index][texIndex] >> shading);
				screenbuffer[screenIndex + 1] = (byte)(texturebuffers[source_index][texIndex + 1] >> shading);
				screenbuffer[screenIndex + 2] = (byte)(texturebuffers[source_index][texIndex + 2] >> shading);
				screenbuffer[screenIndex + 3] = 255;
			}
		}

		if (renderingMethod == "forward_plus")
		{
			// Rendering device method
			var rd = RenderingServer.GetRenderingDevice();
			var texture2DRD = Texture as Texture2Drd;
			rd.TextureUpdate(texture2DRD.TextureRdRid, 0, screenbuffer);
		}
		else
		{
			// ImageTexture method
			image.SetData(screenwidth, screenheight, false, Image.Format.Rgba8, screenbuffer);
			if (Texture is ImageTexture imageTexture)
			{
				imageTexture.Update(image);
			}
		}

		Array.Clear(screenbuffer, 0, screenbuffer.Length);
	}
}