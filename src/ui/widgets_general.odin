package ui

import "core:mem"
import rl "vendor:raylib"

Panel :: struct {
	child: ^Component,
	color: rl.Color,
}

make_panel :: proc(color: rl.Color, min_size: rl.Vector2, child: ^Component = nil) -> ^Component {
	c := new(Component)

	c.size = min_size
	c.min_size = min_size

	c.variant = Panel {
		color = color,
		child = child,
	}

	return c
}

panel_set_color :: proc(component: ^Component, color: rl.Color) {
	if component == nil do return

	if panel, ok := &component.variant.(Panel); ok {
		panel.color = color
	}
}

TexturePanel :: struct {
	child:      ^Component,
	texture:    rl.Texture2D,
	tint_color: rl.Color,
}

make_texture_panel :: proc(
	texture: rl.Texture2D,
	min_size: rl.Vector2,
	tint_color: rl.Color = rl.WHITE,
	child: ^Component = nil,
) -> ^Component {
	c := new(Component)

	c.size = min_size
	c.min_size = min_size

	c.variant = TexturePanel {
		texture    = texture,
		tint_color = tint_color,
		child      = child,
	}

	return c
}

texture_panel_set_texture :: proc(component: ^Component, texture: rl.Texture2D) {
	if component == nil do return

	if texture_panel, ok := &component.variant.(TexturePanel); ok {
		texture_panel.texture = texture
	}
}

texture_panel_set_tint_color :: proc(component: ^Component, tint_color: rl.Color) {
	if component == nil do return

	if texture_panel, ok := &component.variant.(TexturePanel); ok {
		texture_panel.tint_color = tint_color
	}
}

NPatchTexturePanel :: struct {
	child:                    ^Component,
	texture:                  rl.Texture2D,
	tint_color:               rl.Color,
	left, top, right, bottom: i32,
}

make_n_patch_texture_panel :: proc(
	texture: rl.Texture2D,
	min_size: rl.Vector2,
	left, top, right, bottom: i32,
	tint_color: rl.Color = rl.WHITE,
	child: ^Component = nil,
) -> ^Component {
	c := new(Component)

	c.size = min_size
	c.min_size = min_size

	c.variant = NPatchTexturePanel {
		texture    = texture,
		tint_color = tint_color,
		child      = child,
		left       = left,
		top        = top,
		right      = right,
		bottom     = bottom,
	}

	return c
}

n_patch_texture_panel_set_texture :: proc(component: ^Component, texture: rl.Texture2D) {
	if component == nil do return

	if n_patch_texture_panel, ok := &component.variant.(NPatchTexturePanel); ok {
		n_patch_texture_panel.texture = texture
	}
}

n_patch_texture_panel_set_tint_color :: proc(component: ^Component, tint_color: rl.Color) {
	if component == nil do return

	if texture_panel, ok := &component.variant.(NPatchTexturePanel); ok {
		texture_panel.tint_color = tint_color
	}
}

Pill :: struct {
	child: ^Component,
	color: rl.Color,
}

make_pill :: proc(color: rl.Color, min_size: rl.Vector2, child: ^Component = nil) -> ^Component {
	c := new(Component)

	c.size = min_size
	c.min_size = min_size

	c.variant = Pill {
		color = color,
		child = child,
	}

	return c
}

Label :: struct {
	text_buffer: [256]u8,
	font:        rl.Font,
	font_size:   f32,
	color:       rl.Color,
	alignment:   AnchorType,
}

make_label :: proc(
	text: string,
	font: rl.Font,
	font_size: f32 = 20.0,
	color: rl.Color = rl.BLACK,
	alignment: AnchorType = .Center,
) -> ^Component {
	c := new(Component)
	lbl := Label {
		font      = font,
		font_size = font_size,
		color     = color,
		alignment = alignment,
	}

	copy(lbl.text_buffer[:], text)

	c.variant = lbl

	return c
}

label_set_text :: proc(component: ^Component, text: string) {
	if component == nil do return

	if label, ok := &component.variant.(Label); ok {
		mem.zero(&label.text_buffer[0], len(label.text_buffer))
		copy(label.text_buffer[:], text)

		component.desired_size = {0, 0}
	}
}

label_set_color :: proc(component: ^Component, color: rl.Color) {
	if component == nil do return

	if label, ok := &component.variant.(Label); ok {
		if label.color == color do return

		label.color = color
	}
}

LoadingBar :: struct {
	max, current:     f32,
	color:            rl.Color,
	background_color: rl.Color,
}

make_loading_bar :: proc(
	current, max: f32,
	color: rl.Color,
	bg_color: rl.Color,
	size: rl.Vector2,
) -> ^Component {
	c := new(Component)
	c.desired_size = size
	c.min_size = size
	c.variant = LoadingBar {
		current          = current,
		max              = max,
		color            = color,
		background_color = bg_color,
	}
	return c
}

loading_bar_set_color :: proc(component: ^Component, new_color: rl.Color) {
	if component == nil do return

	if loading_bar, ok := &component.variant.(LoadingBar); ok {
		loading_bar.color = new_color
	}
}

GraphValueGetter :: #type proc(data: rawptr, index: int) -> f32

Graph :: struct {
	child:                                     ^Component,
	color_background, color_grid, color_lines: rl.Color,
	point_size:                                f32,
	data_buffer:                               rawptr,
	data_count:                                int,
	get_value:                                 GraphValueGetter,
	min_val, max_val:                          f32,
	interpolate_points:                        bool,
}

make_graph :: proc(
	min_size: rl.Vector2,
	interpolate_points: bool = false,
	child: ^Component = nil,
) -> ^Component {
	c := new(Component)

	c.size = min_size
	c.min_size = min_size

	c.variant = Graph {
		child              = child,
		color_background   = rl.DARKGRAY,
		color_grid         = rl.Color{128.0, 128.0, 128.0, 128.0},
		color_lines        = rl.ORANGE,
		point_size         = 2.0,
		interpolate_points = interpolate_points,
	}

	return c
}

graph_set_data :: proc(
	component: ^Component,
	data_buffer: rawptr,
	count: int,
	getter: GraphValueGetter,
	min_v, max_v: f32,
) {
	if component == nil do return

	if graph, ok := &component.variant.(Graph); ok {
		graph.data_buffer = data_buffer
		graph.data_count = count
		graph.get_value = getter
		graph.min_val = min_v
		graph.max_val = max_v
	}
}

graph_set_line_color :: proc(component: ^Component, new_color: rl.Color) {
	if component == nil do return

	if graph, ok := &component.variant.(Graph); ok {
		graph.color_lines = new_color
	}
}

graph_set_point_size :: proc(component: ^Component, point_size: f32) {
	if component == nil do return

	if graph, ok := &component.variant.(Graph); ok {
		graph.point_size = point_size
	}
}

RangeIndicator :: struct {
	min_val, max_val, current_val:           f64,
	bar_color, knob_color, background_color: rl.Color,
	show_labels:                             bool, // Optional: Draw "Min" and "Max" text next to it
}

make_range_indicator :: proc(min_v, max_v, current: f64, size: rl.Vector2) -> ^Component {
	c := new(Component)

	c.desired_size = size
	c.min_size = size

	c.variant = RangeIndicator {
		min_val          = min_v,
		max_val          = max_v,
		current_val      = current,
		bar_color        = rl.GRAY,
		knob_color       = rl.WHITE,
		background_color = rl.DARKGRAY,
	}
	return c
}

range_indicator_set_data :: proc(component: ^Component, min_val, max_val, current_val: f64) {
	if component == nil do return

	if range_indicator, ok := &component.variant.(RangeIndicator); ok {
		range_indicator.min_val = min_val
		range_indicator.max_val = max_val
		range_indicator.current_val = current_val
	}
}
