package game_ui

import "../buildings"
import "../global"
import "../ui"
import rl "vendor:raylib"

BuildingInfoPanel :: struct {
	root:       ^ui.Component,
	name_label: ^ui.Component,
}

make_building_info_panel :: proc() -> BuildingInfoPanel {
	widget: BuildingInfoPanel = {}

	widget.name_label = ui.make_label("", global.font, 24.0, rl.BLACK, .Left)

	widget.root = ui.make_anchor(
		.Center,
		ui.make_panel(
			rl.GRAY,
			{100.0, 300.0},
			ui.make_margin(
				8,
				8,
				8,
				8,
				ui.make_box(.Vertical, .Start, .Fill, 4, widget.name_label),
			),
		),
	)

	return widget
}

update_building_info_panel :: proc(widget: ^BuildingInfoPanel, building: ^buildings.Building) {
	ui.label_set_text(widget.name_label, building.name)
}
