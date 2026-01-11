package ui

import "../textures"
import rl "vendor:raylib"

StackContainer :: struct {
	children: [dynamic]^Component,
}

make_stack :: proc(children: ..^Component) -> ^Component {
	c := new(Component)
	stack := StackContainer {
		children = make([dynamic]^Component),
	}
	for child in children do append(&stack.children, child)
	c.variant = stack
	return c
}

AnchorType :: enum {
	TopLeft,
	Top,
	TopRight,
	Left,
	Center,
	Right,
	BottomLeft,
	Bottom,
	BottomRight,
}

AnchorContainer :: struct {
	child: ^Component,
	type:  AnchorType,
}

make_anchor :: proc(type: AnchorType, child: ^Component = nil) -> ^Component {
	c := new(Component)

	c.variant = AnchorContainer {
		type  = type,
		child = child,
	}

	return c
}

BoxDirection :: enum {
	Vertical,
	Horizontal,
}

BoxMainAlignment :: enum {
	Start,
	Center,
	End,
	Fill,
	SpaceBetween,
	SpaceEvenly,
}

BoxCrossAlignment :: enum {
	Start,
	Center,
	End,
	Fill,
}

BoxContainer :: struct {
	children:        [dynamic]^Component,
	direction:       BoxDirection,
	main_alignment:  BoxMainAlignment,
	cross_alignment: BoxCrossAlignment,
	gap:             int,
}

make_box :: proc(
	direction: BoxDirection,
	main: BoxMainAlignment,
	cross: BoxCrossAlignment,
	gap: int,
	children: ..^Component,
) -> ^Component {
	c := new(Component)

	box := BoxContainer {
		direction       = direction,
		main_alignment  = main,
		cross_alignment = cross,
		gap             = gap,
		children        = make([dynamic]^Component),
	}

	for child in children do append(&box.children, child)

	c.variant = box
	return c
}

box_add_child :: proc(box: ^Component, child: ^Component) {
	if b, ok := &box.variant.(BoxContainer); ok {
		append(&b.children, child)
	}
}

box_remove_child :: proc(box: ^Component, child_to_remove: ^Component) {
	if b, ok := &box.variant.(BoxContainer); ok {
		for child_ptr, i in b.children {
			if child_ptr == child_to_remove {
				ordered_remove(&b.children, i)
				return
			}
		}
	}
}

MarginContainer :: struct {
	child:                                                ^Component,
	margin_top, margin_right, margin_bottom, margin_left: int,
}

make_margin :: proc(
	margin_top, margin_right, margin_bottom, margin_left: int,
	child: ^Component = nil,
) -> ^Component {
	c := new(Component)

	c.variant = MarginContainer {
		margin_top    = margin_top,
		margin_right  = margin_right,
		margin_bottom = margin_bottom,
		margin_left   = margin_left,
		child         = child,
	}

	return c
}

ScrollBarPosition :: enum {
	Right,
	Left,
}

ScrollContainerStyle :: struct {
	scroll_bar_width:                f32,
	scroll_bar_texture_id:           textures.UiTextureId,
	scroll_bar_texture_patch_offset: i32,
	scroll_bar_tint_color:           rl.Color,
	scroll_bar_background_color:     rl.Color,
}

DefaultScrollContainerStyle := ScrollContainerStyle {
	scroll_bar_width                = 16.0,
	scroll_bar_texture_id           = .ScrollBar,
	scroll_bar_texture_patch_offset = 8,
	scroll_bar_tint_color           = rl.Color{92, 64, 138, 255},
	scroll_bar_background_color     = rl.DARKGRAY,
}

ScrollContainer :: struct {
	child:                           ^Component,
	scroll_y:                        f32, // Tracks how far the view is scrolled down
	content_height:                  f32, // Calculated max height of the content
	viewport_height:                 f32, // The height the parent allocated to this container
	scrollable_range:                f32, // content_height - viewport_height
	scroll_bar_dragging:             bool, // Tracks if the scroll bar is currently being dragged
	scroll_bar_width:                f32, // Width of the scroll bar, duh
	scroll_bar_position:             ScrollBarPosition, // Side of the container where scroll bar is
	scroll_bar_texture:              rl.Texture2D, // Texture to use for the scroll bar
	scroll_bar_texture_patch_offset: i32, // NPatch offset for the texture
	scroll_bar_tint_color:           rl.Color, // Color to use for the scroll bar tint
	scroll_bar_background_color:     rl.Color, // Color to use for the scroll bar background
}

make_scroll_container :: proc(
	min_size: rl.Vector2,
	scroll_bar_position: ScrollBarPosition = .Right,
	style: ScrollContainerStyle = DefaultScrollContainerStyle,
	child: ^Component = nil,
) -> ^Component {
	c := new(Component)
	c.min_size = min_size

	clamped_scroll_bar_width := clamp(style.scroll_bar_width, 2.0, style.scroll_bar_width)

	c.variant = ScrollContainer {
		scroll_bar_width                = clamped_scroll_bar_width,
		scroll_bar_position             = scroll_bar_position,
		scroll_bar_texture              = textures.ui_textures[style.scroll_bar_texture_id],
		scroll_bar_texture_patch_offset = style.scroll_bar_texture_patch_offset,
		scroll_bar_tint_color           = style.scroll_bar_tint_color,
		scroll_bar_background_color     = style.scroll_bar_background_color,
		child                           = child,
	}
	return c
}
