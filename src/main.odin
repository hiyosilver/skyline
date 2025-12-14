package crown

import "buildings"
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:os"
import "core:path/filepath"
import "crew"
import "game_ui"
import "global"
import "input"
import "jobs"
import "simulation"
import "stocks"
import "textures"
import "types"
import "ui"
import rl "vendor:raylib"

UPDATE_FPS :: 60
RENDER_FPS :: 120
FIXED_DELTA :: 1.0 / f32(UPDATE_FPS)

CameraZoom :: enum {
	Default,
	Close,
	Far,
}

DefaultSelectionState :: struct {
}

AssignCrewMemberSelectionState :: struct {
	target_job_id:          types.JobID,
	target_crew_slot_index: int,
}

SelectionState :: union #no_nil {
	DefaultSelectionState,
	AssignCrewMemberSelectionState,
}

GameUIHandles :: struct {
	ui_root:                            ^ui.Component,
	money_label_component:              ^ui.Component,
	illegitimate_money_label_component: ^ui.Component,
	tick_bar_component:                 ^ui.Component,
	jobs_box:                           ^ui.Component,
	crew_members_box:                   ^ui.Component,
	graph:                              ^ui.Component,
	money_radio_button:                 ^ui.Component,
	illegitimate_money_radio_button:    ^ui.Component,
	stock_window:                       game_ui.StockWindow,
	building_info_panel:                game_ui.BuildingInfoPanel,
}

GameState :: struct {
	camera:           rl.Camera2D,
	camera_zoom:      CameraZoom,
	zoom_delay:       f32,
	selection_state:  SelectionState,

	// UI Containers
	job_view_models:  [dynamic]game_ui.JobCard,
	crew_view_models: [dynamic]game_ui.CrewMemberCard,
	ui:               GameUIHandles,
}

JobEntry :: struct {
	job:     types.Job,
	display: game_ui.JobCard,
}

CrewEntry :: struct {
	crew_member: types.CrewMember,
	display:     game_ui.CrewMemberCard,
}

exe_path: string
exe_dir: string

simulation_state: simulation.SimulationState
game_state: GameState

buildings_list: [dynamic]buildings.Building


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

	simulation_state = simulation.init()

	game_state.camera.target = {global.SCREEN_WIDTH * 0.5, global.SCREEN_HEIGHT * 0.5}
	game_state.camera.offset = {global.SCREEN_WIDTH * 0.5, global.SCREEN_HEIGHT * 0.5}
	game_state.camera.rotation = 0.0
	game_state.camera.zoom = 1.0

	init_game_ui_layout()

	setup_debug_scenario(&simulation_state, &game_state)

	frame_input: input.RawInput
	pending_buttons := make(map[rl.MouseButton]bit_set[input.InputFlags])
	pending_keys := make(map[rl.KeyboardKey]bit_set[input.InputFlags])
	defer delete(pending_buttons)
	defer delete(pending_keys)

	screen_w := f32(rl.GetScreenWidth())
	screen_h := f32(rl.GetScreenHeight())

	accumulator: f32 = 0.0
	max_updates := 5

	for !rl.WindowShouldClose() {
		delta := rl.GetFrameTime()
		accumulator += delta

		frame_input = input.get_input()

		process_ui_interactions(&frame_input)

		process_game_input(&frame_input)

		buffer_input_changes(&frame_input, &pending_buttons, &pending_keys)

		updates := 0
		for accumulator >= FIXED_DELTA && updates < max_updates {
			apply_buffered_inputs(&frame_input, &pending_buttons, &pending_keys)

			update_fixed(&frame_input)

			clear_buffered_inputs(&frame_input)

			accumulator -= FIXED_DELTA
			updates += 1
		}

		if len(game_state.job_view_models) != len(simulation_state.job_entries) {
			rebuild_job_ui_list()
		}

		if len(game_state.crew_view_models) != len(simulation_state.crew_roster) {
			rebuild_crew_ui_list()
		}

		sync_ui_visuals()

		ui.update_components_recursive(game_state.ui.ui_root, {0, 0, screen_w, screen_h})

		alpha := accumulator / FIXED_DELTA

		draw(alpha)

		free_all(context.temp_allocator)
	}

	cleanup()
}

init_game_ui_layout :: proc() {
	game_state.ui.jobs_box = ui.make_box(.Vertical, .SpaceBetween, .Fill, 8)

	job_scroll_container := ui.make_scroll_container(
		{0.0, global.SCREEN_HEIGHT * 0.5},
		game_state.ui.jobs_box,
		scroll_bar_position = .Left,
	)

	job_panel := ui.make_anchor(.BottomLeft, ui.make_margin(16, 16, 16, 16, job_scroll_container))


	game_state.ui.crew_members_box = ui.make_box(.Vertical, .SpaceBetween, .Fill, 8)

	crew_panel := ui.make_anchor(
		.BottomRight,
		ui.make_margin(16, 16, 16, 16, game_state.ui.crew_members_box),
	)

	game_state.ui.tick_bar_component = ui.make_loading_bar(
		0,
		simulation_state.tick_speed,
		rl.ORANGE,
		rl.DARKGRAY,
		{250.0, 16.0},
	)

	top_panel := ui.make_anchor(
		.Top,
		ui.make_margin(32, 0, 0, 0, game_state.ui.tick_bar_component),
	)

	game_state.ui.money_label_component = ui.make_label("", global.font_large, 28, rl.BLACK, .Left)
	game_state.ui.illegitimate_money_label_component = ui.make_label(
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
				game_state.ui.money_label_component,
				game_state.ui.illegitimate_money_label_component,
			),
		),
	)

	game_state.ui.graph = ui.make_graph({250.0, 150.0}, true)

	game_state.ui.money_radio_button = ui.make_radio_button(selected = true)
	game_state.ui.illegitimate_money_radio_button = ui.make_radio_button()

	ui.radio_button_connect(
		game_state.ui.money_radio_button,
		game_state.ui.illegitimate_money_radio_button,
	)
	ui.radio_button_connect(
		game_state.ui.illegitimate_money_radio_button,
		game_state.ui.money_radio_button,
	)

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
								game_state.ui.money_radio_button,
								ui.make_label("$", global.font, 24, rl.BLACK, .Left),
							),
							ui.make_box(
								.Horizontal,
								.Center,
								.Center,
								4,
								game_state.ui.illegitimate_money_radio_button,
								ui.make_label("₴", global.font, 24, rl.BLACK, .Left),
							),
						),
					),
				),
				game_state.ui.graph,
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

	game_state.ui.stock_window = game_ui.make_stock_window(&simulation_state.market)
	game_state.ui.stock_window.root.state = .Inactive

	game_state.ui.building_info_panel = game_ui.make_building_info_panel()
	game_state.ui.building_info_panel.root.state = .Inactive

	game_state.ui.ui_root = ui.make_stack(
		money_panel,
		graph_panel,
		job_panel,
		crew_panel,
		top_panel,
		game_state.ui.stock_window.root,
		game_state.ui.building_info_panel.root,
	)
}

setup_debug_scenario :: proc(simulation: ^simulation.SimulationState, game_state: ^GameState) {
	building_crown_plaza := buildings.Building {
		position       = {400.0, 800.0},
		texture_id     = .SkyscraperCrownPlaza,
		texture_offset = {96.0, 1088.0},
		image_data     = rl.LoadImageFromTexture(
			textures.building_textures[.SkyscraperCrownPlaza],
		),
		name           = "Crown Plaza Tower",
	}
	append(&buildings_list, building_crown_plaza)

	building_atlas_hotel := buildings.Building {
		position       = {600.0, 860.0},
		texture_id     = .SkyscraperAtlasHotel,
		texture_offset = {77.0, 480.0},
		image_data     = rl.LoadImageFromTexture(
			textures.building_textures[.SkyscraperAtlasHotel],
		),
		name           = "Atlas Hotel",
	}
	append(&buildings_list, building_atlas_hotel)

	jobA := jobs.create_job("Construction", 2, 6, 2.5, 1.5)
	append(&simulation_state.job_entries, jobA)

	jobB := jobs.create_job("Waiting", 1, 5, 3.0, 0.0)
	append(&simulation_state.job_entries, jobB)

	jobC := jobs.create_job("Fast food", 1, 3, 1.5, 0.0)
	append(&simulation_state.job_entries, jobC)

	jobD := jobs.create_job("Collect debt", 5, 10, 0.0, 145.0, true)
	append(&simulation_state.job_entries, jobD)

	crew_memberA := crew.generate_crew_member()
	append(&simulation_state.crew_roster, crew_memberA)

	crew_memberB := crew.generate_crew_member()
	append(&simulation_state.crew_roster, crew_memberB)

	crew_memberC := crew.generate_crew_member()
	append(&simulation_state.crew_roster, crew_memberC)

	rebuild_job_ui_list()
	rebuild_crew_ui_list()
}

buffer_input_changes :: proc(
	frame_input: ^input.RawInput,
	pending_buttons: ^map[rl.MouseButton]bit_set[input.InputFlags],
	pending_keys: ^map[rl.KeyboardKey]bit_set[input.InputFlags],
) {
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
}

apply_buffered_inputs :: proc(
	frame_input: ^input.RawInput,
	pending_buttons: ^map[rl.MouseButton]bit_set[input.InputFlags],
	pending_keys: ^map[rl.KeyboardKey]bit_set[input.InputFlags],
) {
	for btn, flags in pending_buttons {
		if .ChangedThisFrame in flags {
			delete_key(pending_buttons, btn)
			frame_input.mouse_buttons[btn] += {.ChangedThisFrame}
		}
	}
	for key, flags in pending_keys {
		if .ChangedThisFrame in flags {
			delete_key(pending_keys, key)
			frame_input.keys[key] += {.ChangedThisFrame}
		}
	}
}

clear_buffered_inputs :: proc(frame_input: ^input.RawInput) {
	for btn in rl.MouseButton {
		frame_input.mouse_buttons[btn] -= {.ChangedThisFrame}
	}
	for key in rl.KeyboardKey {
		frame_input.keys[key] -= {.ChangedThisFrame}
	}
}

cleanup :: proc() {
	for &building in buildings_list {
		rl.UnloadImage(building.image_data)
	}
	delete(buildings_list)
	delete(simulation_state.job_entries)
	delete(simulation_state.crew_roster)
	delete(simulation_state.tick_stats_buffer)

	stocks.close_market(&simulation_state.market)

	ui.destroy_components_recursive(game_state.ui.ui_root)
}

process_ui_interactions :: proc(input_data: ^input.RawInput) {
	input_data.captured = ui.handle_input_recursive(game_state.ui.ui_root, input_data)

	handle_stock_window_interactions()

	handle_job_card_interactions()

	if ui.radio_button_was_activated(game_state.ui.money_radio_button) ||
	   ui.radio_button_was_activated(game_state.ui.illegitimate_money_radio_button) {
		update_graph()
	}

	handle_crew_member_card_interactions()

	if bar, ok := &game_state.ui.tick_bar_component.variant.(ui.LoadingBar); ok {
		bar.current = simulation_state.tick_timer
		bar.max = simulation_state.tick_speed
	}
}

rebuild_job_ui_list :: proc() {
	if box, ok := &game_state.ui.jobs_box.variant.(ui.BoxContainer); ok {
		for &job_card in box.children {
			ui.destroy_components_recursive(job_card)
		}
		clear(&box.children)
	}
	clear(&game_state.job_view_models)

	for &job in simulation_state.job_entries {
		card := game_ui.make_job_card(&job)
		append(&game_state.job_view_models, card)
		ui.box_add_child(game_state.ui.jobs_box, card.root)
	}
}

rebuild_crew_ui_list :: proc() {
	if box, ok := &game_state.ui.crew_members_box.variant.(ui.BoxContainer); ok {
		for &crew_card in box.children {
			ui.destroy_components_recursive(crew_card)
		}
		clear(&box.children)
	}
	clear(&game_state.crew_view_models)

	for &crew in simulation_state.crew_roster {
		card := game_ui.make_crew_member_card(&crew)
		append(&game_state.crew_view_models, card)
		ui.box_add_child(game_state.ui.crew_members_box, card.root)
	}
}

update_graph :: proc() {
	get_money_from_stats :: proc(data: rawptr, index: int) -> f32 {
		stats_arr := cast(^[dynamic]simulation.TickStatistics)data

		if index >= len(stats_arr) do return 0

		return f32(stats_arr[index].current_money)
	}

	get_illegitimate_money_from_stats :: proc(data: rawptr, index: int) -> f32 {
		stats_arr := cast(^[dynamic]simulation.TickStatistics)data

		if index >= len(stats_arr) do return 0

		return f32(stats_arr[index].current_illegitimate_money)
	}

	min_val, max_val := math.F64_MAX, math.F64_MIN

	if ui.radio_button_is_selected(game_state.ui.money_radio_button) {
		for &stats in simulation_state.tick_stats_buffer {
			min_val = min(min_val, stats.current_money)
			max_val = max(max_val, stats.current_money)
		}

		range := max_val - min_val

		ui.graph_set_line_color(game_state.ui.graph, rl.GREEN)

		ui.graph_set_data(
			game_state.ui.graph,
			&simulation_state.tick_stats_buffer,
			len(simulation_state.tick_stats_buffer),
			get_money_from_stats,
			f32(min_val - range * 0.1),
			f32(max_val + range * 0.1),
		)
	} else if ui.radio_button_is_selected(game_state.ui.illegitimate_money_radio_button) {
		for &stats in simulation_state.tick_stats_buffer {
			min_val = min(min_val, stats.current_illegitimate_money)
			max_val = max(max_val, stats.current_illegitimate_money)
		}

		range := max_val - min_val

		ui.graph_set_line_color(game_state.ui.graph, rl.ORANGE)

		ui.graph_set_data(
			game_state.ui.graph,
			&simulation_state.tick_stats_buffer,
			len(simulation_state.tick_stats_buffer),
			get_illegitimate_money_from_stats,
			f32(min_val - range * 0.1),
			f32(max_val + range * 0.1),
		)
	}
}

handle_stock_window_interactions :: proc() {
	if box, ok := &game_state.ui.stock_window.stock_list_box.variant.(ui.BoxContainer); ok {
		for child, i in box.children {
			if ui.button_was_clicked(child) {
				selected_id := game_state.ui.stock_window.company_list[i]
				game_state.ui.stock_window.selected_id = selected_id
			}
		}
	}

	if ui.button_was_clicked(game_state.ui.stock_window.buy_button) {
		simulation.buy_stock(&simulation_state, game_state.ui.stock_window.selected_id, 1)
	}

	if ui.button_was_clicked(game_state.ui.stock_window.sell_button) {
		simulation.sell_stock(&simulation_state, game_state.ui.stock_window.selected_id, 1)
	}

	if ui.button_was_clicked(game_state.ui.stock_window.buy_all_button) {
		number_to_buy := int(
			simulation_state.money /
			simulation_state.market.companies[game_state.ui.stock_window.selected_id].current_price,
		)
		simulation.buy_stock(
			&simulation_state,
			game_state.ui.stock_window.selected_id,
			number_to_buy,
		)
	}

	if ui.button_was_clicked(game_state.ui.stock_window.sell_all_button) {
		stock_info := &simulation_state.stock_portfolio.stocks[game_state.ui.stock_window.selected_id]
		simulation.sell_stock(
			&simulation_state,
			game_state.ui.stock_window.selected_id,
			stock_info.quantity_owned,
		)
	}
}

handle_job_card_interactions :: proc() {
	for i in 0 ..< len(simulation_state.job_entries) {
		job := &simulation_state.job_entries[i]
		if i >= len(game_state.job_view_models) do break
		display := &game_state.job_view_models[i]

		#partial switch &details in job.details {
		case types.BuyinJob:
			has_sufficient_funds :=
				simulation_state.money >= details.buyin_price &&
				simulation_state.illegitimate_money >= details.illegitimate_buyin_price
			ui.button_set_disabled(
				display.start_button,
				!has_sufficient_funds && !job.is_ready && !job.is_ready,
			)

			for slot_display, j in display.crew_slots {
				if ui.button_was_clicked(slot_display.root_button) {
					if details.crew_member_slots[j].assigned_crew_member != 0 {
						simulation.clear_crew(&simulation_state, job.id, j)
					} else {
						game_state.selection_state = AssignCrewMemberSelectionState {
							target_job_id          = job.id,
							target_crew_slot_index = j,
						}
					}
				}
			}
		}

		if ui.button_was_clicked(display.start_button) {
			simulation.interact_toggle_job(&simulation_state, i)
			break
		}
	}
}

handle_crew_member_card_interactions :: proc() {
	state, is_crew_selection_mode := game_state.selection_state.(AssignCrewMemberSelectionState)

	for i in 0 ..< len(simulation_state.crew_roster) {
		crew_member := &simulation_state.crew_roster[i]
		if i >= len(game_state.crew_view_models) do break
		display := &game_state.crew_view_models[i]

		job_lookup := simulation.generate_job_lookup(&simulation_state)

		game_ui.update_crew_member_card(
			display,
			crew_member,
			simulation_state.tick_timer,
			simulation_state.tick_speed,
			is_crew_selection_mode,
			job_lookup,
		)

		if ui.button_was_clicked(display.root) {
			if is_crew_selection_mode {
				if simulation.try_assign_crew(
					&simulation_state,
					state.target_job_id,
					state.target_crew_slot_index,
					crew_member.id,
				) {
					game_state.selection_state = DefaultSelectionState{}
					sync_ui_visuals()
				}
			}
		}
	}
}

process_game_input :: proc(input_data: ^input.RawInput) {
	if input.is_key_released_this_frame(.SPACE, input_data) {
		simulation_state.paused = !simulation_state.paused
	}

	if input.is_key_released_this_frame(.S, input_data) {
		if game_state.ui.stock_window.root.state == .Inactive {
			game_state.ui.stock_window.root.state = .Active

			for &building in buildings_list {
				building.selected = false
			}

			game_state.ui.building_info_panel.root.state = .Inactive
		} else {
			game_state.ui.stock_window.root.state = .Inactive
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

update_fixed :: proc(input_data: ^input.RawInput) {
	if !simulation_state.paused {
		simulation_state.tick_timer += FIXED_DELTA
		if simulation_state.tick_timer >= simulation_state.tick_speed {
			simulation_state.tick_timer -= simulation_state.tick_speed
			simulation.tick(&simulation_state)
		}
	}

	show_building_info_panel := false
	for &building in buildings_list {
		if building.selected {
			show_building_info_panel = true
		}

		if input_data.captured do continue

		is_hovered := buildings.is_building_hovered(&building, input_data, &game_state.camera)
		if is_hovered {
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

	if show_building_info_panel {
		game_state.ui.building_info_panel.root.state = .Active
		game_state.ui.stock_window.root.state = .Inactive
	} else {
		game_state.ui.building_info_panel.root.state = .Inactive
	}

	if simulation_state.current_tick == global.TICKS_PER_PERIOD {
		ui.loading_bar_set_color(game_state.ui.tick_bar_component, rl.RED)
	} else {
		ui.loading_bar_set_color(game_state.ui.tick_bar_component, rl.ORANGE)
	}
}

sync_ui_visuals :: proc() {
	update_graph()

	game_ui.update_stock_window(
		&game_state.ui.stock_window,
		&simulation_state.market,
		&simulation_state.stock_portfolio,
	)

	for &building in buildings_list {
		if building.selected {
			game_ui.update_building_info_panel(&game_state.ui.building_info_panel, &building)
			break
		}
	}

	crew_lookup := simulation.generate_crew_lookup(&simulation_state)

	for i in 0 ..< len(simulation_state.job_entries) {
		data := &simulation_state.job_entries[i]
		view := &game_state.job_view_models[i]

		game_ui.update_job_card(
			view,
			data,
			simulation_state.tick_timer,
			simulation_state.tick_speed,
			crew_lookup,
		)
	}

	if simulation_state.tax_debt > 0.0 {
		ui.label_set_text(
			game_state.ui.money_label_component,
			fmt.tprintf(
				"$%s (-$%s)",
				global.format_float_thousands(simulation_state.money, 2),
				global.format_float_thousands(simulation_state.tax_debt, 2),
			),
		)
	} else {
		ui.label_set_text(
			game_state.ui.money_label_component,
			fmt.tprintf("$%s", global.format_float_thousands(simulation_state.money, 2)),
		)
	}
	ui.label_set_text(
		game_state.ui.illegitimate_money_label_component,
		fmt.tprintf(
			"₴%s",
			global.format_float_thousands(simulation_state.illegitimate_money, 2),
		),
	)
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

	draw_tick_indicator()

	if game_state.ui.ui_root != nil do ui.draw_components_recursive(game_state.ui.ui_root)
}

draw_tick_indicator :: proc() {
	circle_radius: f32 = 12.0
	ring_width: f32 = 4.0
	period_display_width :=
		global.TICKS_PER_PERIOD * (int(circle_radius) * 2) + (global.TICKS_PER_PERIOD - 1) * 2
	origin := rl.Vector2 {
		global.SCREEN_WIDTH * 0.5 - f32(period_display_width) * 0.5 + circle_radius,
		16,
	}

	circle_progress := 1.0 - (simulation_state.tick_timer / simulation_state.tick_speed)
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
			(i + 1) == simulation_state.current_tick ? rl.RAYWHITE : rl.DARKGRAY,
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
		if (i + 1) < simulation_state.current_tick {
			rl.DrawCircleGradient(
				i32(origin.x),
				i32(origin.y),
				circle_radius - 4.0,
				rl.RAYWHITE,
				base_color,
			)
		}
		if (i + 1) == simulation_state.current_tick {
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
}
