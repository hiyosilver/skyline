package global

import "core:fmt"
import "core:math"
import "base:intrinsics"
import "core:strings"

approx_equal :: proc(a, b: $T) -> bool where intrinsics.type_is_float(T) {
	epsilon: T
	when T == f32 {
		epsilon = 1e-5
	} else {
		epsilon = 1e-9
	}
    return math.abs(a - b) < epsilon
}

is_approx_zero :: proc(x: $T) -> bool where intrinsics.type_is_float(T) {
	epsilon: T
	when T == f32 {
		epsilon = 1e-5
	} else {
		epsilon = 1e-9
	}
    return math.abs(x) < epsilon
}

/*
 * Formats a float with a given thousands separator.
 
 * @param val The float value to format.
 * @param precision The number of decimal places to show.
 * @param thousand_sep The rune to use as a thousands separator (e.g., ',').
 * @param decimal_sep The rune to use as a decimal separator (e.g., '.').
 * @param allocator The allocator to use for the new string.
 
 * @return A new string with the formatted number.
 */
format_float_thousands :: proc(
	val: f64, 
	precision: int, 
	thousand_sep: rune = ',',
	decimal_sep: rune = '.',
	allocator := context.temp_allocator,
) -> string {
	sb := strings.builder_make(allocator)
	val := val

	if val < 0 {
		strings.write_byte(&sb, '-')
		val = -val
	}

	scale := math.pow(10, f64(precision))
	rounded_val := math.round(val * scale) / scale
	
	int_part, frac_part := math.modf(rounded_val)
	int_val := i64(int_part)

	int_str := fmt.tprintf("%d", int_val)
	n := len(int_str)

	start_len := n % 3
	if start_len == 0 && n > 0 {
		start_len = 3
	}

	strings.write_string(&sb, int_str[0:start_len])

	for i := start_len; i < n; i += 3 {
		strings.write_rune(&sb, thousand_sep)
		strings.write_string(&sb, int_str[i:i+3])
	}

	if precision > 0 {
		strings.write_rune(&sb, decimal_sep)
		
		frac_val := i64(math.round(frac_part * scale))
		
		frac_fmt_str := fmt.tprintf("%%0%dd", precision)
		frac_str := fmt.tprintf(frac_fmt_str, frac_val)
		
		strings.write_string(&sb, frac_str)
	}
	
	return strings.to_string(sb)
}

/*
 * Formats an int with a given thousands separator.

 * @param val The int value to format.
 * @param thousand_sep The rune to use as a thousands separator (e.g., ',').
 * @param allocator The allocator to use for the new string.

 * @return A new string with the formatted number.
 */
format_int_thousands :: proc(
	val: int,
	thousand_sep: rune = ',',
	allocator := context.temp_allocator,
) -> string {
	sb := strings.builder_make(allocator)
	val := val

	if val < 0 {
		strings.write_byte(&sb, '-')
		val = -val
	}

	int_str := fmt.tprintf("%d", val)
	n := len(int_str)

	start_len := n % 3
	if start_len == 0 && n > 0 {
		start_len = 3
	}

	strings.write_string(&sb, int_str[0:start_len])

	for i := start_len; i < n; i += 3 {
		strings.write_rune(&sb, thousand_sep)
		strings.write_string(&sb, int_str[i:i+3])
	}

	return strings.to_string(sb)
}