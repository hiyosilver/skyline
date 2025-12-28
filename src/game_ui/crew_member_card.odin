package game_ui

import "../global"
import "../textures"
import "../types"
import "../ui"
import "core:fmt"
import rl "vendor:raylib"

CrewMemberCard :: struct {
	root:               ^ui.Component,
	nickname_label:     ^ui.Component,
	brawn_label:        ^ui.Component,
	savvy_label:        ^ui.Component,
	tech_label:         ^ui.Component,
	charisma_label:     ^ui.Component,
	salary_label:       ^ui.Component,
	job_name_label:     ^ui.Component,
	income_label:       ^ui.Component,
	ticks_label:        ^ui.Component,
	progress_box:       ^ui.Component,
	assigned_job_label: ^ui.Component,
}

make_crew_member_card :: proc(cm: ^types.CrewMember) -> CrewMemberCard {
	widget: CrewMemberCard = {}

	base_color: rl.Color
	if cm.default_job.cached_failure_chance > 0.0 {
		base_color = rl.Color{192, 92, 92, 255}
	} else {
		base_color = rl.GRAY
	}

	widget.nickname_label = ui.make_label("", global.font, 24.0, rl.RAYWHITE, .Left)

	widget.brawn_label = ui.make_label("", global.font, 24.0, rl.RAYWHITE, .Left)
	widget.savvy_label = ui.make_label("", global.font, 24.0, rl.RAYWHITE, .Left)
	widget.tech_label = ui.make_label("", global.font, 24.0, rl.RAYWHITE, .Left)
	widget.charisma_label = ui.make_label("", global.font, 24.0, rl.RAYWHITE, .Left)

	widget.salary_label = ui.make_label("", global.font_small, 18.0, rl.RAYWHITE, .Left)

	widget.job_name_label = ui.make_label("", global.font_small, 18.0, rl.RAYWHITE, .Left)
	widget.income_label = ui.make_label("", global.font_small_italic, 18.0, rl.RAYWHITE, .Left)
	widget.ticks_label = ui.make_label("", global.font_small_italic, 18.0, rl.RAYWHITE, .Left)

	widget.assigned_job_label = ui.make_label("", global.font_small, 18.0, rl.RAYWHITE, .Left)
	widget.assigned_job_label.state = .Inactive

	usable_width := f32(320.0 - 32.0)

	widget.progress_box = ui.make_box(.Horizontal, .Start, .Fill, 1)

	ticks_needed := cm.default_job.ticks_needed
	if ticks_needed > 0 {
		total_gaps := f32(ticks_needed - 1) * 1.0
		segment_width := (usable_width - total_gaps) / f32(ticks_needed)

		for _ in 0 ..< ticks_needed {
			bar := ui.make_loading_bar(
				0.0,
				1.0,
				rl.Color{92, 92, 192, 255},
				rl.DARKGRAY,
				{segment_width, 8.0},
			)
			ui.box_add_child(widget.progress_box, bar)
		}
	}

	visuals := ui.make_n_patch_texture_panel(
		textures.ui_textures[.Panel],
		{320.0, 0.0},
		6,
		6,
		6,
		6,
		rl.Color{64, 48, 92, 255},
		ui.make_margin(
			16,
			16,
			16,
			16,
			ui.make_box(
				.Vertical,
				.Fill,
				.Fill,
				8,
				ui.make_box(
					.Horizontal,
					.SpaceBetween,
					.Fill,
					8,
					widget.nickname_label,
					ui.make_box(
						.Horizontal,
						.Center,
						.Fill,
						8,
						ui.make_box(
							.Horizontal,
							.Center,
							.Center,
							2,
							ui.make_texture_panel(
								textures.icon_textures[textures.IconTextureId.Brawn],
								{24, 24},
							),
							widget.brawn_label,
						),
						ui.make_box(
							.Horizontal,
							.Center,
							.Center,
							2,
							ui.make_texture_panel(
								textures.icon_textures[textures.IconTextureId.Savvy],
								{24, 24},
							),
							widget.savvy_label,
						),
						ui.make_box(
							.Horizontal,
							.Center,
							.Center,
							2,
							ui.make_texture_panel(
								textures.icon_textures[textures.IconTextureId.Tech],
								{24, 24},
							),
							widget.tech_label,
						),
						ui.make_box(
							.Horizontal,
							.Center,
							.Center,
							2,
							ui.make_texture_panel(
								textures.icon_textures[textures.IconTextureId.Charisma],
								{24, 24},
							),
							widget.charisma_label,
						),
					),
				),
				widget.salary_label,
				ui.make_box(
					.Vertical,
					.SpaceBetween,
					.Fill,
					2,
					ui.make_box(
						.Horizontal,
						.SpaceBetween,
						.End,
						0,
						widget.job_name_label,
						widget.income_label,
						widget.ticks_label,
					),
					widget.progress_box,
					widget.assigned_job_label,
				),
			),
		),
	)

	widget.root = ui.make_simple_button(
		.OnRelease,
		rl.Color{255, 255, 255, 0},
		rl.Color{255, 255, 255, 0},
		{},
		visuals,
		0.0,
	)

	ui.simple_button_set_disabled(widget.root, true)

	return widget
}

update_crew_member_card :: proc(
	widget: ^CrewMemberCard,
	cm: ^types.CrewMember,
	tick_timer: f32,
	tick_speed: f32,
	selectable: bool,
	jobs: []types.Job,
) {
	ui.label_set_text(widget.nickname_label, fmt.tprintf("'%s'", cm.nickname))

	ui.label_set_text(widget.brawn_label, fmt.tprintf("%d", cm.brawn))
	ui.label_set_text(widget.savvy_label, fmt.tprintf("%d", cm.savvy))
	ui.label_set_text(widget.tech_label, fmt.tprintf("%d", cm.tech))
	ui.label_set_text(widget.charisma_label, fmt.tprintf("%d", cm.charisma))

	if cm.base_salary > 0.0 {
		if cm.base_salary_illegitimate > 0.0 {
			ui.label_set_text(
				widget.salary_label,
				fmt.tprintf(
					"Salary: $%s & ₴%s",
					global.format_float_thousands(cm.base_salary, 2),
					global.format_float_thousands(cm.base_salary_illegitimate, 2),
				),
			)
		} else {
			ui.label_set_text(
				widget.salary_label,
				fmt.tprintf("Salary: $%s", global.format_float_thousands(cm.base_salary, 2)),
			)
		}
	} else {
		ui.label_set_text(
			widget.salary_label,
			fmt.tprintf(
				"Salary: ₴%s",
				global.format_float_thousands(cm.base_salary_illegitimate, 2),
			),
		)
	}

	job_name := cm.default_job.name
	if cm.default_job.is_active {
		ui.label_set_text(widget.job_name_label, fmt.tprintf("%s ▶", job_name))
	} else if cm.default_job.is_ready {
		ui.label_set_text(widget.job_name_label, fmt.tprintf("%s ▷", job_name))
	} else {
		ui.label_set_text(widget.job_name_label, job_name)
	}

	job := &cm.default_job
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

	if job.cached_failure_chance > 0.0 {
		ui.label_set_text(
			widget.ticks_label,
			fmt.tprintf(
				"%d ticks (Fail: %s%%)",
				job.ticks_needed,
				global.format_float_thousands(f64(job.cached_failure_chance * 100.0), 1),
			),
		)
	} else {
		ui.label_set_text(widget.ticks_label, fmt.tprintf("%d ticks", job.ticks_needed))
	}

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

	job_ptr := global.find_job(jobs, cm.assigned_to_job_id)
	is_assigned_to_job := job_ptr != nil

	if selectable && !is_assigned_to_job {
		ui.simple_button_set_disabled(widget.root, false)
		ui.simple_button_set_color(widget.root, rl.GREEN)
	} else {
		ui.simple_button_set_disabled(widget.root, true)
		ui.simple_button_set_color(widget.root, rl.Color{255, 255, 255, 0})
	}

	if is_assigned_to_job {
		widget.assigned_job_label.state = .Active
		ui.label_set_text(
			widget.assigned_job_label,
			fmt.tprintf("Assigned to job %s", job_ptr.name),
		)
	} else {
		widget.assigned_job_label.state = .Inactive
	}
}
