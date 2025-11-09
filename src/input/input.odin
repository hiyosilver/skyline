package input

import rl "vendor:raylib"

RawInput :: struct {
    mouse_position: rl.Vector2,
    mouse_delta: rl.Vector2,
    mouse_buttons: [rl.MouseButton]bit_set[InputFlags],
    mouse_wheel_movement: f32,
    keys: #sparse[rl.KeyboardKey]bit_set[InputFlags],
}

InputFlags :: enum u8 {
    Down, 
    ChangedThisFrame,
}

get_input :: proc() -> RawInput {
    input: RawInput

    input.mouse_position = rl.GetMousePosition()
    input.mouse_delta = rl.GetMouseDelta()

    for mouseButton in rl.MouseButton {
        if rl.IsMouseButtonPressed(rl.MouseButton(mouseButton)) {
            input.mouse_buttons[mouseButton] = { InputFlags.Down, InputFlags.ChangedThisFrame }
        } else if rl.IsMouseButtonDown(rl.MouseButton(mouseButton)) && InputFlags.ChangedThisFrame not_in input.mouse_buttons[mouseButton] {
            input.mouse_buttons[mouseButton] = { InputFlags.Down }
        } else if rl.IsMouseButtonReleased(rl.MouseButton(mouseButton)) {
            input.mouse_buttons[mouseButton] = { InputFlags.ChangedThisFrame }
        } else {
            input.mouse_buttons[mouseButton] = {}
        }
    }

    input.mouse_wheel_movement = rl.GetMouseWheelMove()

    for key in rl.KeyboardKey {
        if rl.IsKeyPressed(rl.KeyboardKey(key)) {
            input.keys[key] = { InputFlags.Down, InputFlags.ChangedThisFrame }
        } else if rl.IsKeyDown(rl.KeyboardKey(key)) && InputFlags.ChangedThisFrame not_in input.keys[key] {
            input.keys[key] = { InputFlags.Down }
        } else if rl.IsKeyReleased(rl.KeyboardKey(key)) {
            input.keys[key] = { InputFlags.ChangedThisFrame }
        } else {
            input.keys[key] = {}
        }
    }

    return input
}

is_mouse_button_pressed_this_frame :: proc(button: rl.MouseButton, input: ^RawInput) -> bool {
    return InputFlags.Down in input.mouse_buttons[button] && InputFlags.ChangedThisFrame in input.mouse_buttons[button]
}

is_mouse_button_released_this_frame :: proc(button: rl.MouseButton, input: ^RawInput) -> bool {
    return InputFlags.Down not_in input.mouse_buttons[button] && InputFlags.ChangedThisFrame in input.mouse_buttons[button]
}

is_mouse_button_held_down :: proc(button: rl.MouseButton, input: ^RawInput) -> bool {
    return InputFlags.Down in input.mouse_buttons[button]
}

is_key_pressed_this_frame :: proc(key: rl.KeyboardKey, input: ^RawInput) -> bool {
    return InputFlags.Down in input.keys[key] && InputFlags.ChangedThisFrame in input.keys[key]
}

is_key_released_this_frame :: proc(key: rl.KeyboardKey, input: ^RawInput) -> bool {
    return InputFlags.Down not_in input.keys[key] && InputFlags.ChangedThisFrame in input.keys[key]
}

is_key_held_down :: proc(key: rl.KeyboardKey, input: ^RawInput) -> bool {
    if key < rl.KeyboardKey.A do return false
    return InputFlags.Down in input.keys[key]
}