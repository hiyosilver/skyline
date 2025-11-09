package ui

import rl "vendor:raylib"
import "core:fmt"
import "core:strings"
import "../global"
import "../input"
import "../jobs"

Base :: struct {
	position, size: rl.Vector2,
}

LoadingBar :: struct {
	using base: Base,
	max, current: f32,
	color: rl.Color,
	background_color: Maybe(rl.Color),
}

draw_loading_bar :: proc(bar: ^LoadingBar) {
    fill_amount := 1.0 / bar.max * bar.current
    if background, ok := bar.background_color.?; ok {
    	rl.DrawRectangleV(bar.position, bar.size, background)
    }
    rl.DrawRectangleV(bar.position, { fill_amount * bar.size.x, bar.size.y }, bar.color)
}

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

JobDisplay :: struct {
	job: ^jobs.Job,
	position, size: rl.Vector2,
	start_button: Button,
	bars: [dynamic]LoadingBar,
}

create_job_display :: proc(job: ^jobs.Job, position, size: rl.Vector2) -> JobDisplay {
	display := new(JobDisplay)

	button_state: ButtonState
	switch &details in job.details {
	case jobs.StandardJob:
		button_state = .Idle
	case jobs.BuyinJob:
        button_state = .Disabled
	}

	display.job = job
	display.position = position
	display.size = size

	display.start_button = Button {
		position = {display.position.x + display.size.x - 96.0, display.position.y + 16.0},
		size = {80.0, 24.0},
		label = "Start",
		label_alt = "Stop",
		state = button_state,
	}

	bar_width := display.size.x - 32.0
	bar_segment_width := bar_width / f32(job.ticks_needed)
	for i in 0..<job.ticks_needed {
		append(&display.bars, LoadingBar{
			position = {display.position.x + 16.0 + f32(i) * bar_segment_width, display.position.y + display.size.y - 24.0},
			size = {bar_segment_width, 8.0},
			max = 1.0,
			current = 0.0,
			color = rl.YELLOW,
			background_color = rl.DARKGRAY,
		})
	}

	return display^
}

destroy_job_display :: proc(display: ^JobDisplay) {
	delete(display.bars)
	free(display)
}

update_job_display_input :: proc(display: ^JobDisplay, input_data: ^input.RawInput) {
	update_button_input(&display.start_button, input_data)
}

update_job_display :: proc(display: ^JobDisplay, tick_timer: f32) {
	if !display.job.is_active do return

	display.bars[display.job.ticks_current].current = tick_timer
}

reset_job_display :: proc(display: ^JobDisplay) {
	for &bar in display.bars {
		bar.current = 0.0
	}
}

draw_job_display :: proc(display: ^JobDisplay) {
	base_color: rl.Color
	ticks_label: cstring
	switch &details in display.job.details {
	case jobs.StandardJob:
		base_color = rl.GRAY
		ticks_label = fmt.ctprintf("%d ticks", display.job.ticks_needed)
	case jobs.BuyinJob:
		base_color = rl.Color{192, 92, 92, 255}
		ticks_label = fmt.ctprintf("%d ticks (Failure chance: %s%% per tick)", display.job.ticks_needed, global.format_float_thousands(f64(details.failure_chance * 100.0), 2, ',', '.'))
	}

	rl.DrawRectangleV(display.position, display.size, base_color)
	level_label := fmt.ctprintf("%s%s", strings.repeat("◆", display.job.level), strings.repeat("◇", 10 - display.job.level))
	rl.DrawTextPro(global.font_small, level_label, display.position + {16.0, 16.0}, {0.0, 0.0}, 0.0, 18.0, 2.0, rl.RAYWHITE)
	name_label := display.job.is_active ? fmt.ctprintf("%s ▶", display.job.name) : display.job.is_ready ? fmt.ctprintf("%s ▷", display.job.name)  : fmt.ctprint(display.job.name)
	rl.DrawTextPro(global.font, name_label, display.position + {16.0, 32.0}, {0.0, 0.0}, 0.0, 24.0, 2.0, rl.RAYWHITE)
	if display.job.income > 0.0 {
		if display.job.illegitimate_income > 0.0 {
			rl.DrawTextPro(global.font_small_italic, fmt.ctprintf("%s $ + %s ₴", global.format_float_thousands(display.job.income, 2, ',', '.'), global.format_float_thousands(display.job.illegitimate_income, 2, ',', '.')), display.position + {16.0, 56.0}, {0.0, 0.0}, 0.0, 18.0, 2.0, rl.RAYWHITE)
		} else {
			rl.DrawTextPro(global.font_small_italic, fmt.ctprintf("%s $", global.format_float_thousands(display.job.income, 2, ',', '.')), display.position + {16.0, 56.0}, {0.0, 0.0}, 0.0, 18.0, 2.0, rl.RAYWHITE)
		}
	} else {
		rl.DrawTextPro(global.font_small_italic, fmt.ctprintf("%s ₴", global.format_float_thousands(display.job.illegitimate_income, 2, ',', '.')), display.position + {16.0, 56.0}, {0.0, 0.0}, 0.0, 18.0, 2.0, rl.RAYWHITE)
	}
	rl.DrawTextPro(global.font_small_italic, ticks_label, display.position + {16.0, 72.0}, {0.0, 0.0}, 0.0, 18.0, 2.0, rl.RAYWHITE)
	draw_button(&display.start_button, display.job.is_ready || display.job.is_active)
	#partial switch &details in display.job.details {
	case jobs.BuyinJob:
		buyin_price_label := fmt.ctprintf("%s $", global.format_float_thousands(details.buyin_price, 2, ',', '.'))
		buyin_price_label_size := rl.MeasureTextEx(global.font_small_italic, buyin_price_label, 18.0, 2.0)
		rl.DrawTextPro(global.font_small_italic, buyin_price_label, display.start_button.position + {display.start_button.size.x * 0.5 - buyin_price_label_size.x * 0.5, display.start_button.size.y + 2.0}, {0.0, 0.0}, 0.0, 18.0, 2.0, rl.RAYWHITE)
		illegitimate_buyin_price_label := fmt.ctprintf("%s ₴", global.format_float_thousands(details.illegitimate_buyin_price, 2, ',', '.'))
		illegitimate_buyin_price_label_width := rl.MeasureTextEx(global.font_small_italic, illegitimate_buyin_price_label, 18.0, 2.0).x
		rl.DrawTextPro(global.font_small_italic, illegitimate_buyin_price_label, display.start_button.position + {display.start_button.size.x * 0.5 - illegitimate_buyin_price_label_width * 0.5, display.start_button.size.y + buyin_price_label_size.y + 2.0}, {0.0, 0.0}, 0.0, 18.0, 2.0, rl.RAYWHITE)
	}
	for &bar in display.bars {
		draw_loading_bar(&bar)
		rl.DrawLineV({bar.position.x + bar.size.x, bar.position.y - 2.0}, {bar.position.x + bar.size.x, bar.position.y + bar.size.y + 2.0}, rl.GRAY)
	}
}