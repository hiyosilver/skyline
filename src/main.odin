package crown

import "buildings"
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:os"
import "core:path/filepath"
import "crew"
import "global"
import "input"
import "jobs"
import "stocks"
import "textures"
import "ui"
import rl "vendor:raylib"

UPDATE_FPS :: 60
RENDER_FPS :: 120
FIXED_DELTA :: 1.0 / f32(UPDATE_FPS)

ChangeOnTick :: enum {
	Maintained,
	Increased,
	Decreased,
}

GameState :: struct {
	//Camera
	camera:                    rl.Camera2D,
	camera_zoom:               CameraZoom,
	zoom_delay:                f32,

	//Simulation
	paused:                    bool,
	tick_speed:                f32,
	tick_timer:                f32,
	current_tick:              int,
	current_period:            int,
	current_quarter:           int,
	current_year:              int,

	//Game data
	money:                     f64,
	period_income:             f64,
	money_change:              ChangeOnTick,
	illegitimate_money:        f64,
	illegitimate_money_change: ChangeOnTick,
	base_tax_rate:             f64,
	tax_debt:                  f64,
	tax_debt_interest_rate:    f64,
	tick_stats_buffer:         [dynamic]TickStatistics,
	tick_stats_buffer_size:    int,
	market:                    stocks.Market,
	stock_portfolio:           stocks.StockPortfolio,
}

TickStatistics :: struct {
	current_money:              f64,
	current_illegitimate_money: f64,
	income:                     f64,
	illegitimate_income:        f64,
	salaries:                   f64,
	illegitimate_salaries:      f64,
	taxes:                      f64,
	tax_debt:                   f64,
}

CameraZoom :: enum {
	Default,
	Close,
	Far,
}

JobEntry :: struct {
	job:     jobs.Job,
	display: ui.JobDisplay,
}

CrewEntry :: struct {
	crew_member: crew.CrewMember,
	display:     ui.CrewMemberDisplay,
}

exe_path: string
exe_dir: string

game_state: GameState

money_label_component: ^ui.Component
illegitimate_money_label_component: ^ui.Component
tick_bar_component: ^ui.Component

buildings_list: [dynamic]buildings.Building

job_entries: [dynamic]JobEntry
jobs_box: ^ui.Component

crew_member_entries: [dynamic]CrewEntry
crew_members_box: ^ui.Component

graph: ^ui.Component
money_radio_button: ^ui.Component
illegitimate_money_radio_button: ^ui.Component

stock_window: ui.StockWindow

ui_root: ^ui.Component

main :: proc() {
	/*
    track: mem.Tracking_Allocator
    mem.tracking_allocator_init(&track, context.allocator)
    defer mem.tracking_allocator_destroy(&track)
    context.allocator = mem.tracking_allocator(&track)

    defer {
        if len(track.allocation_map) > 0 {
            fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
            for _, entry in track.allocation_map {
                fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)

                if entry.size < 500 {
                    str := string(mem.slice_ptr(cast(^u8)entry.memory, entry.size))
                    fmt.eprintf("  Content: %q\n", str)
                }
            }
        }
        if len(track.bad_free_array) > 0 {
            fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
            for entry in track.bad_free_array {
                fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
            }
        }
    }
    */

	game_state.tick_speed = 1.0
	game_state.current_tick = 1
	game_state.current_period = 1
	game_state.current_quarter = 1
	game_state.current_year = 1
	game_state.money = 100.0
	game_state.base_tax_rate = 0.15
	game_state.tax_debt_interest_rate = 0.005
	game_state.tick_stats_buffer = make([dynamic]TickStatistics)
	game_state.tick_stats_buffer_size = 30
	game_state.market = stocks.create_market()
	for _ in 0 ..< 30 {
		stocks.update_market_tick(&game_state.market)
	}
	game_state.stock_portfolio = stocks.create_stock_portfolio(&game_state.market)

	exe_path = os.args[0]
	exe_dir = filepath.dir(exe_path)
	defer delete(exe_dir)
	asset_dir := filepath.join([]string{exe_dir, "../assets"})
	defer delete(asset_dir)

	rl.SetExitKey(rl.KeyboardKey.KEY_NULL)
	rl.SetConfigFlags(
		{
			.MSAA_4X_HINT, /*.VSYNC_HINT*/
		},
	)

	rl.InitWindow(global.SCREEN_WIDTH, global.SCREEN_HEIGHT, "Skyline")
	defer rl.CloseWindow()
	rl.SetTargetFPS(RENDER_FPS)

	textures.load_textures(asset_dir)
	global.load_fonts(asset_dir)
	buildings.load_building_data(asset_dir)

	game_state.camera.target = {global.SCREEN_WIDTH * 0.5, global.SCREEN_HEIGHT * 0.5}
	game_state.camera.offset = {global.SCREEN_WIDTH * 0.5, global.SCREEN_HEIGHT * 0.5}
	game_state.camera.rotation = 0.0
	game_state.camera.zoom = 1.0

	accumulator: f32 = 0.0
	max_updates := 5

	frame_input: input.RawInput
	pending_buttons := make(map[rl.MouseButton]bit_set[input.InputFlags])
	pending_keys := make(map[rl.KeyboardKey]bit_set[input.InputFlags])

	building_crown_plaza := buildings.Building {
		position       = {400.0, 800.0},
		texture_id     = .SkyscraperCrownPlaza,
		texture_offset = {96.0, 1088.0},
		image_data     = rl.LoadImageFromTexture(
			textures.building_textures[.SkyscraperCrownPlaza].albedo,
		),
		name           = "Crown Plaza Tower",
	}
	append(&buildings_list, building_crown_plaza)

	building_atlas_hotel := buildings.Building {
		position       = {600.0, 860.0},
		texture_id     = .SkyscraperAtlasHotel,
		texture_offset = {77.0, 480.0},
		image_data     = rl.LoadImageFromTexture(
			textures.building_textures[.SkyscraperAtlasHotel].albedo,
		),
		name           = "Atlas Hotel",
	}
	append(&buildings_list, building_atlas_hotel)

	job_entries = make([dynamic]JobEntry)

	jobA := jobs.Job {
		name                = "Job A",
		level               = 2,
		ticks_needed        = 6,
		income              = 2.5,
		illegitimate_income = 1.5,
		details             = jobs.StandardJob{},
	}
	append(&job_entries, JobEntry{jobA, ui.make_job_display(&jobA)})

	jobB := jobs.Job {
		name         = "Job B",
		level        = 1,
		ticks_needed = 5,
		income       = 3.0,
		details      = jobs.StandardJob{},
	}
	append(&job_entries, JobEntry{jobB, ui.make_job_display(&jobB)})


	jobC := jobs.Job {
		name         = "Job C",
		level        = 1,
		ticks_needed = 3,
		income       = 1.5,
		details      = jobs.StandardJob{},
	}
	append(&job_entries, JobEntry{jobC, ui.make_job_display(&jobC)})

	jobD: jobs.Job = jobs.Job {
		name = "Risky Job",
		level = 5,
		ticks_needed = 10,
		illegitimate_income = 145.0,
		details = jobs.BuyinJob {
			buyin_price = 10.0,
			illegitimate_buyin_price = 10.0,
			failure_chance = 0.02,
		},
	}
	append(&job_entries, JobEntry{jobD, ui.make_job_display(&jobD)})

	jobs_box = ui.make_box(
		.Vertical,
		.SpaceBetween,
		.Fill,
		16,
		job_entries[0].display.root,
		job_entries[1].display.root,
		job_entries[2].display.root,
		job_entries[3].display.root,
	)

	job_panel := ui.make_anchor(.BottomLeft, ui.make_margin(16, 16, 16, 16, jobs_box))

	crew_member_entries = make([dynamic]CrewEntry)

	crew_memberA := crew.generate_crew_member()
	append(
		&crew_member_entries,
		CrewEntry{crew_memberA, ui.make_crew_member_display(&crew_memberA)},
	)

	crew_memberB := crew.generate_crew_member()
	append(
		&crew_member_entries,
		CrewEntry{crew_memberB, ui.make_crew_member_display(&crew_memberB)},
	)

	crew_members_box = ui.make_box(
		.Vertical,
		.SpaceBetween,
		.Fill,
		16,
		crew_member_entries[0].display.root,
		crew_member_entries[1].display.root,
	)

	crew_panel := ui.make_anchor(.BottomRight, ui.make_margin(16, 16, 16, 16, crew_members_box))

	tick_bar_component = ui.make_loading_bar(
		0,
		game_state.tick_speed,
		rl.ORANGE,
		rl.DARKGRAY,
		{250.0, 16.0},
	)

	top_panel := ui.make_anchor(.Top, ui.make_margin(32, 0, 0, 0, tick_bar_component))

	money_label_component = ui.make_label("", global.font_large, 28, rl.BLACK, .Left)
	illegitimate_money_label_component = ui.make_label(
		"",
		global.font_large_italic,
		28,
		rl.DARKGRAY,
		.Left,
	)

	money_panel := ui.make_anchor(
		.TopLeft,
		ui.make_margin(
			16,
			16,
			16,
			16,
			ui.make_box(
				.Vertical,
				.Start,
				.Fill,
				4,
				money_label_component,
				illegitimate_money_label_component,
			),
		),
	)

	graph = ui.make_graph({250.0, 150.0}, true)

	money_radio_button = ui.make_radio_button(selected = true)
	illegitimate_money_radio_button = ui.make_radio_button()

	ui.radio_button_connect(money_radio_button, illegitimate_money_radio_button)
	ui.radio_button_connect(illegitimate_money_radio_button, money_radio_button)

	graph_panel := ui.make_anchor(
		.TopRight,
		ui.make_margin(
			16,
			16,
			16,
			16,
			ui.make_box(
				.Vertical,
				.Start,
				.Fill,
				4,
				ui.make_box(
					.Horizontal,
					.Start,
					.Center,
					16,
					ui.make_pill(
						rl.GRAY,
						{},
						ui.make_box(
							.Horizontal,
							.Start,
							.Center,
							16,
							ui.make_box(
								.Horizontal,
								.Center,
								.Center,
								4,
								money_radio_button,
								ui.make_label("$", global.font, 24, rl.BLACK, .Left),
							),
							ui.make_box(
								.Horizontal,
								.Center,
								.Center,
								4,
								illegitimate_money_radio_button,
								ui.make_label("₴", global.font, 24, rl.BLACK, .Left),
							),
						),
					),
				),
				graph,
				ui.make_box(
					.Horizontal,
					.Start,
					.Center,
					4,
					ui.make_check_box(),
					ui.make_label("Test check box", global.font, 24, rl.BLACK, .Left),
				),
			),
		),
	)

	stock_window = ui.make_stock_window(&game_state.market)
	stock_window.root.state = .Inactive

	ui_root = ui.make_stack(
		money_panel,
		graph_panel,
		job_panel,
		crew_panel,
		top_panel,
		stock_window.root,
	)

	screen_w := f32(rl.GetScreenWidth())
	screen_h := f32(rl.GetScreenHeight())

	for !rl.WindowShouldClose() {
		delta := rl.GetFrameTime()
		accumulator += delta

		frame_input = input.get_input()

		process_ui_interactions(&frame_input)

		for btn in rl.MouseButton {
			flags := frame_input.mouse_buttons[btn]
			if input.InputFlags.ChangedThisFrame in flags {
				pending_buttons[btn] = flags
			}
		}

		for key in rl.KeyboardKey {
			flags := frame_input.keys[key]
			if input.InputFlags.ChangedThisFrame in flags {
				pending_keys[key] = flags
			}
		}

		updates := 0
		for accumulator >= FIXED_DELTA && updates < max_updates {
			for btn, flags in pending_buttons {
				if .ChangedThisFrame in flags {
					delete_key(&pending_buttons, btn)
					frame_input.mouse_buttons[btn] += {.ChangedThisFrame}
				}
			}

			for key, flags in pending_keys {
				if .ChangedThisFrame in flags {
					delete_key(&pending_keys, key)
					frame_input.keys[key] += {.ChangedThisFrame}
				}
			}

			update(&frame_input)

			for btn in rl.MouseButton {
				frame_input.mouse_buttons[btn] -= {.ChangedThisFrame}
			}

			for key in rl.KeyboardKey {
				frame_input.keys[key] -= {.ChangedThisFrame}
			}

			accumulator -= FIXED_DELTA
			updates += 1
		}

		sync_ui_visuals()

		ui.update_components_recursive(ui_root, {0, 0, screen_w, screen_h})

		alpha := accumulator / FIXED_DELTA

		draw(alpha)

		free_all(context.temp_allocator)
	}

	cleanup()
}

cleanup :: proc() {
	for &building in buildings_list {
		rl.UnloadImage(building.image_data)
	}
	delete(buildings_list)
	delete(job_entries)
	delete(crew_member_entries)
	delete(game_state.tick_stats_buffer)

	stocks.close_market(&game_state.market)

	ui.destroy_components_recursive(ui_root)
}

process_ui_interactions :: proc(input_data: ^input.RawInput) {
	input_data.captured = ui.handle_input_recursive(ui_root, input_data)

	handle_stock_window_interactions()

	handle_job_display_interactions()

	if ui.radio_button_was_activated(money_radio_button) ||
	   ui.radio_button_was_activated(illegitimate_money_radio_button) {
		update_graph()
	}

	for &entry in crew_member_entries {
		ui.update_crew_member_display(
			&entry.display,
			&entry.crew_member,
			game_state.tick_timer,
			game_state.tick_speed,
		)
	}

	if bar, ok := &tick_bar_component.variant.(ui.LoadingBar); ok {
		bar.current = game_state.tick_timer
		bar.max = game_state.tick_speed
	}
}

handle_stock_window_interactions :: proc() {
	if box, ok := &stock_window.stock_list_box.variant.(ui.BoxContainer); ok {
		for child, i in box.children {
			if ui.button_was_clicked(child) {
				selected_id := stock_window.company_list[i]
				stock_window.selected_id = selected_id
			}
		}
	}

	if ui.button_was_clicked(stock_window.buy_button) {
		stocks.execute_buy_order(
			&game_state.market,
			&game_state.stock_portfolio,
			&game_state.money,
			stock_window.selected_id,
			1,
		)
	}

	if ui.button_was_clicked(stock_window.sell_button) {
		stocks.execute_sell_order(
			&game_state.market,
			&game_state.stock_portfolio,
			&game_state.money,
			&game_state.period_income,
			stock_window.selected_id,
			1,
		)
	}

	if ui.button_was_clicked(stock_window.buy_all_button) {
		number_to_buy := int(
			game_state.money / game_state.market.companies[stock_window.selected_id].current_price,
		)
		stocks.execute_buy_order(
			&game_state.market,
			&game_state.stock_portfolio,
			&game_state.money,
			stock_window.selected_id,
			number_to_buy,
		)
	}

	if ui.button_was_clicked(stock_window.sell_all_button) {
		stock_info := &game_state.stock_portfolio.stocks[stock_window.selected_id]
		stocks.execute_sell_order(
			&game_state.market,
			&game_state.stock_portfolio,
			&game_state.money,
			&game_state.period_income,
			stock_window.selected_id,
			stock_info.quantity_owned,
		)
	}
}

handle_job_display_interactions :: proc() {
	for &entry, i in job_entries {
		#partial switch &details in entry.job.details {
		case jobs.BuyinJob:
			has_sufficient_funds :=
				game_state.money >= details.buyin_price &&
				game_state.illegitimate_money >= details.illegitimate_buyin_price
			ui.button_set_disabled(
				entry.display.start_button,
				!has_sufficient_funds && !entry.job.is_ready && !entry.job.is_ready,
			)
		}

		if ui.button_was_clicked(entry.display.start_button) {
			toggle_job_state(&entry, i)
			break
		}
	}
}

toggle_job_state :: proc(entry: ^JobEntry, index: int) {
	job_active := jobs.toggle_state(&entry.job)
	if job_active {
		#partial switch &d in entry.job.details {
		case jobs.BuyinJob:
			game_state.money -= d.buyin_price
			game_state.illegitimate_money -= d.illegitimate_buyin_price
		}

		for &other_entry, j in job_entries {
			if index == j do continue

			jobs.deactivate(&other_entry.job)
		}
	}
}

update :: proc(input_data: ^input.RawInput) {
	if input.is_key_released_this_frame(.SPACE, input_data) {
		game_state.paused = !game_state.paused
	}

	if input.is_key_released_this_frame(.S, input_data) {
		if stock_window.root.state == .Inactive {
			stock_window.root.state = .Active
		} else {
			stock_window.root.state = .Inactive
		}
	}

	if !game_state.paused {
		game_state.tick_timer += FIXED_DELTA
		if game_state.tick_timer >= game_state.tick_speed {
			game_state.tick_timer -= game_state.tick_speed
			tick()
		}
	}

	for &building in buildings_list {
		is_hovered := buildings.is_building_hovered(&building, input_data, &game_state.camera)
		if is_hovered && !input_data.captured {
			building.hovered = true
			if input.is_mouse_button_released_this_frame(.LEFT, input_data) {
				building.selected = true
			}
		} else {
			building.hovered = false
			if input.is_mouse_button_released_this_frame(.LEFT, input_data) {
				building.selected = false
			}
		}
	}

	if input.is_mouse_button_held_down(.MIDDLE, input_data) {
		pan_direction := input_data.mouse_delta / game_state.camera.zoom
		angle := linalg.angle_between(rl.Vector2{1.0, 0.0}, pan_direction) / math.PI
		if angle < 0.5 {
			angle += (0.5 - angle) * 2.0
		}
		game_state.camera.target -= pan_direction * angle
	}

	if !input_data.captured &&
	   input_data.mouse_wheel_movement > 0.0 &&
	   math.abs(game_state.zoom_delay) < math.F32_EPSILON &&
	   game_state.camera_zoom != .Close {
		game_state.zoom_delay = 0.25
		#partial switch game_state.camera_zoom {
		case .Default:
			game_state.camera_zoom = .Close
			game_state.camera.zoom = 2.0
		case .Far:
			game_state.camera_zoom = .Default
			game_state.camera.zoom = 1.0
		}
	} else if !input_data.captured &&
	   input_data.mouse_wheel_movement < 0.0 &&
	   math.abs(game_state.zoom_delay) < math.F32_EPSILON &&
	   game_state.camera_zoom != .Far {
		game_state.zoom_delay = 0.25
		#partial switch game_state.camera_zoom {
		case .Default:
			game_state.camera_zoom = .Far
			game_state.camera.zoom = 0.5
		case .Close:
			game_state.camera_zoom = .Default
			game_state.camera.zoom = 1.0
		}
	}

	if game_state.zoom_delay < math.F32_EPSILON {
		game_state.zoom_delay = 0.0
	} else {
		game_state.zoom_delay -= FIXED_DELTA
	}
}

sync_ui_visuals :: proc() {
	ui.update_stock_window(&stock_window, &game_state.market, &game_state.stock_portfolio)

	for &entry in job_entries {
		ui.update_job_display(
			&entry.display,
			&entry.job,
			game_state.tick_timer,
			game_state.tick_speed,
		)
	}

	if game_state.tax_debt > 0.0 {
		ui.label_set_text(
			money_label_component,
			fmt.tprintf(
				"%s $ (-%s $)",
				global.format_float_thousands(game_state.money, 2),
				global.format_float_thousands(game_state.tax_debt, 2),
			),
		)
	} else {
		ui.label_set_text(
			money_label_component,
			fmt.tprintf("%s $", global.format_float_thousands(game_state.money, 2)),
		)
	}
	ui.label_set_text(
		illegitimate_money_label_component,
		fmt.tprintf("%s ₴", global.format_float_thousands(game_state.illegitimate_money, 2)),
	)
}

tick :: proc() {
	tick_stats: TickStatistics

	prev_money := game_state.money
	prev_illegitimate_money := game_state.illegitimate_money

	for &entry, i in job_entries {
		job_result := jobs.tick(&entry.job)
		if entry.job.is_ready {
			entry.job.is_active = true
		}
		if job_result == .Finished {
			game_state.money += entry.job.income
			game_state.period_income += entry.job.income
			tick_stats.income += entry.job.income
			game_state.illegitimate_money += entry.job.illegitimate_income
			tick_stats.illegitimate_income += entry.job.illegitimate_income
			#partial switch &d in entry.job.details {
			case jobs.BuyinJob:
				jobs.deactivate(&entry.job)
				remove_job(i)
			}
		} else if job_result == .Failed {
			jobs.deactivate(&entry.job)
			remove_job(i)
		}
	}

	for &entry in crew_member_entries {
		job_result := jobs.tick(&entry.crew_member.default_job)
		if entry.crew_member.default_job.is_ready {
			entry.crew_member.default_job.is_active = true
		}
		if job_result == .Finished {
			game_state.money += entry.crew_member.default_job.income
			game_state.period_income += entry.crew_member.default_job.income
			tick_stats.income += entry.crew_member.default_job.income
			game_state.illegitimate_money += entry.crew_member.default_job.illegitimate_income
			tick_stats.illegitimate_income += entry.crew_member.default_job.illegitimate_income
		} else if job_result == .Failed {
			jobs.deactivate(&entry.crew_member.default_job)
		}
	}

	game_state.current_tick += 1
	stocks.update_market_tick(&game_state.market)
	if game_state.current_tick == global.TICKS_PER_PERIOD {
		ui.loading_bar_set_color(tick_bar_component, rl.RED)
	} else if game_state.current_tick > global.TICKS_PER_PERIOD {
		game_state.current_tick = 1

		ui.loading_bar_set_color(tick_bar_component, rl.ORANGE)

		fmt.println("Update market period!")
		calculate_period_end(&tick_stats)
		game_state.current_period += 1

		if (game_state.current_period - 1) % global.PERIODS_PER_QUARTER == 0 {
			game_state.current_period = 1

			fmt.println("Update market quarter!")
			stocks.update_market_quarter(&game_state.market)
			game_state.current_quarter += 1
		}
		if game_state.current_quarter > global.QUARTERS_PER_YEAR {
			game_state.current_quarter = 1
			fmt.println("Update market year!")
			stocks.update_market_year(&game_state.market)
			game_state.current_year += 1
		}
	}

	switch {
	case game_state.money == prev_money:
		game_state.money_change = .Maintained
	case game_state.money < prev_money:
		game_state.money_change = .Decreased
	case game_state.money > prev_money:
		game_state.money_change = .Increased
	}

	switch {
	case game_state.illegitimate_money == prev_illegitimate_money:
		game_state.illegitimate_money_change = .Maintained
	case game_state.illegitimate_money < prev_illegitimate_money:
		game_state.illegitimate_money_change = .Decreased
	case game_state.illegitimate_money > prev_illegitimate_money:
		game_state.illegitimate_money_change = .Increased
	}

	tick_stats.current_money = game_state.money
	tick_stats.current_illegitimate_money = game_state.illegitimate_money

	append(&game_state.tick_stats_buffer, tick_stats)
	if len(game_state.tick_stats_buffer) > game_state.tick_stats_buffer_size {
		ordered_remove(&game_state.tick_stats_buffer, 0)
	}

	update_graph()
}

update_graph :: proc() {
	get_money_from_stats :: proc(data: rawptr, index: int) -> f32 {
		stats_arr := cast(^[dynamic]TickStatistics)data

		if index >= len(stats_arr) do return 0

		return f32(stats_arr[index].current_money)
	}

	get_illegitimate_money_from_stats :: proc(data: rawptr, index: int) -> f32 {
		stats_arr := cast(^[dynamic]TickStatistics)data

		if index >= len(stats_arr) do return 0

		return f32(stats_arr[index].current_illegitimate_money)
	}

	min_val, max_val := math.F64_MAX, math.F64_MIN

	if ui.radio_button_is_selected(money_radio_button) {
		for &stats in game_state.tick_stats_buffer {
			min_val = min(min_val, stats.current_money)
			max_val = max(max_val, stats.current_money)
		}

		range := max_val - min_val

		ui.graph_set_line_color(graph, rl.GREEN)

		ui.graph_set_data(
			graph,
			&game_state.tick_stats_buffer,
			len(game_state.tick_stats_buffer),
			get_money_from_stats,
			f32(min_val - range * 0.1),
			f32(max_val + range * 0.1),
		)
	} else if ui.radio_button_is_selected(illegitimate_money_radio_button) {
		for &stats in game_state.tick_stats_buffer {
			min_val = min(min_val, stats.current_illegitimate_money)
			max_val = max(max_val, stats.current_illegitimate_money)
		}

		range := max_val - min_val

		ui.graph_set_line_color(graph, rl.ORANGE)

		ui.graph_set_data(
			graph,
			&game_state.tick_stats_buffer,
			len(game_state.tick_stats_buffer),
			get_illegitimate_money_from_stats,
			f32(min_val - range * 0.1),
			f32(max_val + range * 0.1),
		)
	}
}

calculate_period_end :: proc(tick_stats: ^TickStatistics) {
	//Calculate and pay salaries
	salaries, salaries_illegitimate: f64
	#reverse for &entry, i in crew_member_entries {
		quit := false
		if game_state.money >= entry.crew_member.base_salary {
			game_state.money -= entry.crew_member.base_salary
			salaries += entry.crew_member.base_salary
		} else {
			game_state.money = 0.0
			quit = true
		}

		if game_state.illegitimate_money >= entry.crew_member.base_salary_illegitimate {
			game_state.illegitimate_money -= entry.crew_member.base_salary_illegitimate
			salaries_illegitimate += entry.crew_member.base_salary_illegitimate
		} else {
			game_state.illegitimate_money = 0.0
			quit = true
		}

		if quit do remove_crew_member(i)
	}

	tick_stats.salaries = salaries
	tick_stats.illegitimate_salaries = salaries_illegitimate

	//Calculate tax debt interest
	tax_debt_interest := game_state.tax_debt * game_state.tax_debt_interest_rate

	//Accumulate tax debt
	game_state.tax_debt += tax_debt_interest

	//Try to pay tax debt
	if game_state.tax_debt > 0.0 {
		if game_state.money >= game_state.tax_debt {
			game_state.money -= game_state.tax_debt
			game_state.tax_debt = 0.0
		} else {
			game_state.tax_debt -= game_state.money
			game_state.money = 0.0
		}
	}

	//Calculate tax
	tax := game_state.period_income * game_state.base_tax_rate
	tick_stats.taxes = tax

	//Try to pay tax
	if tax > 0.0 {
		if game_state.money >= tax {
			game_state.money -= tax
		} else {
			game_state.tax_debt += tax - game_state.money
			game_state.money = 0
		}
	}

	tick_stats.tax_debt = game_state.tax_debt
	game_state.period_income = 0.0

	stocks.update_market_period(&game_state.market)
}

remove_crew_member :: proc(entry_index: int) {
	entry := crew_member_entries[entry_index]
	ui.box_remove_child(crew_members_box, entry.display.root)
	ui.destroy_components_recursive(entry.display.root)
	ordered_remove(&crew_member_entries, entry_index)
}

remove_job :: proc(entry_index: int) {
	entry := job_entries[entry_index]
	ui.box_remove_child(jobs_box, entry.display.root)
	ui.destroy_components_recursive(entry.display.root)
	ordered_remove(&job_entries, entry_index)
}

draw :: proc(alpha: f32) {
	rl.BeginDrawing()
	defer rl.EndDrawing()

	rl.ClearBackground(rl.LIGHTGRAY)

	rl.BeginMode2D(game_state.camera)

	for &building in buildings_list {
		buildings.draw_building(&building)
	}

	rl.EndMode2D()

	/*
    money_string := fmt.ctprintf("Money: %s $", global.format_float_thousands(game_state.money, 2))
    money_string_width := rl.MeasureTextEx(global.font_large, money_string, 28.0, 2.0).x
    illegitimate_money_string := fmt.ctprintf("Illegitimate money: %s ₴", global.format_float_thousands(game_state.illegitimate_money, 2))
    illegitimate_money_string_width := rl.MeasureTextEx(global.font_large_italic, illegitimate_money_string, 28.0, 2.0).x

    rl.DrawTextPro(global.font_large, money_string, {16.0, 16.0}, {0.0, 0.0}, 0.0, 28.0, 2.0, rl.DARKGRAY)
    switch game_state.money_change {
    case .Maintained:
        rl.DrawTextPro(global.font_large, "→", {24.0 + money_string_width, 16.0}, {0.0, 0.0}, 0.0, 28.0, 2.0, rl.DARKGRAY)
    case .Increased:
        rl.DrawTextPro(global.font_large, "↗", {24.0 + money_string_width, 16.0}, {0.0, 0.0}, 0.0, 28.0, 2.0, rl.DARKGREEN)
    case .Decreased:
        rl.DrawTextPro(global.font_large, "↘", {24.0 + money_string_width, 16.0}, {0.0, 0.0}, 0.0, 28.0, 2.0, rl.RED)
    }
    rl.DrawTextPro(global.font_large_italic, illegitimate_money_string, {16.0, 48.0}, {0.0, 0.0}, 0.0, 28.0, 2.0, rl.DARKGRAY)
    switch game_state.illegitimate_money_change {
    case .Maintained:
        rl.DrawTextPro(global.font_large_italic, "→", {24.0 + illegitimate_money_string_width, 48.0}, {0.0, 0.0}, 0.0, 28.0, 2.0, rl.DARKGRAY)
    case .Increased:
        rl.DrawTextPro(global.font_large_italic, "↗", {24.0 + illegitimate_money_string_width, 48.0}, {0.0, 0.0}, 0.0, 28.0, 2.0, rl.DARKGREEN)
    case .Decreased:
        rl.DrawTextPro(global.font_large_italic, "↘", {24.0 + illegitimate_money_string_width, 48.0}, {0.0, 0.0}, 0.0, 28.0, 2.0, rl.RED)
    }
    */

	circle_radius: f32 = 12.0
	ring_width: f32 = 4.0
	period_display_width :=
		global.TICKS_PER_PERIOD * (int(circle_radius) * 2) + (global.TICKS_PER_PERIOD - 1) * 2
	origin := rl.Vector2 {
		global.SCREEN_WIDTH * 0.5 - f32(period_display_width) * 0.5 + circle_radius,
		16,
	}

	circle_progress := 1.0 - (game_state.tick_timer / game_state.tick_speed)
	angle := (360 * circle_progress) - 90

	rl.DrawLineEx(
		origin,
		origin + {(circle_radius * 2 + 2) * f32(global.TICKS_PER_PERIOD - 1), 0},
		6.0,
		rl.DARKGRAY,
	)

	for i in 0 ..< global.TICKS_PER_PERIOD {
		base_color := i == global.TICKS_PER_PERIOD - 1 ? rl.RED : rl.ORANGE
		rl.DrawCircleV(
			origin,
			circle_radius,
			(i + 1) == game_state.current_tick ? rl.RAYWHITE : rl.DARKGRAY,
		)
		rl.DrawRing(
			origin,
			circle_radius - ring_width,
			circle_radius - 2.0,
			0.0,
			360.0,
			16,
			base_color,
		)
		if (i + 1) < game_state.current_tick {
			rl.DrawCircleGradient(
				i32(origin.x),
				i32(origin.y),
				circle_radius - 4.0,
				rl.RAYWHITE,
				base_color,
			)
		}
		if (i + 1) == game_state.current_tick {
			rl.DrawCircleGradient(
				i32(origin.x),
				i32(origin.y),
				circle_radius - 4.0,
				rl.RAYWHITE,
				base_color,
			)
			rl.DrawCircleSector(origin, circle_radius - ring_width, -90.0, angle, 32, rl.DARKGRAY)
		}
		origin += {circle_radius * 2 + 2, 0}
	}

	if ui_root != nil do ui.draw_components_recursive(ui_root)
}
