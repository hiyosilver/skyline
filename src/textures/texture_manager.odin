package textures

import rl "vendor:raylib"
import "core:fmt"

BuildingTextureId :: enum {
	SkyscraperCrownPlaza,
	SkyscraperAtlasHotel,
}

BuildingTextures :: struct {
	albedo, normal: rl.Texture2D,
}

exe_path: string
exe_dir: string

building_textures: map[BuildingTextureId]BuildingTextures

load_textures :: proc(asset_dir: string) {
    building_textures = make(map[BuildingTextureId]BuildingTextures, len(BuildingTextureId))
    texture_file_path, normal_texture_file_path: cstring
    for id in BuildingTextureId {
    	switch id {
		case .SkyscraperCrownPlaza:
			texture_file_path = fmt.caprintf("%s/images/skyscraper_crown_plaza.png", asset_dir)
			normal_texture_file_path = fmt.caprintf("%s/images/skyscraper_crown_plaza_normal.png", asset_dir)
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
}

@(fini)
unload_textures :: proc() {
	for _, tex in building_textures {
		rl.UnloadTexture(tex.albedo)
		rl.UnloadTexture(tex.normal)
	}
}