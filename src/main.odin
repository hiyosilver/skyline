package crown

import rl "vendor:raylib"
import "core:fmt"
import "core:math"
import "core:math/linalg"
//import "core:mem"
import "core:os"
import "core:path/filepath"
import "crew"
import "buildings"
import "global"
import "input"
import "jobs"
import "textures"
import "ui"

UPDATE_FPS   :: 60
RENDER_FPS    :: 120
FIXED_DELTA   :: 1.0 / f32(UPDATE_FPS)

ChangeOnTick :: enum {
    Maintained,
    Increased,
    Decreased,
}

GameState :: struct {
    //Camera
    camera: rl.Camera2D,
    camera_zoom: CameraZoom,
    zoom_delay: f32,

    //Simulation
    paused: bool,
    tick_speed: f32,
    tick_timer: f32,
    period_length: int,
    current_tick: int,

    //Game data
    money: f64,
    period_income: f64,
    money_change: ChangeOnTick,
    illegitimate_money: f64,
    illegitimate_money_change: ChangeOnTick,
    base_tax_rate: f64,
}

CameraZoom :: enum {
    Default,
    Close,
    Far,
}

JobEntry :: struct {
    job: ^jobs.Job,
    display: ui.JobDisplay,
}

CrewEntry :: struct {
    crew_member: ^crew.CrewMember,
    display: ui.CrewMemberDisplay,
}

exe_path: string
exe_dir: string

game_state: GameState

money_label_component: ^ui.Component
illegitimate_money_label_component: ^ui.Component
tick_bar_component: ^ui.Component

buildings_list: [dynamic]buildings.Building 

jobs_list: [dynamic]jobs.Job
job_entries: [dynamic]JobEntry

crew_members_list: [dynamic]crew.CrewMember
crew_member_entries: [dynamic]CrewEntry

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
    game_state.period_length = 30
    game_state.current_tick = 1
    game_state.money = 20.0
    game_state.base_tax_rate = 0.15

    exe_path = os.args[0]
    exe_dir = filepath.dir(exe_path)
    defer delete(exe_dir)
    asset_dir := filepath.join([]string{exe_dir, "../assets"})
    defer delete(asset_dir)

    rl.SetExitKey(rl.KeyboardKey.KEY_NULL)
    rl.SetConfigFlags({ .MSAA_4X_HINT, /*.VSYNC_HINT*/ }) //MSAA causes artifacts when used with raygui for some reason!

    rl.InitWindow(global.SCREEN_WIDTH, global.SCREEN_HEIGHT, "Skyline")
    defer rl.CloseWindow()
    rl.SetTargetFPS(RENDER_FPS)

    textures.load_textures(asset_dir)
    global.load_fonts(asset_dir)
    buildings.load_building_data(asset_dir)

    game_state.camera.target = { global.SCREEN_WIDTH * 0.5, global.SCREEN_HEIGHT * 0.5 }
    game_state.camera.offset = { global.SCREEN_WIDTH * 0.5, global.SCREEN_HEIGHT * 0.5 }
    game_state.camera.rotation = 0.0
    game_state.camera.zoom = 1.0

    accumulator: f32 = 0.0
    max_updates := 5

    frame_input: input.RawInput
    pending_buttons := make(map[rl.MouseButton]bit_set[input.InputFlags])
    pending_keys    := make(map[rl.KeyboardKey]bit_set[input.InputFlags])

    building_crown_plaza := buildings.Building {
        position = {400.0, 800.0},
        texture_id = .SkyscraperCrownPlaza,
        texture_offset = {96.0, 1088.0},
        image_data = rl.LoadImageFromTexture(textures.building_textures[.SkyscraperCrownPlaza].albedo),
        name = "Crown Plaza Tower",
    }
    append(&buildings_list, building_crown_plaza)

    building_atlas_hotel := buildings.Building {
        position = {600.0, 860.0},
        texture_id = .SkyscraperAtlasHotel,
        texture_offset = {77.0, 480.0},
        image_data = rl.LoadImageFromTexture(textures.building_textures[.SkyscraperAtlasHotel].albedo),
        name = "Atlas Hotel",
    }
    append(&buildings_list, building_atlas_hotel)

    jobs_list = make([dynamic]jobs.Job)
    job_entries = make([dynamic]JobEntry)

    jobA := jobs.Job {
        name = "Job A",
        level = 2,
        ticks_needed = 6,
        income = 2.5,
        illegitimate_income = 1.5,
        details = jobs.StandardJob{},
    }
    append(&jobs_list, jobA)
    append(&job_entries, JobEntry{&jobA, ui.make_job_display(&jobA)})

    jobB := jobs.Job {
        name = "Job B",
        level = 1,
        ticks_needed = 5,
        income = 3.0,
        details = jobs.StandardJob{},
    }
    append(&jobs_list, jobB)
    append(&job_entries, JobEntry{&jobB, ui.make_job_display(&jobB)})


    jobC := jobs.Job {
        name = "Job C",
        level = 1,
        ticks_needed = 3,
        income = 1.5,
        details = jobs.StandardJob{},
    }
    append(&jobs_list, jobC)
    append(&job_entries, JobEntry{&jobC, ui.make_job_display(&jobC)})

    jobD : jobs.Job = jobs.Job {
        name = "Risky Job",
        level = 5,
        ticks_needed = 10,
        illegitimate_income = 145.0,
        details = jobs.BuyinJob{
            buyin_price = 10.0,
            illegitimate_buyin_price = 10.0,
            failure_chance = 0.02,
        },
    }
    append(&jobs_list, jobD)
    append(&job_entries, JobEntry{&jobD, ui.make_job_display(&jobD)})

    crew_members_list = make([dynamic]crew.CrewMember)
    crew_member_entries = make([dynamic]CrewEntry)

    crew_member := crew.generate_crew_member()
    append(&crew_members_list, crew_member)
    append(&crew_member_entries, CrewEntry{&crew_member, ui.make_crew_member_display(&crew_member)})

    job_panel := ui.make_anchor(.BottomLeft,
        ui.make_panel(rl.Color{255.0, 255.0, 255.0, 0.0}, {200.0, 0.0},
            ui.make_margin(16, 16, 16, 16, 
                ui.make_box(.Vertical, .SpaceBetween, .Fill, 16,
                    job_entries[0].display.root,
                    job_entries[1].display.root,
                    job_entries[2].display.root,
                    job_entries[3].display.root,
                ),
            ),
        ),
    )

    crew_panel := ui.make_anchor(.BottomRight,
        ui.make_panel(rl.Color{255.0, 255.0, 255.0, 0.0}, {200.0, 0.0},
            ui.make_margin(16, 16, 16, 16, 
                ui.make_box(.Vertical, .SpaceBetween, .Fill, 16,
                    crew_member_entries[0].display.root,
                ),
            ),
        ),
    )

    tick_bar_component = ui.make_loading_bar(0, game_state.tick_speed, rl.ORANGE, rl.DARKGRAY, {250.0, 16.0})

    top_panel := ui.make_anchor(.Top,
        ui.make_margin(32, 0, 0, 0,
            tick_bar_component,
        ),
    )

    money_label_component = ui.make_label("", global.font_large, 28, rl.BLACK, .Left)
    illegitimate_money_label_component = ui.make_label("", global.font_large_italic, 28, rl.DARKGRAY, .Left)

    money_panel := ui.make_anchor(.TopLeft,
        ui.make_margin(16, 16, 16, 16,
            ui.make_box(.Vertical, .Start, .Fill, 4,
                money_label_component,
                illegitimate_money_label_component,
            ),
        ),
    )

    ui_root = ui.make_stack(
        money_panel,
        job_panel,
        crew_panel,
        top_panel,
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
                    frame_input.mouse_buttons[btn] += { .ChangedThisFrame }
                }
            }

            for key, flags in pending_keys {
                if .ChangedThisFrame in flags {
                    delete_key(&pending_keys, key)
                    frame_input.keys[key] += { .ChangedThisFrame }
                }
            }

            update(&frame_input)

            for btn in rl.MouseButton {
                frame_input.mouse_buttons[btn] -= { .ChangedThisFrame }
            }

            for key in rl.KeyboardKey {
                frame_input.keys[key] -= { .ChangedThisFrame }
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
    delete(jobs_list)
    delete(job_entries)
    delete(crew_members_list)
    delete(crew_member_entries)

    ui.destroy_components_recursive(ui_root)
}

process_ui_interactions :: proc(input_data: ^input.RawInput) {
    input_data.captured = ui.handle_input_recursive(ui_root, input_data)

    handle_job_display_interactions()

    for &entry in crew_member_entries {
        ui.update_crew_member_display(&entry.display, entry.crew_member, game_state.tick_timer, game_state.tick_speed)
    }

    if bar, ok := &tick_bar_component.variant.(ui.LoadingBarAlt); ok {
        bar.current = game_state.tick_timer
        bar.max = game_state.tick_speed 
    }
}

handle_job_display_interactions :: proc() {
    for &entry, i in job_entries {
        #partial switch &details in entry.job.details {
        case jobs.BuyinJob:
            has_sufficient_funds := game_state.money >= details.buyin_price && game_state.illegitimate_money >= details.illegitimate_buyin_price
            ui.button_set_disabled(entry.display.start_button, !has_sufficient_funds && !entry.job.is_ready && !entry.job.is_ready)
        }

        if ui.button_was_clicked(entry.display.start_button) {
            toggle_job_state(&entry, i)
            break
        }
    }
}

toggle_job_state :: proc(entry: ^JobEntry, index: int) {
    job_active := jobs.toggle_state(entry.job)
    if job_active {
        #partial switch &d in entry.job.details {
        case jobs.BuyinJob:
            game_state.money -= d.buyin_price
            game_state.illegitimate_money -= d.illegitimate_buyin_price
        }

        for other_entry, j in job_entries {
            if index == j do continue

            jobs.deactivate(other_entry.job)
        }
    }
}

update :: proc(input_data: ^input.RawInput) {
    if input.is_key_released_this_frame(.SPACE, input_data) {
        game_state.paused = ! game_state.paused
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

    if input_data.mouse_wheel_movement > 0.0 && math.abs(game_state.zoom_delay) < math.F32_EPSILON && game_state.camera_zoom != .Close {
        game_state.zoom_delay = 0.25
        #partial switch game_state.camera_zoom {
        case .Default:
            game_state.camera_zoom = .Close
            game_state.camera.zoom = 2.0
        case .Far:
            game_state.camera_zoom = .Default
            game_state.camera.zoom = 1.0
        }
    } else if input_data.mouse_wheel_movement < 0.0 && math.abs(game_state.zoom_delay) < math.F32_EPSILON && game_state.camera_zoom != .Far {
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
    for &entry in job_entries {
        ui.update_job_display(&entry.display, entry.job, game_state.tick_timer, game_state.tick_speed)
    }

    ui.label_set_text(money_label_component, fmt.tprintf("%s $", global.format_float_thousands(game_state.money, 2, ',', '.')))
    ui.label_set_text(illegitimate_money_label_component, fmt.tprintf("%s ₴", global.format_float_thousands(game_state.illegitimate_money, 2, ',', '.')))
}

tick :: proc() {
    prev_money := game_state.money
    prev_illegitimate_money := game_state.illegitimate_money

    for &entry in job_entries {
        job_result := jobs.tick(entry.job)
        if entry.job.is_ready {
            entry.job.is_active = true
        }
        if job_result == .Finished {
            game_state.money += entry.job.income
            game_state.period_income += entry.job.income
            game_state.illegitimate_money += entry.job.illegitimate_income
            #partial switch &d in entry.job.details {
            case jobs.BuyinJob:
                jobs.deactivate(entry.job)
            }
        } else if job_result == .Failed {
            jobs.deactivate(entry.job)
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
            game_state.illegitimate_money += entry.crew_member.default_job.illegitimate_income
        } else if job_result == .Failed {
            jobs.deactivate(&entry.crew_member.default_job)
        }
    }

    game_state.current_tick += 1
    if game_state.current_tick > game_state.period_length {
        game_state.current_tick = 1

        salaries, salaries_illegitimate: f64
        for &crew_member in crew_members_list {
            salaries += crew_member.base_salary
            salaries_illegitimate += crew_member.base_salary_illegitimate
        }

        game_state.money -= salaries
        game_state.illegitimate_money -= salaries_illegitimate

        tax := game_state.period_income * game_state.base_tax_rate

        game_state.money -= tax

        game_state.period_income = 0.0
    }

    switch  {
    case game_state.money == prev_money:
        game_state.money_change = .Maintained
    case game_state.money < prev_money:
        game_state.money_change = .Decreased
    case game_state.money > prev_money:
        game_state.money_change = .Increased
    }

    switch  {
    case game_state.illegitimate_money == prev_illegitimate_money:
        game_state.illegitimate_money_change = .Maintained
    case game_state.illegitimate_money < prev_illegitimate_money:
        game_state.illegitimate_money_change = .Decreased
    case game_state.illegitimate_money > prev_illegitimate_money:
        game_state.illegitimate_money_change = .Increased
    }
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
    money_string := fmt.ctprintf("Money: %s $", global.format_float_thousands(game_state.money, 2, ',', '.'))
    money_string_width := rl.MeasureTextEx(global.font_large, money_string, 28.0, 2.0).x
    illegitimate_money_string := fmt.ctprintf("Illegitimate money: %s ₴", global.format_float_thousands(game_state.illegitimate_money, 2, ',', '.'))
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

    //rl.DrawTextPro(global.font_italic, fmt.ctprintf("Scroll delay: %f", game_state.zoom_delay), {16.0, 80.0}, {0.0, 0.0}, 0.0, 24.0, 2.0, rl.DARKGRAY)

    circle_radius : f32 = 10.0
    period_display_width := game_state.period_length * (int(circle_radius) * 2) + (game_state.period_length - 1) * 2
    origin := rl.Vector2{global.SCREEN_WIDTH * 0.5 - f32(period_display_width) * 0.5 + circle_radius, 16}

    for i in 0..<game_state.period_length {
        base_color := i == game_state.period_length - 1 ? rl.RED : rl.ORANGE
        rl.DrawCircleV(origin, circle_radius, rl.DARKGRAY)
        rl.DrawRing(origin, circle_radius - 4.0, circle_radius - 2.0, 0.0, 360.0, 16, base_color)
        if (i + 1) <= game_state.current_tick {
            rl.DrawCircleGradient(i32(origin.x), i32(origin.y), circle_radius - 4.0, rl.RAYWHITE, base_color)
        }
        origin += {circle_radius * 2 + 2, 0}
    }

    if ui_root != nil do ui.draw_components_recursive(ui_root)
}
