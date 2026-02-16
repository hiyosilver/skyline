package game_ui

import "../global"
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
	repeats_label:     ^ui.Component,
	description_label: ^ui.Component,
	income_label:      ^ui.Component,
	ticks_label:       ^ui.Component,
	buyin_price_label: ^ui.Component,
	start_button:      ^ui.Component,
	button_label:      ^ui.Component,
	progress_box:      ^ui.Component,
	crew_slots:        [dynamic]CrewSlotDisplay,
}

CrewSlotDisplay :: struct {
	root_button:  ^ui.Component,
	status_label: ^ui.Component,
	icon_panel:   ^ui.Component,
}

destroy_job_card :: proc(job_card: ^JobCard) {
	delete(job_card.crew_slots)
}

make_job_card :: proc(job: ^types.Job) -> JobCard {
	widget: JobCard = {}

	panel_color, button_color, button_color_disabled: rl.Color

	widget.buyin_price_label = ui.make_label("", global.font_small_italic, 18.0, rl.BLACK, .Center)
	buyin_pill := ui.make_pill(rl.RAYWHITE, {}, widget.buyin_price_label)

	if job.base_failure_chance > 0.0 {
		panel_color = rl.Color{92, 24, 48, 255}
		button_color = rl.Color{224, 64, 16, 255}
		button_color_disabled = rl.Color{160, 32, 8, 255}
	} else {
		panel_color = rl.Color{64, 48, 92, 255}
		button_color = rl.GRAY
		button_color_disabled = rl.DARKGRAY
	}

	if global.is_approx_zero(job.buyin_price) &&
	   global.is_approx_zero(job.illegitimate_buyin_price) {
		buyin_pill.state = .Inactive
	}

	widget.button_label = ui.make_label("", global.font, 24.0, rl.RAYWHITE)
	widget.start_button = ui.make_simple_button(
		.OnRelease,
		button_color,
		button_color_disabled,
		{80.0, 0.0},
		widget.button_label,
	)

	widget.level_label = ui.make_label("", global.font_small, 18.0, rl.RAYWHITE, .Left)
	widget.name_label = ui.make_label("", global.font, 24.0, rl.RAYWHITE, .Left)
	widget.repeats_label = ui.make_label("", global.font, 24.0, rl.RAYWHITE, .Left)
	widget.description_label = ui.make_label("", global.font_small, 18.0, rl.RAYWHITE, .Left)
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

	for slot in job.crew_member_slots {
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

		texture: rl.Texture2D
		if slot.optional {
			texture = textures.ui_textures[.CrewSlotOptional]
		} else {
			texture = textures.ui_textures[.CrewSlot]
		}

		status_label := ui.make_label("Empty", global.font_small_italic, 18, rl.GRAY)
		icon_panel := ui.make_texture_panel(icon, {20, 20})

		slot_button := ui.make_n_patch_button(
			.OnRelease,
			texture,
			rl.GRAY,
			rl.DARKGRAY,
			6,
			6,
			6,
			6,
			{50, 50},
			ui.make_box(.Vertical, .Center, .Center, 2, status_label, icon_panel),
			0.0,
		)
		append(
			&widget.crew_slots,
			CrewSlotDisplay {
				root_button = slot_button,
				status_label = status_label,
				icon_panel = icon_panel,
			},
		)
		ui.box_add_child(crew_members_box, slot_button)
	}

	repeats_texture := ui.make_texture_panel(
		textures.icon_textures[.Repeats],
		{32.0, 32.0},
		rl.RAYWHITE,
		ui.make_anchor(.Center, ui.make_offset({0, -2}, widget.repeats_label)),
	)

	widget.root = ui.make_n_patch_texture_panel(
		textures.ui_textures[.Panel],
		{320.0, 120.0},
		6,
		6,
		6,
		6,
		panel_color,
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
						ui.make_box(
							.Horizontal,
							.Start,
							.Fill,
							4,
							repeats_texture,
							widget.level_label,
						),
						widget.name_label,
						widget.description_label,
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
	roster: []types.CrewMember,
	money: f64,
	illegitimate_money: f64,
) {
	ui.label_set_text(
		widget.level_label,
		fmt.tprintf(
			"%s%s",
			strings.repeat("◆", job.level, context.temp_allocator),
			strings.repeat("◇", 10 - job.level, context.temp_allocator),
		),
	)
	ui.label_set_text(widget.name_label, job.name)
	ui.label_set_text(widget.description_label, job.description)
	if job.is_active {
		ui.label_set_text(widget.name_label, fmt.tprintf("%s ▶", job.name))
	} else if job.is_ready {
		ui.label_set_text(widget.name_label, fmt.tprintf("%s ▷", job.name))
	} else {
		ui.label_set_text(widget.name_label, job.name)
	}

	repeats := job.repeats < 0 ? "∞" : fmt.tprintf("%d", job.repeats)
	ui.label_set_text(widget.repeats_label, repeats)

	if job.cached_income > 0.0 {
		if job.cached_illegitimate_income > 0.0 {
			ui.label_set_text(
				widget.income_label,
				fmt.tprintf(
					"$%s & ₴%s",
					global.format_float_thousands(job.cached_income, 2),
					global.format_float_thousands(job.cached_illegitimate_income, 2),
				),
			)
		} else {
			ui.label_set_text(
				widget.income_label,
				fmt.tprintf("$%s", global.format_float_thousands(job.cached_income, 2)),
			)
		}
	} else {
		ui.label_set_text(
			widget.income_label,
			fmt.tprintf("₴%s", global.format_float_thousands(job.cached_illegitimate_income, 2)),
		)
	}

	can_afford := true

	if job.buyin_price > 0 && money < job.buyin_price ||
	   job.illegitimate_buyin_price > 0 && illegitimate_money < job.illegitimate_buyin_price {
		can_afford = false
		ui.label_set_color(widget.buyin_price_label, rl.GRAY)
	} else {
		ui.label_set_color(widget.buyin_price_label, rl.BLACK)
	}

	has_crew := true

	for slot in job.crew_member_slots {
		if !slot.optional && slot.assigned_crew_member == 0 {
			has_crew = false
			break
		}
	}

	can_start := can_afford && has_crew && !job.is_active && !job.is_ready

	ui.simple_button_set_disabled(widget.start_button, !can_start)
	if can_start {
		ui.simple_button_set_label_color(widget.start_button, rl.RAYWHITE)
	} else {
		ui.simple_button_set_label_color(widget.start_button, rl.GRAY)
	}


	for slot_data, i in job.crew_member_slots {
		ui_slot := widget.crew_slots[i]

		if slot_data.assigned_crew_member != 0 {
			crew_ptr := global.find_crew_member(roster, slot_data.assigned_crew_member)
			found := crew_ptr != nil

			if found {
				ui.label_set_text(ui_slot.status_label, crew_ptr.nickname)
				ui.label_set_color(ui_slot.status_label, rl.GREEN)
			} else {
				ui.label_set_text(ui_slot.status_label, "Unknown")
			}
			ui.n_patch_button_set_tint_color(ui_slot.root_button, rl.GRAY)
		} else {
			ui.label_set_text(ui_slot.status_label, "Empty")
			ui.label_set_color(ui_slot.status_label, rl.GRAY)
			ui.n_patch_button_set_tint_color(ui_slot.root_button, rl.DARKGRAY)
		}

		is_job_started := job.is_ready || job.is_active
		ui.n_patch_button_set_disabled(ui_slot.root_button, is_job_started)
	}

	if job.cached_failure_chance > 0.0 {
		ui.label_set_text(
			widget.ticks_label,
			fmt.tprintf(
				"%d ticks (Failure chance: %s%% / tick)",
				job.ticks_needed,
				global.format_float_thousands(f64(job.cached_failure_chance * 100.0), 2),
			),
		)
	} else {
		ui.label_set_text(widget.ticks_label, fmt.tprintf("%d ticks", job.ticks_needed))
	}

	if job.buyin_price > 0.0 {
		if job.illegitimate_buyin_price > 0.0 {
			ui.label_set_text(
				widget.buyin_price_label,
				fmt.tprintf(
					"$%s & ₴%s",
					global.format_float_thousands(job.buyin_price, 2),
					global.format_float_thousands(job.illegitimate_buyin_price, 2),
				),
			)
		} else {
			ui.label_set_text(
				widget.buyin_price_label,
				fmt.tprintf("$%s", global.format_float_thousands(job.buyin_price, 2)),
			)
		}
	} else if job.illegitimate_buyin_price > 0.0 {
		ui.label_set_text(
			widget.buyin_price_label,
			fmt.tprintf("₴%s", global.format_float_thousands(job.illegitimate_buyin_price, 2)),
		)
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
