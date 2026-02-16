package ui

import "../global"
import "../textures"
import rl "vendor:raylib"

TabBarPosition :: enum {
	Top,
	Right,
	Bottom,
	Left,
}

TabPage :: struct {
	title:   string,
	content: ^Component,
}

TabPanel :: struct {
	pages:            [dynamic]TabPage,
	selected_page:    int,
	tab_bar_position: TabBarPosition,
	root:             ^Component,
	header_box:       ^Component,
	content_area:     ^Component,
}

make_tab_panel :: proc(
	min_size: rl.Vector2,
	texture: rl.Texture2D,
	tab_bar_width: f32 = 40.0,
	tab_bar_position: TabBarPosition = .Top,
	selected_page: int = -1,
	pages: ..TabPage,
) -> ^Component {
	c := new(Component)
	c.min_size = min_size

	header_direction := BoxDirection.Horizontal
	main_direction := BoxDirection.Vertical
	button_size := rl.Vector2{120, tab_bar_width}

	if tab_bar_position == .Left || tab_bar_position == .Right {
		header_direction = BoxDirection.Vertical
		main_direction = BoxDirection.Horizontal
		button_size.xy = button_size.yx
	}

	header := make_box(header_direction, .Fill, .Fill, 2)
	content := make_box(.Vertical, .Fill, .Fill, 0)

	background_panel := make_n_patch_texture_panel(
		texture,
		{},
		6,
		6,
		6,
		6,
		rl.Color{32, 24, 48, 255},
		content,
	)

	for page in pages {
		lbl := make_label(page.title, global.font, 24.0, color = rl.RAYWHITE)

		btn := make_simple_button(
			.OnRelease,
			rl.Color{255, 255, 255, 0},
			rl.Color{255, 255, 255, 0},
			button_size,
			make_n_patch_texture_panel(
				textures.ui_textures[.TabHeader],
				{},
				6,
				6,
				6,
				0,
				rl.Color{32, 24, 48, 255},
				lbl,
			),
			0.0,
		)
		box_add_child(header, btn)
	}

	root := make_box(main_direction, .Start, .Fill, -6)

	if tab_bar_position == .Top || tab_bar_position == .Left {
		box_add_child(root, header)
		box_add_child(root, background_panel)
	} else {
		box_add_child(root, background_panel)
		box_add_child(root, header)
	}

	panel := TabPanel {
		selected_page    = 0,
		root             = root,
		header_box       = header,
		content_area     = content,
		pages            = make([dynamic]TabPage),
		tab_bar_position = tab_bar_position,
	}

	for p in pages do append(&panel.pages, p)

	if len(panel.pages) > 0 {
		box_add_child(content, panel.pages[0].content)
	}

	c.variant = panel

	return c
}

tab_panel_add_page :: proc(panel: ^Component, page: TabPage) {
	if p, ok := &panel.variant.(TabPanel); ok {
		append(&p.pages, page)
	}
}

tab_panel_remove_page :: proc(panel: ^Component, index_to_remove: int) {
	if p, ok := &panel.variant.(TabPanel); ok {
		if len(p.pages) <= index_to_remove {
			return
		}

		ordered_remove(&p.pages, index_to_remove)
	}
}
