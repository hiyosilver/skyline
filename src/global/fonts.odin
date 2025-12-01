package global

import rl "vendor:raylib"
import "core:fmt"
import "core:unicode/utf8"

font: rl.Font
font_italic: rl.Font
font_large: rl.Font
font_large_italic: rl.Font
font_small: rl.Font
font_small_italic: rl.Font

load_fonts :: proc(asset_dir: string) {
    symbols := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890!?()[]%/$₴@~,;.:'+-↗→↘◆◇▶▷"
    runes_array := utf8.string_to_runes(symbols)
    rune_count := utf8.rune_count_in_string(symbols)
    defer delete(runes_array)

    raw := cast([^]rune)(&runes_array[0])

	font_file_path := fmt.caprintf("%s/fonts/vollkorn/Vollkorn-VariableFont_wght.ttf", asset_dir)
    font = rl.LoadFontEx(font_file_path, 24, raw, i32(rune_count))
    delete(font_file_path)
    font_file_path = fmt.caprintf("%s/fonts/vollkorn/Vollkorn-VariableFont_wght.ttf", asset_dir)
    font_large = rl.LoadFontEx(font_file_path, 28, raw, i32(rune_count))
    delete(font_file_path)
    font_file_path = fmt.caprintf("%s/fonts/vollkorn/Vollkorn-VariableFont_wght.ttf", asset_dir)
    font_small = rl.LoadFontEx(font_file_path, 18, raw, i32(rune_count))
    delete(font_file_path)
    font_file_path = fmt.caprintf("%s/fonts/vollkorn/Vollkorn-Italic-VariableFont_wght.ttf", asset_dir)
    font_italic = rl.LoadFontEx(font_file_path, 24, raw, i32(rune_count))
    delete(font_file_path)
    font_file_path = fmt.caprintf("%s/fonts/vollkorn/Vollkorn-Italic-VariableFont_wght.ttf", asset_dir)
    font_large_italic = rl.LoadFontEx(font_file_path, 28, raw, i32(rune_count))
    delete(font_file_path)
    font_file_path = fmt.caprintf("%s/fonts/vollkorn/Vollkorn-Italic-VariableFont_wght.ttf", asset_dir)
    font_small_italic = rl.LoadFontEx(font_file_path, 18, raw, i32(rune_count))
    delete(font_file_path)
}

@(fini)
unload_fonts :: proc() {
	rl.UnloadFont(font)
	rl.UnloadFont(font_italic)
}