package game_ui

import "../global"
import "../jobs"
import "../textures"
import "../types"
import "../ui"
import "core:fmt"
import "core:strings"
import rl "vendor:raylib"

JobCard :: struct {
	root:              ^ui.Component,
	level_label:       ^ui.Component,
	name_label:        ^ui.Component,
	income_label:      ^ui.Component,
	ticks_label:       ^ui.Component,
	buyin_price_label: ^ui.Component,
	start_button:      ^ui.Component,
	button_label:      ^ui.Component,
	progress_box:      ^ui.Component,
	crew_slots:        [dynamic]JobSlotDisplay,
}

JobSlotDisplay :: struct {
	root_button:  ^ui.Component,
	status_label: ^ui.Component,
	icon_panel:   ^ui.Component,
}

make_job_card :: proc(job: ^types.Job) -> JobCard {
	widget: JobCard = {}

	base_color, button_color: rl.Color

	widget.buyin_price_label = ui.make_label("", global.font_small_italic, 18.0, rl.BLACK, .Center)
	buyin_pill := ui.make_pill(rl.RAYWHITE, {}, widget.buyin_price_label)

	if _, ok := job.details.(types.BuyinJob); ok {
		base_color = rl.Color{160, 64, 32, 255}
		button_color = rl.Color{224, 64, 16, 255}
	} else {
		base_color = rl.GRAY
		button_color = rl.DARKGRAY
		buyin_pill.state = .Inactive
	}

	widget.button_label = ui.make_label("", global.font, 24.0, rl.RAYWHITE)
	widget.start_button = ui.make_simple_button(
		.OnRelease,
		button_color,
		{80.0, 0.0},
		widget.button_label,
	)

	widget.level_label = ui.make_label("", global.font_small, 18.0, rl.RAYWHITE, .Left)
	widget.name_label = ui.make_label("", global.font, 24.0, rl.RAYWHITE, .Left)
	widget.income_label = ui.make_label("", global.font_small_italic, 18.0, rl.RAYWHITE, .Left)
	widget.ticks_label = ui.make_label("", global.font_small_italic, 18.0, rl.RAYWHITE, .Left)

	total_width := f32(320.0 - 32.0)
	widget.progress_box = ui.make_box(.Horizontal, .Start, .Fill, 1)

	if job.ticks_needed > 0 {
		total_gap_width := f32(job.ticks_needed - 1) * 1.0
		segment_width := (total_width - total_gap_width) / f32(job.ticks_needed)

		for _ in 0 ..< job.ticks_needed {
			bar := ui.make_loading_bar(0, 1.0, rl.YELLOW, rl.DARKGRAY, {segment_width, 8.0})

			ui.box_add_child(widget.progress_box, bar)
		}
	}

	crew_members_box := ui.make_box(.Horizontal, .Center, .Center, 4)

	if details, ok := job.details.(types.BuyinJob); ok {
		for slot in details.crew_member_slots {
			icon: rl.Texture2D
			switch slot.type {
			case .Brawn:
				icon = textures.icon_textures[.Brawn]
			case .Savvy:
				icon = textures.icon_textures[.Savvy]
			case .Tech:
				icon = textures.icon_textures[.Tech]
			case .Charisma:
				icon = textures.icon_textures[.Charisma]
			}

			status_label := ui.make_label("Empty", global.font_small_italic, 18, rl.GRAY)
			icon_panel := ui.make_texture_panel(icon, {20, 20})

			slot_button := ui.make_simple_button(
				.OnRelease,
				rl.DARKGRAY,
				{50, 50},
				ui.make_box(.Vertical, .Center, .Center, 2, status_label, icon_panel),
				0.0,
			)
			append(
				&widget.crew_slots,
				JobSlotDisplay {
					root_button = slot_button,
					status_label = status_label,
					icon_panel = icon_panel,
				},
			)
			ui.box_add_child(crew_members_box, slot_button)
		}
	}

	widget.root = ui.make_panel(
		base_color,
		{320.0, 120.0},
		ui.make_margin(
			16,
			16,
			16,
			16,
			ui.make_box(
				.Vertical,
				.SpaceBetween,
				.Fill,
				4,
				ui.make_box(
					.Horizontal,
					.Fill,
					.Fill,
					16,
					ui.make_box(
						.Vertical,
						.SpaceBetween,
						.Fill,
						4,
						widget.level_label,
						widget.name_label,
						widget.income_label,
					),
					ui.make_box(
						.Vertical,
						.Start,
						.End,
						4,
						ui.make_box(
							.Horizontal,
							.Center,
							.Center,
							4,
							crew_members_box,
							widget.start_button,
						),
						buyin_pill,
					),
				),
				widget.ticks_label,
				widget.progress_box,
			),
		),
	)

	return widget
}

update_job_card :: proc(
	widget: ^JobCard,
	job: ^types.Job,
	tick_timer: f32,
	tick_speed: f32,
	crew_lookup: map[types.CrewMemberID]^types.CrewMember,
) {
	final_income, final_illegitimate_income, final_failure_chance := jobs.calculate_job_values(
		job,
		crew_lookup,
	)

	ui.label_set_text(
		widget.level_label,
		fmt.tprintf(
			"%s%s",
			strings.repeat("◆", job.level, context.temp_allocator),
			strings.repeat("◇", 10 - job.level, context.temp_allocator),
		),
	)
	ui.label_set_text(widget.name_label, job.name)
	if job.is_active {
		ui.label_set_text(widget.name_label, fmt.tprintf("%s ▶", job.name))
	} else if job.is_ready {
		ui.label_set_text(widget.name_label, fmt.tprintf("%s ▷", job.name))
	} else {
		ui.label_set_text(widget.name_label, job.name)
	}

	if final_income > 0.0 {
		if final_illegitimate_income > 0.0 {
			ui.label_set_text(
				widget.income_label,
				fmt.tprintf(
					"$%s & ₴%s",
					global.format_float_thousands(final_income, 2),
					global.format_float_thousands(final_illegitimate_income, 2),
				),
			)
		} else {
			ui.label_set_text(
				widget.income_label,
				fmt.tprintf("$%s", global.format_float_thousands(final_income, 2)),
			)
		}
	} else {
		ui.label_set_text(
			widget.income_label,
			fmt.tprintf("₴%s", global.format_float_thousands(final_illegitimate_income, 2)),
		)
	}

	if details, ok := job.details.(types.BuyinJob); ok {
		for slot_data, i in details.crew_member_slots {
			ui_slot := widget.crew_slots[i]

			if slot_data.assigned_crew_member != 0 {
				if crew_ptr, found := crew_lookup[slot_data.assigned_crew_member]; found {
					ui.label_set_text(ui_slot.status_label, crew_ptr.nickname)
					ui.label_set_color(ui_slot.status_label, rl.GREEN)
				} else {
					ui.label_set_text(ui_slot.status_label, "Unknown")
				}
				ui.button_set_color(ui_slot.root_button, rl.GRAY)
			} else {
				ui.label_set_text(ui_slot.status_label, "Empty")
				ui.label_set_color(ui_slot.status_label, rl.GRAY)
				ui.button_set_color(ui_slot.root_button, rl.DARKGRAY)
			}

			is_job_started := job.is_ready || job.is_active
			ui.button_set_disabled(ui_slot.root_button, is_job_started)
		}

		ui.label_set_text(
			widget.ticks_label,
			fmt.tprintf(
				"%d ticks (Failure chance: %s%% / tick)",
				job.ticks_needed,
				global.format_float_thousands(f64(final_failure_chance * 100.0), 2),
			),
		)
		if details.buyin_price > 0.0 {
			if details.illegitimate_buyin_price > 0.0 {
				ui.label_set_text(
					widget.buyin_price_label,
					fmt.tprintf(
						"$%s & ₴%s",
						global.format_float_thousands(details.buyin_price, 2),
						global.format_float_thousands(details.illegitimate_buyin_price, 2),
					),
				)
			} else {
				ui.label_set_text(
					widget.buyin_price_label,
					fmt.tprintf("$%s", global.format_float_thousands(details.buyin_price, 2)),
				)
			}
		} else {
			ui.label_set_text(
				widget.buyin_price_label,
				fmt.tprintf(
					"₴%s",
					global.format_float_thousands(details.illegitimate_buyin_price, 2),
				),
			)
		}
	} else {
		ui.label_set_text(widget.ticks_label, fmt.tprintf("%d ticks", job.ticks_needed))
	}

	ui.label_set_text(widget.button_label, job.is_ready || job.is_active ? "Stop" : "Start")

	if box, ok := &widget.progress_box.variant.(ui.BoxContainer); ok {
		for child, i in box.children {
			if bar, is_bar := &child.variant.(ui.LoadingBar); is_bar {
				if !job.is_active {
					bar.current = 0.0
				} else if i < job.ticks_current {
					bar.current = 1.0
					bar.max = 1.0
				} else if i == job.ticks_current {
					bar.current = tick_timer
					bar.max = tick_speed
				} else {
					bar.current = 0.0
				}
			}
		}
	}
}
