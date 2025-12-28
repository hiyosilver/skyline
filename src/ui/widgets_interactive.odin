package ui

import rl "vendor:raylib"

ButtonState :: enum {
	Idle,
	Disabled,
	Hovered,
	Pressed,
	Released,
}

ButtonClickType :: enum {
	OnPress,
	OnRelease,
}

SimpleButton :: struct {
	child:                                                       ^Component,
	state:                                                       ButtonState,
	click_type:                                                  ButtonClickType,
	color_default, color_hovered, color_pressed, color_disabled: rl.Color,
	padding:                                                     f32,
}

make_simple_button :: proc(
	click_type: ButtonClickType,
	color, color_disabled: rl.Color,
	min_size: rl.Vector2,
	child: ^Component = nil,
	padding: f32 = 4.0,
) -> ^Component {
	c := new(Component)

	c.min_size = min_size

	c.variant = SimpleButton {
		state          = .Idle,
		click_type     = click_type,
		color_default  = color,
		color_hovered  = rl.ColorBrightness(color, 0.2),
		color_pressed  = rl.ColorBrightness(color, -0.2),
		color_disabled = color_disabled,
		padding        = padding,
		child          = child,
	}

	return c
}

simple_button_was_clicked :: proc(component: ^Component) -> bool {
	if component == nil || component.state == .Inactive do return false
	if btn, ok := component.variant.(SimpleButton); ok {
		return btn.state == .Released
	}
	return false
}

simple_button_set_disabled :: proc(component: ^Component, disabled: bool) {
	if component == nil do return
	if btn, ok := &component.variant.(SimpleButton); ok {
		if disabled {
			btn.state = .Disabled
		} else {
			if btn.state == .Disabled {
				btn.state = .Idle
			}
		}
	}
}

simple_button_set_color :: proc(component: ^Component, color: rl.Color) {
	if component == nil do return

	if btn, ok := &component.variant.(SimpleButton); ok {
		if btn.color_default == color do return

		btn.color_default = color
		btn.color_hovered = rl.ColorBrightness(color, 0.2)
		btn.color_pressed = rl.ColorBrightness(color, -0.2)
	}
}

simple_button_reset_state :: proc(component: ^Component) {
	if component == nil do return

	if btn, ok := &component.variant.(SimpleButton); ok {
		btn.state = .Idle
	}
}

simple_button_set_label_text :: proc(component: ^Component, text: string) {
	if component == nil do return

	if btn, ok := &component.variant.(SimpleButton); ok {
		label_set_text(btn.child, text)
	}
}

simple_button_set_label_color :: proc(component: ^Component, color: rl.Color) {
	if component == nil do return

	if btn, ok := &component.variant.(SimpleButton); ok {
		label_set_color(btn.child, color)
	}
}

NPatchButton :: struct {
	child:                                                                           ^Component,
	state:                                                                           ButtonState,
	click_type:                                                                      ButtonClickType,
	texture:                                                                         rl.Texture2D,
	tint_color_default, tint_color_hovered, tint_color_pressed, tint_color_disabled: rl.Color,
	left, top, right, bottom:                                                        i32,
	padding:                                                                         f32,
}

make_n_patch_button :: proc(
	click_type: ButtonClickType,
	texture: rl.Texture2D,
	tint_color, tint_color_disabled: rl.Color,
	left, top, right, bottom: i32,
	min_size: rl.Vector2,
	child: ^Component = nil,
	padding: f32 = 4.0,
) -> ^Component {
	c := new(Component)

	c.min_size = min_size

	c.variant = NPatchButton {
		state               = .Idle,
		click_type          = click_type,
		texture             = texture,
		tint_color_default  = tint_color,
		tint_color_hovered  = rl.ColorBrightness(tint_color, 0.2),
		tint_color_pressed  = rl.ColorBrightness(tint_color, -0.2),
		tint_color_disabled = tint_color_disabled,
		left                = left,
		top                 = top,
		right               = right,
		bottom              = bottom,
		padding             = padding,
		child               = child,
	}

	return c
}

n_patch_button_was_clicked :: proc(component: ^Component) -> bool {
	if component == nil || component.state == .Inactive do return false
	if btn, ok := component.variant.(NPatchButton); ok {
		return btn.state == .Released
	}
	return false
}

n_patch_button_set_disabled :: proc(component: ^Component, disabled: bool) {
	if component == nil do return
	if btn, ok := &component.variant.(NPatchButton); ok {
		if disabled {
			btn.state = .Disabled
		} else {
			if btn.state == .Disabled {
				btn.state = .Idle
			}
		}
	}
}

n_patch_button_set_tint_color :: proc(component: ^Component, tint_color: rl.Color) {
	if component == nil do return

	if btn, ok := &component.variant.(NPatchButton); ok {
		if btn.tint_color_default == tint_color do return

		btn.tint_color_default = tint_color
		btn.tint_color_hovered = rl.ColorBrightness(tint_color, 0.2)
		btn.tint_color_pressed = rl.ColorBrightness(tint_color, -0.2)
	}
}

n_patch_button_reset_state :: proc(component: ^Component) {
	if component == nil do return

	if btn, ok := &component.variant.(NPatchButton); ok {
		btn.state = .Idle
	}
}

n_patch_button_set_label_text :: proc(component: ^Component, text: string) {
	if component == nil do return

	if btn, ok := &component.variant.(NPatchButton); ok {
		label_set_text(btn.child, text)
	}
}

n_patch_button_set_label_color :: proc(component: ^Component, color: rl.Color) {
	if component == nil do return

	if btn, ok := &component.variant.(NPatchButton); ok {
		label_set_color(btn.child, color)
	}
}

RadioButton :: struct {
	selected:                bool,
	state:                   ButtonState,
	connected_radio_buttons: [dynamic]^Component,
}

make_radio_button :: proc(
	min_size: rl.Vector2 = {20.0, 20.0},
	selected: bool = false,
) -> ^Component {
	c := new(Component)

	c.min_size = min_size

	c.variant = RadioButton {
		selected                = selected,
		state                   = .Idle,
		connected_radio_buttons = make([dynamic]^Component),
	}

	return c
}

radio_button_connect :: proc(component: ^Component, other_button: ^Component) {
	if component == nil do return

	if radio_button, ok := &component.variant.(RadioButton); ok {
		append(&radio_button.connected_radio_buttons, other_button)
	}
}

radio_button_set_state :: proc(component: ^Component, selected: bool) {
	if component == nil do return

	if radio_button, ok := &component.variant.(RadioButton); ok {
		radio_button.selected = selected
	}
}

radio_button_is_selected :: proc(component: ^Component) -> bool {
	if component == nil do return false

	if radio_button, ok := &component.variant.(RadioButton); ok {
		return radio_button.selected
	}

	return false
}

radio_button_was_activated :: proc(component: ^Component) -> bool {
	if component == nil do return false

	if radio_button, ok := component.variant.(RadioButton); ok {
		return radio_button.state == .Released && radio_button.selected
	}

	return false
}

CheckBox :: struct {
	selected: bool,
	state:    ButtonState,
}

make_check_box :: proc(min_size: rl.Vector2 = {18.0, 18.0}, selected: bool = false) -> ^Component {
	c := new(Component)

	c.min_size = min_size

	c.variant = CheckBox {
		selected = selected,
		state    = .Idle,
	}

	return c
}

check_box_is_selected :: proc(component: ^Component) -> bool {
	if component == nil do return false

	if check_box, ok := &component.variant.(CheckBox); ok {
		return check_box.selected
	}

	return false
}

check_box_was_activated :: proc(component: ^Component) -> bool {
	if component == nil do return false

	if check_box, ok := component.variant.(CheckBox); ok {
		return check_box.state == .Released && check_box.selected
	}

	return false
}

check_box_was_toggled :: proc(component: ^Component) -> bool {
	if component == nil do return false

	if check_box, ok := component.variant.(CheckBox); ok {
		return check_box.state == .Released
	}

	return false
}
