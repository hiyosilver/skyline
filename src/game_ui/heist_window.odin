package game_ui

//import "../types"
import "../ui"
//import rl "vendor:raylib"

HeistWindow :: struct {
	root:              ^ui.Component,
	level_label:       ^ui.Component,
	name_label:        ^ui.Component,
	description_label: ^ui.Component,
	income_label:      ^ui.Component,
	ticks_label:       ^ui.Component,
	buyin_price_label: ^ui.Component,
	start_button:      ^ui.Component,
	button_label:      ^ui.Component,
	progress_box:      ^ui.Component,
	crew_slots:        [dynamic]CrewSlotDisplay,
}
