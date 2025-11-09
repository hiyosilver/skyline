package textures

import rl "vendor:raylib"
import "core:fmt"

BuildingTextureId :: enum {
	Skyscraper1,
}

exe_path: string
exe_dir: string

building_textures: map[BuildingTextureId]rl.Texture2D

load_textures :: proc(asset_dir: string) {
    building_textures = make(map[BuildingTextureId]rl.Texture2D, len(BuildingTextureId))
    texture_file_path: cstring
    for id in BuildingTextureId {
    	switch id {
		case .Skyscraper1:
			texture_file_path = fmt.caprintf("%s/images/skyscraper_1_larger.png", asset_dir)
    	}
    	building_textures[id] = rl.LoadTexture(texture_file_path)
    	delete(texture_file_path)
    }
}

@(fini)
unload_textures :: proc() {
	for _, tex in building_textures {
		rl.UnloadTexture(tex)
	}
}