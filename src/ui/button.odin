package ui

import rl "vendor:raylib"
import "core:fmt"
import "../global"
import "../input"

ButtonState :: enum {
	Idle,
	Disabled,
	Hovered,
	Pressed,
	Released,
}

Button :: struct {
	using base: Base,
	state: ButtonState,
	label, label_alt: string,
}

update_button_input :: proc(button: ^Button, input_data: ^input.RawInput) {
	if button.state == .Disabled do return

	hovered := input_data.mouse_position.x >= button.position.x &&
		input_data.mouse_position.x <= button.position.x + button.size.x &&
		input_data.mouse_position.y >= button.position.y &&
		input_data.mouse_position.y <= button.position.y + button.size.y
	mouse_button_pressed := input.is_mouse_button_held_down(.LEFT, input_data)
	button_was_pressed := button.state == .Pressed

	if button_was_pressed && !mouse_button_pressed {
		button.state = .Released
	} else if hovered && !mouse_button_pressed {
		button.state = .Hovered
	} else if hovered && mouse_button_pressed {
		button.state = .Pressed
	} else {
		button.state = .Idle
	}
}

draw_button :: proc(button: ^Button, use_alt_label: bool) {
	rl.DrawRectangleV(button.position, button.size, button.state == .Hovered || button.state == .Pressed ? rl.SKYBLUE : rl.DARKGRAY)
	if button.state == .Pressed {
		rl.DrawRectangleV(button.position + {2.0, 2.0}, button.size - {4.0, 4.0}, rl.DARKBLUE)
	}

	button_label := use_alt_label ? fmt.ctprint(button.label_alt) : fmt.ctprint(button.label)
	label_size := rl.MeasureTextEx(global.font, button_label, 24.0, 2.0)
	label_color := button.state == .Disabled ? rl.GRAY : rl.RAYWHITE
	rl.DrawTextPro(
		global.font, 
		button_label, 
		button.position + {(button.size.x - label_size.x) * 0.5, (button.size.y - label_size.y) * 0.5}, 
		{0.0, 0.0}, 
		0.0, 
		24.0, 
		2.0, 
		label_color)
}