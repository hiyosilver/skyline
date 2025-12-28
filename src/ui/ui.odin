package ui

import "../global"
import "../input"
import "../textures"
import "core:math"
import rl "vendor:raylib"

Component :: struct {
	position, size, min_size, desired_size: rl.Vector2,
	variant:                                ComponentVariant,
	state:                                  ComponentState,
}

ComponentState :: enum {
	Active, //Default
	Hidden, //Invisible, but still takes up space
	Inactive, //Invisible and no area for purposes of space calculation
}

ComponentVariant :: union {
	StackContainer,
	AnchorContainer,
	BoxContainer,
	MarginContainer,
	ScrollContainer,
	Panel,
	TexturePanel,
	Pill,
	SimpleButton,
	NPatchButton,
	RadioButton,
	CheckBox,
	Label,
	LoadingBar,
	Graph,
	RangeIndicator,
	NPatchTexturePanel,
}

make_component :: proc(variant: Component) -> ^Component {
	c := new(Component)
	c^ = variant
	return c
}

update_components_recursive :: proc(component: ^Component, base_rect: rl.Rectangle) {
	get_desired_size(component)
	arrange_components(component, base_rect)
}

@(private = "file")
get_desired_size :: proc(component: ^Component) -> rl.Vector2 {
	if component == nil || component.state == .Inactive do return {}

	desired_size: rl.Vector2

	switch &v in component.variant {
	case StackContainer:
		for child in v.children {
			child_size := get_desired_size(child)
			desired_size.x = max(desired_size.x, child_size.x)
			desired_size.y = max(desired_size.y, child_size.y)
		}
	case AnchorContainer:
		desired_size = get_desired_size(v.child)
	case BoxContainer:
		visible_children := 0
		for child in v.children {
			if child == nil || child.state == .Inactive do continue
			visible_children += 1
		}

		if visible_children > 0 {
			processed_children := 0
			for child in v.children {
				if child == nil || child.state == .Inactive do continue

				child_desired_size := get_desired_size(child)

				if v.direction == .Vertical {
					desired_size.x = max(desired_size.x, child_desired_size.x)
					desired_size.y += child_desired_size.y

					if processed_children < visible_children - 1 {
						desired_size.y += f32(v.gap)
					}
				} else {
					desired_size.x += child_desired_size.x
					if processed_children < visible_children - 1 {
						desired_size.x += f32(v.gap)
					}
					desired_size.y = max(desired_size.y, child_desired_size.y)
				}
				processed_children += 1
			}
		}
	case MarginContainer:
		desired_size = get_desired_size(v.child)
		desired_size.x += f32(v.margin_left + v.margin_right)
		desired_size.y += f32(v.margin_top + v.margin_bottom)
	case ScrollContainer:
		child_desired_size := get_desired_size(v.child)

		desired_size.x = max(component.min_size.x, child_desired_size.x) + v.scroll_bar_width
		desired_size.y = min(child_desired_size.y, component.min_size.y)
	case Panel:
		desired_size = get_desired_size(v.child)
		desired_size = {
			max(component.min_size.x, desired_size.x),
			max(component.min_size.y, desired_size.y),
		}
	case TexturePanel:
		desired_size = get_desired_size(v.child)
		desired_size = {
			max(component.min_size.x, desired_size.x),
			max(component.min_size.y, desired_size.y),
		}
	case NPatchTexturePanel:
		desired_size = get_desired_size(v.child)
		desired_size = {
			max(component.min_size.x, desired_size.x),
			max(component.min_size.y, desired_size.y),
		}
	case Pill:
		child_desired_size := get_desired_size(v.child) + {0.0, 2.0}
		desired_size.x = child_desired_size.x + child_desired_size.y
		desired_size.y = child_desired_size.y
		desired_size = {
			max(component.min_size.x, desired_size.x),
			max(component.min_size.y, desired_size.y),
		}
	case SimpleButton:
		child_desired_size := get_desired_size(v.child)
		desired_size.x = child_desired_size.x + (v.padding * 2)
		desired_size.y = child_desired_size.y + (v.padding * 2)
		desired_size = {
			max(component.min_size.x, desired_size.x),
			max(component.min_size.y, desired_size.y),
		}
	case NPatchButton:
		child_desired_size := get_desired_size(v.child)
		desired_size.x = child_desired_size.x + (v.padding * 2)
		desired_size.y = child_desired_size.y + (v.padding * 2)
		desired_size = {
			max(component.min_size.x, desired_size.x),
			max(component.min_size.y, desired_size.y),
		}
	case Label:
		text := cstring(&v.text_buffer[0])
		desired_size = rl.MeasureTextEx(v.font, text, v.font_size, 2.0)
	case RadioButton, CheckBox, LoadingBar:
		desired_size = component.min_size
	case Graph:
		desired_size = get_desired_size(v.child)
		desired_size = {
			max(component.min_size.x, desired_size.x),
			max(component.min_size.y, desired_size.y),
		}
	case RangeIndicator:
		desired_size = component.min_size
	}

	component.desired_size = desired_size

	return desired_size
}

@(private = "file")
arrange_components :: proc(component: ^Component, actual_rect: rl.Rectangle) {
	if component == nil || component.state == .Inactive do return

	component.position = {actual_rect.x, actual_rect.y}
	component.size = {actual_rect.width, actual_rect.height}

	switch &v in component.variant {
	case StackContainer:
		for child in v.children {
			arrange_components(child, actual_rect)
		}
	case AnchorContainer:
		if v.child != nil {
			child_w := v.child.desired_size.x
			child_h := v.child.desired_size.y

			pos: rl.Vector2

			switch v.type {
			case .TopLeft, .Left, .BottomLeft:
				pos.x = actual_rect.x
			case .Top, .Center, .Bottom:
				pos.x = actual_rect.x + (actual_rect.width - child_w) * 0.5
			case .TopRight, .Right, .BottomRight:
				pos.x = actual_rect.x + actual_rect.width - child_w
			}

			switch v.type {
			case .TopLeft, .Top, .TopRight:
				pos.y = actual_rect.y
			case .Left, .Center, .Right:
				pos.y = actual_rect.y + (actual_rect.height - child_h) * 0.5
			case .BottomLeft, .Bottom, .BottomRight:
				pos.y = actual_rect.y + actual_rect.height - child_h
			}

			child_rect := rl.Rectangle{pos.x, pos.y, child_w, child_h}
			arrange_components(v.child, child_rect)
		}
	case BoxContainer:
		total_content_size: f32 = 0
		valid_children := 0

		for child in v.children {
			if child == nil || child.state == .Inactive do continue
			valid_children += 1

			if v.direction == .Vertical {
				total_content_size += child.desired_size.y
			} else {
				total_content_size += child.desired_size.x
			}
		}

		current_gap := f32(v.gap)

		available_space := v.direction == .Vertical ? actual_rect.height : actual_rect.width

		total_gap_space := f32(max(0, valid_children - 1)) * current_gap
		total_used_space := total_content_size + total_gap_space

		free_space := available_space - total_used_space

		start_offset: f32 = 0.0

		child_forced_size: f32 = 0.0

		switch v.main_alignment {
		case .Start:
			start_offset = 0.0

		case .Center:
			start_offset = free_space * 0.5

		case .End:
			start_offset = free_space

		case .Fill:
			start_offset = 0.0
			remaining_space := available_space - total_used_space

			if valid_children > 0 && remaining_space > 0 {
				child_forced_size = remaining_space / f32(valid_children)
			} else {
				child_forced_size = 0.0
			}

		case .SpaceBetween:
			start_offset = 0.0
			if valid_children > 1 {
				current_gap = (available_space - total_content_size) / f32(valid_children - 1)
			}

		case .SpaceEvenly:
			if valid_children > 0 {
				gap_size := (available_space - total_content_size) / f32(valid_children + 1)
				current_gap = gap_size
				start_offset = gap_size
			}
		}

		cursor := rl.Vector2{actual_rect.x, actual_rect.y}

		if v.direction == .Vertical {
			cursor.y += start_offset
		} else {
			cursor.x += start_offset
		}

		for child in v.children {
			if child == nil || child.state == .Inactive do continue

			child_rect: rl.Rectangle

			if v.direction == .Vertical {
				if v.main_alignment == .Fill {
					child_rect.height = child.desired_size.y + child_forced_size
				} else {
					child_rect.height = child.desired_size.y
				}

				switch v.cross_alignment {
				case .Start:
					child_rect.width = child.desired_size.x
					child_rect.x = actual_rect.x
				case .Center:
					child_rect.width = child.desired_size.x
					child_rect.x = actual_rect.x + (actual_rect.width - child_rect.width) * 0.5
				case .End:
					child_rect.width = child.desired_size.x
					child_rect.x = actual_rect.x + (actual_rect.width - child_rect.width)
				case .Fill:
					child_rect.width = actual_rect.width
					child_rect.x = actual_rect.x
				}

				child_rect.y = cursor.y

				cursor.y += child_rect.height + current_gap

			} else {
				if v.main_alignment == .Fill {
					child_rect.width = child.desired_size.x + child_forced_size
				} else {
					child_rect.width = child.desired_size.x
				}

				switch v.cross_alignment {
				case .Start:
					child_rect.height = child.desired_size.y
					child_rect.y = actual_rect.y
				case .Center:
					child_rect.height = child.desired_size.y
					child_rect.y = actual_rect.y + (actual_rect.height - child_rect.height) * 0.5
				case .End:
					child_rect.height = child.desired_size.y
					child_rect.y = actual_rect.y + (actual_rect.height - child_rect.height)
				case .Fill:
					child_rect.height = actual_rect.height
					child_rect.y = actual_rect.y
				}

				child_rect.x = cursor.x

				cursor.x += child_rect.width + current_gap
			}

			arrange_components(child, child_rect)
		}

	case MarginContainer:
		if v.child != nil {
			child_rect := rl.Rectangle {
				x      = actual_rect.x + f32(v.margin_left),
				y      = actual_rect.y + f32(v.margin_top),
				width  = actual_rect.width - f32(v.margin_left + v.margin_right),
				height = actual_rect.height - f32(v.margin_top + v.margin_bottom),
			}
			arrange_components(v.child, child_rect)
		}

	case ScrollContainer:
		if v.child != nil {
			v.viewport_height = actual_rect.height
			v.content_height = v.child.desired_size.y
			v.scrollable_range = max(0.0, v.content_height - v.viewport_height)

			v.scroll_y = math.clamp(v.scroll_y, 0.0, v.scrollable_range)

			scroll_bar_buffer := (v.content_height > v.viewport_height ? v.scroll_bar_width : 0.0)
			scroll_bar_buffer += 2.0

			child_full_rect := rl.Rectangle {
				actual_rect.x,
				actual_rect.y - math.floor(v.scroll_y),
				actual_rect.width - scroll_bar_buffer,
				v.child.desired_size.y,
			}

			if v.scroll_bar_position == .Left {
				child_full_rect.x += scroll_bar_buffer
			}

			arrange_components(v.child, child_full_rect)
		}

	case Panel:
		if v.child != nil {
			arrange_components(v.child, actual_rect)
		}

	case TexturePanel:
		if v.child != nil {
			arrange_components(v.child, actual_rect)
		}

	case NPatchTexturePanel:
		if v.child != nil {
			arrange_components(v.child, actual_rect)
		}

	case Pill:
		if v.child != nil {
			child_rect := rl.Rectangle {
				x      = actual_rect.x + actual_rect.height * 0.5,
				y      = actual_rect.y,
				width  = actual_rect.width - actual_rect.height,
				height = actual_rect.height,
			}
			arrange_components(v.child, child_rect)
		}

	case SimpleButton:
		if v.child != nil {
			padding_x := v.padding * 2
			padding_y := v.padding * 2

			safe_width := max(0.0, actual_rect.width - padding_x)
			safe_height := max(0.0, actual_rect.height - padding_y)

			child_rect := rl.Rectangle {
				x      = actual_rect.x + v.padding,
				y      = actual_rect.y + v.padding,
				width  = safe_width,
				height = safe_height,
			}

			arrange_components(v.child, child_rect)
		}

	case NPatchButton:
		if v.child != nil {
			padding_x := v.padding * 2
			padding_y := v.padding * 2

			safe_width := max(0.0, actual_rect.width - padding_x)
			safe_height := max(0.0, actual_rect.height - padding_y)

			child_rect := rl.Rectangle {
				x      = actual_rect.x + v.padding,
				y      = actual_rect.y + v.padding,
				width  = safe_width,
				height = safe_height,
			}

			arrange_components(v.child, child_rect)
		}

	case Graph:
		if v.child != nil {
			arrange_components(v.child, actual_rect)
		}

	case Label, LoadingBar, RadioButton, CheckBox, RangeIndicator:
	}
}

handle_input_recursive :: proc(component: ^Component, input_data: ^input.RawInput) -> bool {
	if component == nil || component.state != .Active do return false

	captured := false
	mouse_pos := input_data.mouse_position
	rect := rl.Rectangle {
		component.position.x,
		component.position.y,
		component.size.x,
		component.size.y,
	}

	switch &v in component.variant {
	case StackContainer:
		#reverse for child in v.children {
			if handle_input_recursive(child, input_data) do captured = true
		}
	case AnchorContainer:
		if v.child != nil {
			if handle_input_recursive(v.child, input_data) do captured = true
		}

	case BoxContainer:
		for child in v.children {
			if handle_input_recursive(child, input_data) do captured = true
		}

	case MarginContainer:
		if v.child != nil {
			if handle_input_recursive(v.child, input_data) do captured = true
		}

	case ScrollContainer:
		is_hovered := rl.CheckCollisionPointRec(mouse_pos, rect)

		real_mouse_pos := input_data.mouse_position

		if !is_hovered {
			input_data.mouse_position = {-99999, -99999}
		}

		if v.child != nil {
			if handle_input_recursive(v.child, input_data) do captured = true
		}

		input_data.mouse_position = real_mouse_pos

		if is_hovered {
			if v.scrollable_range > 0.0 && input_data.mouse_wheel_movement != 0.0 {
				captured = true
				scroll_delta := input_data.mouse_wheel_movement * 20.0
				v.scroll_y = math.clamp(v.scroll_y - scroll_delta, 0.0, v.scrollable_range)
			}
		}

		if v.scrollable_range > 0.0 {
			scroll_bar_buffer := (v.content_height > v.viewport_height ? v.scroll_bar_width : 0.0)
			scroll_bar_buffer += 2.0

			scroll_bar_rect: rl.Rectangle

			switch v.scroll_bar_position {
			case .Right:
				scroll_bar_rect = rl.Rectangle {
					component.position.x + component.size.x - scroll_bar_buffer,
					component.position.y,
					scroll_bar_buffer,
					component.size.y,
				}
			case .Left:
				scroll_bar_rect = rl.Rectangle {
					component.position.x,
					component.position.y,
					scroll_bar_buffer,
					component.size.y,
				}
			}

			scroll_bar_is_hovered := rl.CheckCollisionPointRec(mouse_pos, scroll_bar_rect)
			if scroll_bar_is_hovered {
				captured = true
				if input.is_mouse_button_pressed_this_frame(.LEFT, input_data) {
					v.scroll_bar_dragging = true
				}
			}

			if !input.is_mouse_button_held_down(.LEFT, input_data) {
				v.scroll_bar_dragging = false
			}

			if v.scroll_bar_dragging {
				vertical_position_normalized := clamp(
					(input_data.mouse_position.y - component.position.y) / v.viewport_height,
					0.0,
					1.0,
				)
				v.scroll_y = v.scrollable_range * vertical_position_normalized
			}
		}

	case Panel:
		captured = rl.CheckCollisionPointRec(mouse_pos, rect)
		if v.child != nil {
			if handle_input_recursive(v.child, input_data) do captured = true
		}

	case TexturePanel:
		captured = rl.CheckCollisionPointRec(mouse_pos, rect)
		if v.child != nil {
			if handle_input_recursive(v.child, input_data) do captured = true
		}

	case NPatchTexturePanel:
		captured = rl.CheckCollisionPointRec(mouse_pos, rect)
		if v.child != nil {
			if handle_input_recursive(v.child, input_data) do captured = true
		}

	case Pill:
		captured = rl.CheckCollisionPointRec(mouse_pos, rect)
		if v.child != nil {
			if handle_input_recursive(v.child, input_data) do captured = true
		}

	case SimpleButton:
		is_hovered := rl.CheckCollisionPointRec(mouse_pos, rect)
		mouse_button_pressed := input.is_mouse_button_held_down(.LEFT, input_data)
		mouse_button_just_pressed := input.is_mouse_button_pressed_this_frame(.LEFT, input_data)

		captured = is_hovered

		if v.state != .Disabled {
			if is_hovered {
				if mouse_button_just_pressed {
					v.state = .Pressed
				} else if !mouse_button_pressed && v.state == .Pressed {
					v.state = .Released
				} else if !mouse_button_pressed {
					v.state = .Hovered
				}
			} else {
				v.state = .Idle
			}
		}

		if v.child != nil {
			if handle_input_recursive(v.child, input_data) do captured = true
		}

	case NPatchButton:
		is_hovered := rl.CheckCollisionPointRec(mouse_pos, rect)
		mouse_button_pressed := input.is_mouse_button_held_down(.LEFT, input_data)
		mouse_button_just_pressed := input.is_mouse_button_pressed_this_frame(.LEFT, input_data)

		captured = is_hovered

		if v.state != .Disabled {
			if is_hovered {
				if mouse_button_just_pressed {
					v.state = .Pressed
				} else if !mouse_button_pressed && v.state == .Pressed {
					v.state = .Released
				} else if !mouse_button_pressed {
					v.state = .Hovered
				}
			} else {
				v.state = .Idle
			}
		}

		if v.child != nil {
			if handle_input_recursive(v.child, input_data) do captured = true
		}

	case RadioButton:
		center := rl.Vector2{rect.x + rect.width * 0.5, rect.y + rect.height * 0.5}
		is_hovered := rl.Vector2Distance(center, mouse_pos) <= rect.width * 0.5
		mouse_button_pressed := input.is_mouse_button_held_down(.LEFT, input_data)
		mouse_button_just_pressed := input.is_mouse_button_pressed_this_frame(.LEFT, input_data)

		captured = is_hovered

		if v.state != .Disabled {
			if is_hovered {
				if mouse_button_just_pressed {
					v.state = .Pressed
				} else if !mouse_button_pressed && v.state == .Pressed {
					if !v.selected {
						v.state = .Released
						v.selected = true
						for other_button in v.connected_radio_buttons {
							radio_button_set_state(other_button, false)
						}
					}
				} else if !mouse_button_pressed {
					v.state = .Hovered
				}
			} else {
				v.state = .Idle
			}
		}

	case CheckBox:
		is_hovered := rl.CheckCollisionPointRec(mouse_pos, rect)
		mouse_button_pressed := input.is_mouse_button_held_down(.LEFT, input_data)

		captured = is_hovered

		if v.state != .Disabled {
			if v.state == .Pressed {
				if is_hovered && !mouse_button_pressed {
					v.state = .Released

					v.selected = !v.selected

				} else if !is_hovered && !mouse_button_pressed {
					v.state = .Idle
				}
			} else {
				if is_hovered {
					if mouse_button_pressed {
						v.state = .Pressed
					} else {
						v.state = .Hovered
					}
				} else {
					v.state = .Idle
				}
			}
		}

	case Label, LoadingBar, RangeIndicator:
		captured = rl.CheckCollisionPointRec(mouse_pos, rect)

	case Graph:
		captured = rl.CheckCollisionPointRec(mouse_pos, rect)
		if v.child != nil {
			if handle_input_recursive(v.child, input_data) do captured = true
		}
	}

	return captured
}

draw_components_recursive :: proc(component: ^Component, debug: bool = false) {
	if component == nil || component.state != .Active do return

	switch &v in component.variant {
	case StackContainer:
		for child in v.children {
			draw_components_recursive(child, debug)
		}
	case AnchorContainer:
		draw_components_recursive(v.child, debug)
	case BoxContainer:
		for child in v.children {
			draw_components_recursive(child, debug)
		}
	case MarginContainer:
		draw_components_recursive(v.child, debug)
	case ScrollContainer:
		if v.child != nil {
			if v.scrollable_range > 0.0 {
				scroll_bar_half_width := v.scroll_bar_width * 0.5

				total_content_height := v.viewport_height + v.scrollable_range

				knob_length_raw: f32 = 0.0
				if total_content_height > 0 {
					visible_ratio := v.viewport_height / total_content_height
					knob_length_raw = v.viewport_height * visible_ratio
				}

				scroll_knob_length := clamp(knob_length_raw, 30.0, v.viewport_height)

				track_space_available := v.viewport_height - scroll_knob_length

				scroll_progress: f32 = 0.0
				if v.scrollable_range > 0 {
					scroll_progress = v.scroll_y / v.scrollable_range
				}

				scroll_knob_start := track_space_available * scroll_progress
				scroll_knob_end := scroll_knob_start + scroll_knob_length

				scroll_bar_color := v.scroll_bar_dragging ? rl.WHITE : rl.RAYWHITE

				switch v.scroll_bar_position {
				case .Right:
					rl.DrawCircleV(
						{
							component.position.x + component.size.x - scroll_bar_half_width,
							component.position.y + scroll_bar_half_width,
						},
						scroll_bar_half_width,
						rl.DARKGRAY,
					)
					rl.DrawCircleV(
						{
							component.position.x + component.size.x - scroll_bar_half_width,
							component.position.y + component.size.y - scroll_bar_half_width,
						},
						scroll_bar_half_width,
						rl.DARKGRAY,
					)

					rl.DrawRectangleV(
						{
							component.position.x + component.size.x - v.scroll_bar_width,
							component.position.y + scroll_bar_half_width,
						},
						{v.scroll_bar_width, component.size.y - v.scroll_bar_width},
						rl.DARKGRAY,
					)

					rl.DrawCircleV(
						{
							component.position.x + component.size.x - scroll_bar_half_width,
							component.position.y + scroll_knob_start + scroll_bar_half_width,
						},
						scroll_bar_half_width,
						scroll_bar_color,
					)

					rl.DrawCircleV(
						{
							component.position.x + component.size.x - scroll_bar_half_width,
							component.position.y + scroll_knob_end - scroll_bar_half_width,
						},
						scroll_bar_half_width,
						scroll_bar_color,
					)

					rl.DrawRectangleV(
						{
							component.position.x + component.size.x - v.scroll_bar_width,
							component.position.y + scroll_knob_start + scroll_bar_half_width,
						},
						{v.scroll_bar_width, scroll_knob_length - v.scroll_bar_width},
						scroll_bar_color,
					)
				case .Left:
					rl.DrawCircleV(
						{
							component.position.x + scroll_bar_half_width,
							component.position.y + scroll_bar_half_width,
						},
						scroll_bar_half_width,
						rl.DARKGRAY,
					)
					rl.DrawCircleV(
						{
							component.position.x + scroll_bar_half_width,
							component.position.y + component.size.y - scroll_bar_half_width,
						},
						scroll_bar_half_width,
						rl.DARKGRAY,
					)

					rl.DrawRectangleV(
						{component.position.x, component.position.y + scroll_bar_half_width},
						{v.scroll_bar_width, component.size.y - v.scroll_bar_width},
						rl.DARKGRAY,
					)
					rl.DrawCircleV(
						{
							component.position.x + scroll_bar_half_width,
							component.position.y + scroll_knob_start + scroll_bar_half_width,
						},
						scroll_bar_half_width,
						scroll_bar_color,
					)

					rl.DrawCircleV(
						{
							component.position.x + scroll_bar_half_width,
							component.position.y + scroll_knob_end - scroll_bar_half_width,
						},
						scroll_bar_half_width,
						scroll_bar_color,
					)

					rl.DrawRectangleV(
						{
							component.position.x,
							component.position.y + scroll_knob_start + scroll_bar_half_width,
						},
						{v.scroll_bar_width, scroll_knob_length - v.scroll_bar_width},
						scroll_bar_color,
					)
				}
			}

			rl.BeginScissorMode(
				i32(component.position.x),
				i32(component.position.y),
				i32(component.size.x),
				i32(component.size.y),
			)
			draw_components_recursive(v.child, debug)

			rl.EndScissorMode()
		}
	case Panel:
		rl.DrawRectangleV(component.position, component.size, v.color)
		draw_components_recursive(v.child, debug)
	case TexturePanel:
		source := rl.Rectangle{0, 0, f32(v.texture.width), f32(v.texture.height)}
		dest := rl.Rectangle {
			component.position.x,
			component.position.y,
			component.size.x,
			component.size.y,
		}
		rl.DrawTexturePro(v.texture, source, dest, {}, 0, v.tint_color)
		draw_components_recursive(v.child, debug)
	case NPatchTexturePanel:
		texture := v.texture
		source_rectangle := rl.Rectangle{0, 0, f32(texture.width), f32(texture.height)}

		n_patch_info := rl.NPatchInfo {
			source_rectangle,
			v.left,
			v.top,
			v.right,
			v.bottom,
			.NINE_PATCH,
		}

		rl.DrawTextureNPatch(
			texture,
			n_patch_info,
			{component.position.x, component.position.y, component.size.x, component.size.y},
			{0, 0},
			0.0,
			v.tint_color,
		)
		draw_components_recursive(v.child, debug)
	case Pill:
		offset := component.size.y * 0.5
		rl.DrawCircleV(component.position + {offset, offset}, offset, v.color)
		rl.DrawCircleV(component.position + {component.size.x - offset, offset}, offset, v.color)
		rl.DrawRectangleV(
			component.position + {offset, 0.0},
			{component.size.x - component.size.y, component.size.y},
			v.color,
		)
		draw_components_recursive(v.child, debug)
	case SimpleButton:
		bg_color: rl.Color
		switch v.state {
		case .Idle:
			bg_color = v.color_default
		case .Hovered:
			bg_color = v.color_hovered
		case .Pressed:
			bg_color = v.color_pressed
		case .Released:
			bg_color = v.color_hovered
		case .Disabled:
			bg_color = v.color_disabled
		}

		rl.DrawRectangleV(component.position, component.size, bg_color)

		if v.state == .Pressed {
			rl.DrawRectangleLinesEx(
				rl.Rectangle {
					component.position.x,
					component.position.y,
					component.size.x,
					component.size.y,
				},
				2.0,
				rl.ColorBrightness(bg_color, -0.3),
			)
		}

		draw_components_recursive(v.child, debug)
	case NPatchButton:
		tint_color: rl.Color
		switch v.state {
		case .Idle:
			tint_color = v.tint_color_default
		case .Hovered:
			tint_color = v.tint_color_hovered
		case .Pressed:
			tint_color = v.tint_color_pressed
		case .Released:
			tint_color = v.tint_color_hovered
		case .Disabled:
			tint_color = v.tint_color_disabled
		}

		texture := v.texture
		source_rectangle := rl.Rectangle{0, 0, f32(texture.width), f32(texture.height)}

		n_patch_info := rl.NPatchInfo {
			source_rectangle,
			v.left,
			v.top,
			v.right,
			v.bottom,
			.NINE_PATCH,
		}

		rl.DrawTextureNPatch(
			texture,
			n_patch_info,
			{component.position.x, component.position.y, component.size.x, component.size.y},
			{0, 0},
			0.0,
			tint_color,
		)

		draw_components_recursive(v.child, debug)
	case RadioButton:
		circle_texture := textures.ui_textures[textures.UiTextureId.Circle]
		ring_texture := textures.ui_textures[textures.UiTextureId.Ring]

		ring_color := rl.SKYBLUE
		dot_color := rl.DARKBLUE
		background_color := rl.BLACK
		foreground_color := rl.RAYWHITE

		source := rl.Rectangle{0, 0, f32(circle_texture.width), f32(circle_texture.height)}
		dest := rl.Rectangle {
			component.position.x,
			component.position.y,
			component.size.x,
			component.size.y,
		}
		rl.DrawTexturePro(circle_texture, source, dest, {}, 0, background_color)

		source = rl.Rectangle{0, 0, f32(circle_texture.width), f32(circle_texture.height)}
		dest = rl.Rectangle {
			component.position.x + 1,
			component.position.y + 1,
			component.size.x - 2,
			component.size.y - 2,
		}
		rl.DrawTexturePro(circle_texture, source, dest, {}, 0, foreground_color)

		if v.selected {
			source = rl.Rectangle{0, 0, f32(circle_texture.width), f32(circle_texture.height)}
			dest = rl.Rectangle {
				component.position.x + 5.0,
				component.position.y + 5.0,
				component.size.x - 10.0,
				component.size.y - 10.0,
			}
			rl.DrawTexturePro(circle_texture, source, dest, {}, 0, dot_color)
		}
		if v.state == .Hovered || v.state == .Pressed {
			source = rl.Rectangle{0, 0, f32(ring_texture.width), f32(ring_texture.height)}
			dest = rl.Rectangle {
				component.position.x + 1,
				component.position.y + 1,
				component.size.x - 2,
				component.size.y - 2,
			}
			rl.DrawTexturePro(ring_texture, source, dest, {}, 0, ring_color)
		}
	case CheckBox:
		square_texture := textures.ui_textures[textures.UiTextureId.Square]
		box_texture := textures.ui_textures[textures.UiTextureId.Box]
		tick_texture := textures.ui_textures[textures.UiTextureId.Tick]

		box_color := rl.SKYBLUE
		tick_color := rl.DARKBLUE
		background_color := rl.BLACK
		foreground_color := rl.RAYWHITE

		source := rl.Rectangle{0, 0, f32(square_texture.width), f32(square_texture.height)}
		dest := rl.Rectangle {
			component.position.x,
			component.position.y,
			component.size.x,
			component.size.y,
		}
		rl.DrawTexturePro(square_texture, source, dest, {}, 0, background_color)

		source = rl.Rectangle{0, 0, f32(square_texture.width), f32(square_texture.height)}
		dest = rl.Rectangle {
			component.position.x + 1,
			component.position.y + 1,
			component.size.x - 2,
			component.size.y - 2,
		}
		rl.DrawTexturePro(square_texture, source, dest, {}, 0, foreground_color)

		if v.selected {
			source = rl.Rectangle{0, 0, f32(tick_texture.width), f32(tick_texture.height)}
			dest = rl.Rectangle {
				component.position.x + 1,
				component.position.y + 1,
				component.size.x - 2,
				component.size.y - 2,
			}
			rl.DrawTexturePro(tick_texture, source, dest, {}, 0, tick_color)
		}
		if v.state == .Hovered || v.state == .Pressed {
			source = rl.Rectangle{0, 0, f32(box_texture.width), f32(box_texture.height)}
			dest = rl.Rectangle {
				component.position.x + 1,
				component.position.y + 1,
				component.size.x - 2,
				component.size.y - 2,
			}
			rl.DrawTexturePro(box_texture, source, dest, {}, 0, box_color)
		}
	case Label:
		text := cstring(&v.text_buffer[0])

		text_dims := rl.MeasureTextEx(v.font, text, v.font_size, 2.0)

		pos := component.position

		#partial switch v.alignment {
		case .Top, .Center, .Bottom:
			pos.x += (component.size.x - text_dims.x) * 0.5
		case .TopRight, .Right, .BottomRight:
			pos.x += (component.size.x - text_dims.x)
		case:
		}

		#partial switch v.alignment {
		case .Left, .Center, .Right:
			pos.y += (component.size.y - text_dims.y) * 0.5
			pos.y += v.font_size * 0.1
		case .BottomLeft, .Bottom, .BottomRight:
			pos.y += (component.size.y - text_dims.y)
		case:
		}

		rl.DrawTextEx(v.font, text, pos, v.font_size, 2.0, v.color)
	case LoadingBar:
		rl.DrawRectangleV(component.position, component.size, v.background_color)

		ratio := math.clamp(v.current / max(v.max, 0.0001), 0.0, 1.0)

		fill_width := component.size.x * ratio
		rl.DrawRectangleV(component.position, {fill_width, component.size.y}, v.color)
	case Graph:
		rl.DrawRectangleV(component.position, component.size, v.color_background)
		range := v.max_val - v.min_val

		point_distance := component.size.x / f32(v.data_count - 1)
		for i in 0 ..< v.data_count {
			rl.DrawLineV(
				{component.position.x + f32(i) * point_distance, component.position.y},
				{
					component.position.x + f32(i) * point_distance,
					component.position.y + component.size.y,
				},
				v.color_grid,
			)

			val := range == 0.0 ? 0.5 : 1.0 - (v.get_value(v.data_buffer, i) - v.min_val) / range

			new_point := rl.Vector2 {
				component.position.x + f32(i) * point_distance,
				component.position.y + val * component.size.y,
			}

			if i > 0 {
				val_prev :=
					range == 0.0 ? 0.5 : 1.0 - (v.get_value(v.data_buffer, i - 1) - v.min_val) / range
				rl.DrawLineV(
					{
						component.position.x + f32(i - 1) * point_distance,
						component.position.y + val_prev * component.size.y,
					},
					new_point,
					v.color_lines,
				)

				if v.interpolate_points && i < v.data_count - 1 {
					val_next :=
						range == 0.0 ? 0.5 : 1.0 - (v.get_value(v.data_buffer, i + 1) - v.min_val) / range
					if !global.approx_equal(val_prev, val) || !global.approx_equal(val, val_next) {
						rl.DrawCircleV(new_point, v.point_size, v.color_lines)
					}
				} else {
					rl.DrawCircleV(new_point, v.point_size, v.color_lines)
				}
			} else {
				rl.DrawCircleV(new_point, v.point_size, v.color_lines)
			}
		}
		draw_components_recursive(v.child, debug)
	case RangeIndicator:
		rl.DrawRectangleGradientH(
			i32(component.position.x),
			i32(component.position.y),
			i32(component.size.x),
			i32(component.size.y),
			rl.RED,
			rl.GREEN,
		)

		range := v.max_val - v.min_val

		if range > 0.0 {
			t := f32(clamp((v.current_val - v.min_val) / range, 0.0, 1.0))
			rl.DrawCircleV(
				component.position + {t * component.size.x, component.size.y * 0.5},
				component.size.y * 0.5,
				rl.BLACK,
			)
		}
	}

	if debug {
		rl.DrawRectangleLinesEx(
			rl.Rectangle {
				component.position.x,
				component.position.y,
				component.size.x,
				component.size.y,
			},
			2.0,
			rl.BLACK,
		)
		//rl.DrawRectangleLinesEx(rl.Rectangle{component.position.x, component.position.y, component.desired_size.x, component.desired_size.y}, 2.0, rl.BLUE)
	}
}

destroy_components_recursive :: proc(component: ^Component) {
	if component == nil do return

	switch v in component.variant {
	case StackContainer:
		for child in v.children {
			destroy_components_recursive(child)
		}
		delete(v.children)
	case AnchorContainer:
		destroy_components_recursive(v.child)
	case BoxContainer:
		for child in v.children {
			destroy_components_recursive(child)
		}
		delete(v.children)
	case MarginContainer:
		destroy_components_recursive(v.child)
	case ScrollContainer:
		destroy_components_recursive(v.child)
	case Panel:
		destroy_components_recursive(v.child)
	case TexturePanel:
		destroy_components_recursive(v.child)
	case NPatchTexturePanel:
		destroy_components_recursive(v.child)
	case Pill:
		destroy_components_recursive(v.child)
	case SimpleButton:
		destroy_components_recursive(v.child)
	case NPatchButton:
		destroy_components_recursive(v.child)
	case RadioButton:
		delete(v.connected_radio_buttons)
	case CheckBox:
	case Label:
	case LoadingBar:
	case Graph:
		destroy_components_recursive(v.child)
	case RangeIndicator:
	}
	free(component)
}
