package textures

import "core:fmt"
import rl "vendor:raylib"

BuildingTextureId :: enum {
	SkyscraperCrownPlaza,
	SkyscraperAtlasHotel,
}

BuildingTextures :: struct {
	albedo, normal: rl.Texture2D,
}

UiTextureId :: enum {
	Circle,
	Ring,
	Square,
	Box,
	Tick,
}

exe_path: string
exe_dir: string

building_textures: map[BuildingTextureId]BuildingTextures
ui_textures: map[UiTextureId]rl.Texture2D

load_textures :: proc(asset_dir: string) {
	building_textures = make(map[BuildingTextureId]BuildingTextures, len(BuildingTextureId))
	texture_file_path, normal_texture_file_path: cstring
	for id in BuildingTextureId {
		switch id {
		case .SkyscraperCrownPlaza:
			texture_file_path = fmt.caprintf("%s/images/skyscraper_crown_plaza.png", asset_dir)
			normal_texture_file_path = fmt.caprintf(
				"%s/images/skyscraper_crown_plaza_normal.png",
				asset_dir,
			)
		case .SkyscraperAtlasHotel:
			texture_file_path = fmt.caprintf("%s/images/atlas_hotel.png", asset_dir)
			normal_texture_file_path = fmt.caprintf("%s/images/atlas_hotel.png", asset_dir)
		}
		building_textures[id] = {
			rl.LoadTexture(texture_file_path),
			rl.LoadTexture(normal_texture_file_path),
		}
		delete(texture_file_path)
		delete(normal_texture_file_path)
	}

	ui_textures = make(map[UiTextureId]rl.Texture2D, len(UiTextureId))

	for id in UiTextureId {
		switch id {
		case .Circle:
			texture_file_path = fmt.caprintf("%s/images/ui/circle.png", asset_dir)
		case .Ring:
			texture_file_path = fmt.caprintf("%s/images/ui/ring.png", asset_dir)
		case .Square:
			texture_file_path = fmt.caprintf("%s/images/ui/square.png", asset_dir)
		case .Box:
			texture_file_path = fmt.caprintf("%s/images/ui/box.png", asset_dir)
		case .Tick:
			texture_file_path = fmt.caprintf("%s/images/ui/tick.png", asset_dir)
		}
		tex := rl.LoadTexture(texture_file_path)
		rl.GenTextureMipmaps(&tex)
		rl.SetTextureFilter(tex, .TRILINEAR)
		ui_textures[id] = tex
		delete(texture_file_path)
	}
}

@(fini)
unload_textures :: proc() {
	for _, tex in building_textures {
		rl.UnloadTexture(tex.albedo)
		rl.UnloadTexture(tex.normal)
	}
	delete(building_textures)


	for _, tex in ui_textures {
		rl.UnloadTexture(tex)
	}
	delete(ui_textures)
}
