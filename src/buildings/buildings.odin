package buildings

import "../input"
import "../textures"
import "../types"
import "core:c"
import "core:fmt"
import rl "vendor:raylib"

building_shader: rl.Shader
time_loc: c.int
texture_size_loc: c.int
tint_color_loc: c.int
hovered_loc: c.int
selected_loc: c.int
normal_map_loc: c.int

load_building_data :: proc(asset_dir: string) {
	building_shader = rl.LoadShader(
		nil,
		fmt.ctprintf("%s/shaders/building_shader.glsl", asset_dir),
	)

	time_loc = rl.GetShaderLocation(building_shader, "time")
	texture_size_loc = rl.GetShaderLocation(building_shader, "textureSize")
	tint_color_loc = rl.GetShaderLocation(building_shader, "tintColor")
	hovered_loc = rl.GetShaderLocation(building_shader, "hovered")
	selected_loc = rl.GetShaderLocation(building_shader, "selected")
	normal_map_loc = rl.GetShaderLocation(building_shader, "normalMap")
}

generate_buildings :: proc(buildings_list: ^[dynamic]types.Building) {
	building_crown_plaza := types.Building {
		id = 100,
		position = {400.0, 800.0},
		texture_id = .SkyscraperCrownPlaza,
		texture_offset = {96.0, 1088.0},
		image_data = rl.LoadImageFromTexture(textures.building_textures[.SkyscraperCrownPlaza]),
		name = "Crown Plaza Tower",
		purchase_price = types.PurchasePrice{2_500_000_000.0, 0.0},
		base_tick_income = 120_000.0,
		base_laundering_amount = 25_000.0,
		base_laundering_efficiency = 0.95,
		effect_stats = types.BuildingEffectStats {
			income_multiplier = 1.0,
			laundering_amount_multiplier = 1.0,
			laundering_efficiency_bonus_flat = 0.0,
		},
	}
	append(buildings_list, building_crown_plaza)

	building_atlas_hotel := types.Building {
		id = 200,
		position = {600.0, 860.0},
		texture_id = .SkyscraperAtlasHotel,
		texture_offset = {77.0, 480.0},
		image_data = rl.LoadImageFromTexture(textures.building_textures[.SkyscraperAtlasHotel]),
		name = "Atlas Hotel",
		purchase_price = types.PurchasePrice{150_000_000.0, 0.0},
		base_tick_income = 35_000.0,
		base_laundering_amount = 5_000.0,
		base_laundering_efficiency = 0.8,
		effect_stats = types.BuildingEffectStats {
			income_multiplier = 1.0,
			laundering_amount_multiplier = 1.0,
			laundering_efficiency_bonus_flat = 0.0,
		},
	}
	append(buildings_list, building_atlas_hotel)

	hotdog_stand_upgrades := make([dynamic]types.Upgrade)
	append(
		&hotdog_stand_upgrades,
		types.Upgrade {
			id = 301,
			name = "TEST: Increase income",
			description = "Increases income by 10%",
			cost = 60.0,
			effect = types.IncomeMultiplier{0.1},
		},
	)

	append(
		&hotdog_stand_upgrades,
		types.Upgrade {
			id = 302,
			name = "TEST: Increase laundering amount",
			description = "Increases laundering amount by 10%",
			cost = 75.0,
			effect = types.LaunderingAmountMultiplier{0.1},
		},
	)

	append(
		&hotdog_stand_upgrades,
		types.Upgrade {
			id = 303,
			name = "TEST: Increase laundering efficiency",
			description = "Increases laundering efficiency by a flat 5%",
			cost = 25.0,
			effect = types.LaunderingEfficiencyBonusFlat{0.05},
		},
	)

	building_hotdog_stand := types.Building {
		id = 300,
		position = {750.0, 950.0},
		texture_id = .HotdogStand,
		texture_offset = {15.0, 15.0},
		image_data = rl.LoadImageFromTexture(textures.building_textures[.HotdogStand]),
		name = "Hotdog stand",
		purchase_price = types.PurchasePrice{500.0, 0.0},
		alt_purchase_price = types.PurchasePrice{250.0, 500.0},
		base_tick_income = 1.5,
		base_laundering_amount = 5.0,
		base_laundering_efficiency = 0.5,
		effect_stats = types.BuildingEffectStats {
			income_multiplier = 1.0,
			laundering_amount_multiplier = 1.0,
			laundering_efficiency_bonus_flat = 0.0,
		},
		upgrades = hotdog_stand_upgrades,
	}
	append(buildings_list, building_hotdog_stand)
}

cleanup :: proc() {
	rl.UnloadShader(building_shader)
}

draw_building :: proc(building: ^types.Building) {
	building_texture := textures.building_textures[building.texture_id]

	rl.BeginShaderMode(building_shader)

	time := f32(rl.GetTime())
	rl.SetShaderValue(building_shader, time_loc, &time, rl.ShaderUniformDataType.FLOAT)

	texture_size := rl.Vector2{f32(building_texture.width), f32(building_texture.height)}
	rl.SetShaderValue(
		building_shader,
		texture_size_loc,
		&texture_size,
		rl.ShaderUniformDataType.VEC2,
	)

	tint_color := building.owned ? [3]f32{0.15, 0.75, 0.0} : [3]f32{1.0, 0.9, 0.3}
	rl.SetShaderValue(building_shader, tint_color_loc, &tint_color, rl.ShaderUniformDataType.VEC3)

	hovered: c.int = building.hovered ? 1 : 0
	rl.SetShaderValue(building_shader, hovered_loc, &hovered, rl.ShaderUniformDataType.INT)

	selected: c.int = building.selected ? 1 : 0
	rl.SetShaderValue(building_shader, selected_loc, &selected, rl.ShaderUniformDataType.INT)

	rl.DrawTexturePro(
		building_texture,
		rl.Rectangle{0.0, 0.0, f32(building_texture.width), f32(building_texture.height)},
		rl.Rectangle {
			building.position.x,
			building.position.y,
			f32(building_texture.width),
			f32(building_texture.height),
		},
		building.texture_offset,
		0.0,
		rl.WHITE,
	)

	rl.EndShaderMode()
}

is_building_hovered :: proc(
	building: ^types.Building,
	input_data: ^input.RawInput,
	camera: ^rl.Camera2D,
) -> bool {
	world_mouse_pos := rl.GetScreenToWorld2D(input_data.mouse_position, camera^)
	building_texture := textures.building_textures[building.texture_id]
	texture_rect := rl.Rectangle {
		building.position.x - building.texture_offset.x,
		building.position.y - building.texture_offset.y,
		f32(building_texture.width),
		f32(building_texture.height),
	}

	//fmt.printfln("mouse_pos: %v", world_mouse_pos)
	//fmt.printfln("texture_rect: %v", texture_rect)

	if world_mouse_pos.x >= texture_rect.x &&
	   world_mouse_pos.x <= texture_rect.x + texture_rect.width &&
	   world_mouse_pos.y >= texture_rect.y &&
	   world_mouse_pos.y <= texture_rect.y + texture_rect.height {
		x := i32(world_mouse_pos.x) - i32(building.position.x) + i32(building.texture_offset.x)
		if x < 0 || x >= building_texture.width {
			return false
		}
		y := i32(world_mouse_pos.y) - i32(building.position.y) + i32(building.texture_offset.y)
		if y < 0 || y >= building_texture.height {
			return false
		}
		pixel_color := rl.GetImageColor(building.image_data, x, y)
		return pixel_color.a > 0.0
	}

	return false
}
