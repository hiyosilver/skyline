package crown

import rl "vendor:raylib"
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:os"
import "core:path/filepath"
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
    tick_speed: f32,
    tick_timer: f32,

    //Game data
    money: f64,
    money_change: ChangeOnTick,
    illegitimate_money: f64,
    illegitimate_money_change: ChangeOnTick,
}

CameraZoom :: enum {
    Default,
    Close,
    Far,
}

exe_path: string
exe_dir: string

game_state: GameState

tick_bar: ui.LoadingBar

building_test: buildings.Building

jobs_list: [dynamic]jobs.Job
job_displays: [dynamic]ui.JobDisplay

main :: proc() {
    game_state.tick_speed = 1.0
    game_state.money = 20.0

    tick_bar = ui.LoadingBar {
        position = {global.SCREEN_WIDTH * 0.5 - 250.0 * 0.5, 32.0},
        size = {250.0, 16.0},
        max = game_state.tick_speed,
        current = 0.0,
        color = rl.YELLOW,
        background_color = rl.DARKGRAY,
    }

    exe_path = os.args[0]
    exe_dir = filepath.dir(exe_path)
    asset_dir := filepath.join([]string{exe_dir, "../assets"})

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

    building_test = buildings.Building {
        position = {400.0, 800.0},
        texture_id = .Skyscraper1,
        texture_offset = {96.0, 1088.0},
        image_data = rl.LoadImageFromTexture(textures.building_textures[.Skyscraper1]),
        name = "Crown Plaza Tower",
    }

    jobs_list = make([dynamic]jobs.Job)
    job_displays = make([dynamic]ui.JobDisplay)

    jobA := jobs.Job {
        name = "Job A",
        level = 2,
        is_active = false,
        ticks_needed = 6,
        income = 2.5,
        illegitimate_income = 1.5,
        details = jobs.StandardJob{},
    }
    append(&jobs_list, jobA)
    append(&job_displays, ui.create_job_display(&jobA, {16.0, 360.0}, {320.0, 120.0}))

    jobB := jobs.Job {
        name = "Job B",
        level = 1,
        is_active = false,
        ticks_needed = 5,
        income = 3.0,
        details = jobs.StandardJob{},
    }
    append(&jobs_list, jobB)
    append(&job_displays, ui.create_job_display(&jobB, {16.0, 492.0}, {320.0, 120.0}))


    jobC := jobs.Job {
        name = "Job C",
        level = 1,
        is_active = false,
        ticks_needed = 3,
        income = 1.5,
        details = jobs.StandardJob{},
    }
    append(&jobs_list, jobC)
    append(&job_displays, ui.create_job_display(&jobC, {16.0, 628.0}, {320.0, 120.0}))

    jobD : jobs.Job = jobs.Job {
        name = "Risky Job",
        level = 5,
        is_active = false,
        ticks_needed = 10,
        illegitimate_income = 145.0,
        details = jobs.BuyinJob{
            buyin_price = 10.0,
            illegitimate_buyin_price = 10.0,
            failure_chance = 0.02,
        },
    }
    append(&jobs_list, jobD)
    append(&job_displays, ui.create_job_display(&jobD, {16.0, 764.0}, {320.0, 120.0}))

    for !rl.WindowShouldClose() {
        delta := rl.GetFrameTime()
        accumulator += delta

        frame_input = input.get_input()

        update_ui_input(&frame_input)

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

        update_ui(&frame_input)

        alpha := accumulator / FIXED_DELTA

        draw(alpha)
    }
}

@(fini)
finish :: proc() {
    rl.UnloadImage(building_test.image_data)
    delete(jobs_list)
    delete(job_displays)
}

update_ui_input :: proc(input_data: ^input.RawInput) {
    for &display in job_displays {
        ui.update_job_display_input(&display, input_data)
    }
}

update :: proc(input_data: ^input.RawInput) {
    game_state.tick_timer += FIXED_DELTA
    if game_state.tick_timer >= game_state.tick_speed {
        game_state.tick_timer -= game_state.tick_speed
        tick()
    }

    is_hovered := buildings.is_building_hovered(&building_test, input_data, &game_state.camera)
    building_test.hovered = is_hovered
    if input.is_mouse_button_released_this_frame(.LEFT, input_data) {
        building_test.selected = is_hovered
    }

    //world_mouse_pos := rl.GetScreenToWorld2D(input.mouse_position, game_state.camera)

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

update_ui :: proc(input_data: ^input.RawInput) {
    outer: for &display, i in job_displays {
        #partial switch &d in display.job.details {
        case jobs.BuyinJob:
            if game_state.money >= d.buyin_price && game_state.illegitimate_money >= d.illegitimate_buyin_price {
                if display.start_button.state == .Disabled {
                    display.start_button.state = .Idle
                }
            } else if !display.job.is_ready && !display.job.is_ready {
                display.start_button.state = .Disabled
            }
        }

        ui.update_job_display(&display, game_state.tick_timer)
        if display.start_button.state == .Released {
            job_active := jobs.toggle_state(display.job)
            if !job_active {
                ui.reset_job_display(&display)
            } else {
                #partial switch &d in display.job.details {
                case jobs.BuyinJob:
                    game_state.money -= d.buyin_price
                    game_state.illegitimate_money -= d.illegitimate_buyin_price
                }

                for &other_display, j in job_displays {
                    if i == j {
                        continue
                    }
                    jobs.deactivate(other_display.job)
                    ui.reset_job_display(&other_display)
                }
            }
            break outer
        }
    }

    tick_bar.current = game_state.tick_timer
}

tick :: proc() {
    prev_money := game_state.money
    prev_illegitimate_monez := game_state.illegitimate_money

    for &display in job_displays {
        job_result := jobs.tick(display.job)
        if display.job.is_ready {
            display.job.is_active = true
        }
        if job_result == .Finished {
            game_state.money += display.job.income
            game_state.illegitimate_money += display.job.illegitimate_income
            ui.reset_job_display(&display)
            #partial switch &d in display.job.details {
            case jobs.BuyinJob:
                jobs.deactivate(display.job)
            }
        } else if job_result == .Failed {
            jobs.deactivate(display.job)
            ui.reset_job_display(&display)
        }
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
    case game_state.illegitimate_money == prev_illegitimate_monez:
        game_state.illegitimate_money_change = .Maintained
    case game_state.illegitimate_money < prev_illegitimate_monez:
        game_state.illegitimate_money_change = .Decreased
    case game_state.illegitimate_money > prev_illegitimate_monez:
        game_state.illegitimate_money_change = .Increased
    }
}

draw :: proc(alpha: f32) {
    rl.BeginDrawing()
    defer rl.EndDrawing()

    rl.ClearBackground(rl.LIGHTGRAY)

    rl.BeginMode2D(game_state.camera)

    //rl.DrawTextureV(textures.building_textures[.Skyscraper1], {300.0, 100.0}, rl.WHITE)
    buildings.draw_building(&building_test)

    rl.EndMode2D()

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

    //rl.DrawTextPro(global.font_italic, fmt.ctprintf("Scroll delay: %f", game_state.zoom_delay), {16.0, 80.0}, {0.0, 0.0}, 0.0, 24.0, 2.0, rl.DARKGRAY)

    ui.draw_loading_bar(&tick_bar)

    for &display in job_displays {
        ui.draw_job_display(&display)
    }

    free_all(context.temp_allocator)
}
