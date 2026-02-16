package textures

import "core:fmt"
import rl "vendor:raylib"

BuildingTextureId :: enum {
	SkyscraperCrownPlaza,
	SkyscraperAtlasHotel,
	HotdogStand,
}

UiTextureId :: enum {
	Circle,
	Ring,
	Square,
	Box,
	Tick,
	Panel,
	TabHeader,
	ScrollBar,
	CrewSlot,
	CrewSlotOptional,
}

IconTextureId :: enum {
	Brawn,
	Savvy,
	Tech,
	Charisma,
	Repeats,
}

exe_path: string
exe_dir: string

building_textures: map[BuildingTextureId]rl.Texture2D
ui_textures: map[UiTextureId]rl.Texture2D
icon_textures: map[IconTextureId]rl.Texture2D

load_textures :: proc(asset_dir: string) {
	building_textures = make(map[BuildingTextureId]rl.Texture2D, len(BuildingTextureId))
	texture_file_path, normal_texture_file_path: cstring
	for id in BuildingTextureId {
		switch id {
		case .SkyscraperCrownPlaza:
			texture_file_path = fmt.caprintf("%s/images/skyscraper_crown_plaza.png", asset_dir)
		case .SkyscraperAtlasHotel:
			texture_file_path = fmt.caprintf("%s/images/atlas_hotel.png", asset_dir)
		case .HotdogStand:
			texture_file_path = fmt.caprintf("%s/images/hotdog_stand.png", asset_dir)
		}

		tex := rl.LoadTexture(texture_file_path)
		rl.GenTextureMipmaps(&tex)
		rl.SetTextureFilter(tex, .TRILINEAR)

		building_textures[id] = tex
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
		case .Panel:
			texture_file_path = fmt.caprintf("%s/images/ui/panel.png", asset_dir)
		case .TabHeader:
			texture_file_path = fmt.caprintf("%s/images/ui/tab_header.png", asset_dir)
		case .ScrollBar:
			texture_file_path = fmt.caprintf("%s/images/ui/scroll_bar.png", asset_dir)
		case .CrewSlot:
			texture_file_path = fmt.caprintf("%s/images/ui/crew_slot.png", asset_dir)
		case .CrewSlotOptional:
			texture_file_path = fmt.caprintf("%s/images/ui/crew_slot_optional.png", asset_dir)
		}
		tex := rl.LoadTexture(texture_file_path)
		rl.GenTextureMipmaps(&tex)

		if id != .TabHeader {
			rl.SetTextureFilter(tex, .TRILINEAR)
		}

		ui_textures[id] = tex
		delete(texture_file_path)
	}

	for id in IconTextureId {
		switch id {
		case .Brawn:
			texture_file_path = fmt.caprintf("%s/images/ui/icons/brawn.png", asset_dir)
		case .Savvy:
			texture_file_path = fmt.caprintf("%s/images/ui/icons/savvy.png", asset_dir)
		case .Tech:
			texture_file_path = fmt.caprintf("%s/images/ui/icons/tech.png", asset_dir)
		case .Charisma:
			texture_file_path = fmt.caprintf("%s/images/ui/icons/charisma.png", asset_dir)
		case .Repeats:
			texture_file_path = fmt.caprintf("%s/images/ui/icons/repeats.png", asset_dir)
		}
		tex := rl.LoadTexture(texture_file_path)
		rl.GenTextureMipmaps(&tex)
		rl.SetTextureFilter(tex, .TRILINEAR)
		icon_textures[id] = tex
		delete(texture_file_path)
	}
}

cleanup :: proc() {
	for _, tex in building_textures {
		rl.UnloadTexture(tex)
	}
	delete(building_textures)


	for _, tex in ui_textures {
		rl.UnloadTexture(tex)
	}
	delete(ui_textures)

	for _, tex in icon_textures {
		rl.UnloadTexture(tex)
	}
	delete(icon_textures)
}
