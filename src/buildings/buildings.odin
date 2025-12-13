package buildings

import "../input"
import "../textures"
import "core:c"
import "core:fmt"
import rl "vendor:raylib"

Building :: struct {
	position:       rl.Vector2,
	texture_id:     textures.BuildingTextureId,
	texture_offset: rl.Vector2,
	image_data:     rl.Image,
	name:           string,
	hovered:        bool,
	selected:       bool,
}

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
		fmt.caprintf("%s/shaders/building_shader.glsl", asset_dir),
	)

	time_loc = rl.GetShaderLocation(building_shader, "time")
	texture_size_loc = rl.GetShaderLocation(building_shader, "textureSize")
	tint_color_loc = rl.GetShaderLocation(building_shader, "tintColor")
	hovered_loc = rl.GetShaderLocation(building_shader, "hovered")
	selected_loc = rl.GetShaderLocation(building_shader, "selected")
	normal_map_loc = rl.GetShaderLocation(building_shader, "normalMap")
}

@(fini)
finish :: proc() {
	rl.UnloadShader(building_shader)
}

draw_building :: proc(building: ^Building) {
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

	tint_color := [3]f32{0.15, 0.75, 0.0}
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
	building: ^Building,
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
