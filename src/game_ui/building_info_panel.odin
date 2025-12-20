package game_ui

import "../global"
import "../textures"
import "../types"
import "../ui"
import "core:fmt"
import rl "vendor:raylib"

UpgradeRow :: struct {
	upgrade_id: types.UpgradeID,
	button:     ^ui.Component,
	label:      ^ui.Component,
}

BuildingInfoPanel :: struct {
	root:                ^ui.Component,
	name_label:          ^ui.Component,
	income_label:        ^ui.Component,
	laundering_label:    ^ui.Component,
	owned_label:         ^ui.Component,
	purchase_button_box: ^ui.Component,
	purchase_button:     ^ui.Component,
	or_label:            ^ui.Component,
	alt_purchase_button: ^ui.Component,
	upgrade_button_box:  ^ui.Component,
	upgrade_rows:        [dynamic]UpgradeRow,
	current_building_id: types.BuildingID,
}

make_building_info_panel :: proc() -> BuildingInfoPanel {
	widget: BuildingInfoPanel = {}

	widget.upgrade_button_box = ui.make_box(.Vertical, .Start, .Center, 4)
	widget.upgrade_rows = make([dynamic]UpgradeRow)

	widget.name_label = ui.make_label("", global.font, 24.0, rl.RAYWHITE, .Left)
	widget.income_label = ui.make_label("", global.font_small, 18.0, rl.RAYWHITE, .Left)
	widget.laundering_label = ui.make_label("", global.font_small, 18.0, rl.RAYWHITE, .Left)
	widget.owned_label = ui.make_label(
		"Owned",
		global.font_small_italic,
		18.0,
		rl.RAYWHITE,
		.Right,
	)
	widget.owned_label.state = .Hidden

	labels_box := ui.make_box(
		.Horizontal,
		.SpaceBetween,
		.Center,
		16,
		widget.name_label,
		widget.owned_label,
	)

	widget.purchase_button_box = ui.make_box(.Vertical, .Start, .Center, 4)

	widget.purchase_button = ui.make_simple_button(
		.OnRelease,
		rl.BLUE,
		rl.DARKBLUE,
		{200.0, 50.0},
		ui.make_label("", global.font_small, 18.0, rl.RAYWHITE),
	)

	widget.or_label = ui.make_label("OR", global.font_small, 18.0, rl.RAYWHITE)

	widget.alt_purchase_button = ui.make_simple_button(
		.OnRelease,
		rl.BLUE,
		rl.DARKBLUE,
		{200.0, 50.0},
		ui.make_label("", global.font_small, 18.0, rl.RAYWHITE),
	)

	ui.box_add_child(widget.purchase_button_box, widget.purchase_button)
	ui.box_add_child(widget.purchase_button_box, widget.or_label)
	ui.box_add_child(widget.purchase_button_box, widget.alt_purchase_button)


	widget.root = ui.make_anchor(
		.Center,
		ui.make_n_patch_texture_panel(
			textures.ui_textures[.Panel],
			{100.0, 300.0},
			6,
			6,
			6,
			6,
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
					labels_box,
					widget.income_label,
					widget.laundering_label,
					widget.purchase_button_box,
					widget.upgrade_button_box,
				),
			),
		),
	)

	return widget
}

update_building_info_panel :: proc(
	widget: ^BuildingInfoPanel,
	building: ^types.Building,
	money: f64,
	illegitimate_money: f64,
) {
	can_afford_purchase := true
	can_afford_alt_purchase := true

	if money < building.purchase_price.money ||
	   illegitimate_money < building.purchase_price.illegitimate_money {
		can_afford_purchase = false
	}

	if alt_purchase_price, ok := building.alt_purchase_price.(types.PurchasePrice);
	   ok &&
	   money < alt_purchase_price.money &&
	   illegitimate_money < alt_purchase_price.illegitimate_money {
		can_afford_alt_purchase = false
	}

	should_disable_purchase_button := !can_afford_purchase
	should_disable_alt_purchase_button := !can_afford_alt_purchase
	ui.button_set_disabled(widget.purchase_button, should_disable_purchase_button)
	ui.button_set_disabled(widget.alt_purchase_button, should_disable_alt_purchase_button)

	if should_disable_purchase_button {
		ui.label_set_color(widget.purchase_button.variant.(ui.SimpleButton).child, rl.GRAY)
	} else {
		ui.label_set_color(widget.purchase_button.variant.(ui.SimpleButton).child, rl.RAYWHITE)
	}

	if should_disable_alt_purchase_button {
		ui.label_set_color(widget.alt_purchase_button.variant.(ui.SimpleButton).child, rl.GRAY)
	} else {
		ui.label_set_color(widget.alt_purchase_button.variant.(ui.SimpleButton).child, rl.RAYWHITE)
	}

	ui.label_set_text(widget.name_label, building.name)
	ui.label_set_text(
		widget.income_label,
		fmt.tprintf(
			"$%s per tick",
			global.format_float_thousands(
				building.base_tick_income * building.effect_stats.income_multiplier,
				2,
			),
		),
	)

	laundering_amount :=
		building.base_laundering_amount * building.effect_stats.laundering_amount_multiplier

	laundering_efficiency :=
		building.base_laundering_efficiency +
		building.effect_stats.laundering_efficiency_bonus_flat

	ui.label_set_text(
		widget.laundering_label,
		fmt.tprintf(
			"₴%s to $%s per tick (%s%% efficiency)",
			global.format_float_thousands(laundering_amount, 2),
			global.format_float_thousands(laundering_amount * laundering_efficiency, 2),
			global.format_float_thousands(laundering_efficiency * 100.0, 2),
		),
	)

	if building.owned {
		widget.purchase_button_box.state = .Inactive
		ui.button_reset_state(widget.purchase_button)
		ui.button_reset_state(widget.alt_purchase_button)
		widget.owned_label.state = .Active
	} else {
		widget.purchase_button_box.state = .Active
		widget.owned_label.state = .Hidden

		ui.button_set_label_text(
			widget.purchase_button,
			fmt.tprintf("$%s", global.format_float_thousands(building.purchase_price.money, 2)),
		)

		alt_purchase_button, ok := widget.alt_purchase_button.variant.(ui.SimpleButton)
		alt_price, ok_alt := building.alt_purchase_price.(types.PurchasePrice)

		if ok && ok_alt {
			ui.label_set_text(
				alt_purchase_button.child,
				fmt.tprintf(
					"$%s\n₴%s",
					global.format_float_thousands(alt_price.money, 2),
					global.format_float_thousands(alt_price.illegitimate_money, 2),
				),
			)
		}

		if building.alt_purchase_price == nil {
			widget.alt_purchase_button.state = .Inactive
			widget.or_label.state = .Inactive
		} else {
			widget.alt_purchase_button.state = .Active
			widget.or_label.state = .Active
		}
	}

	needs_rebuild :=
		(building.id != widget.current_building_id) ||
		(len(widget.upgrade_rows) != len(building.upgrades))

	if needs_rebuild {
		if box, ok := &widget.upgrade_button_box.variant.(ui.BoxContainer); ok {
			for child in box.children {
				ui.destroy_components_recursive(child)
			}
			clear(&box.children)
		}

		clear(&widget.upgrade_rows)
		widget.current_building_id = building.id

		for &upgrade in building.upgrades {
			lbl := ui.make_label(
				fmt.tprintf("%s ($%f)", upgrade.name, upgrade.cost),
				global.font_small,
				18,
				rl.WHITE,
			)

			btn := ui.make_simple_button(.OnRelease, rl.DARKGRAY, rl.GRAY, {280, 40}, lbl)

			ui.box_add_child(widget.upgrade_button_box, btn)

			append(
				&widget.upgrade_rows,
				UpgradeRow{upgrade_id = upgrade.id, button = btn, label = lbl},
			)
		}
	}

	for row in widget.upgrade_rows {
		cost: f64 = 0
		for u in building.upgrades {
			if u.id == row.upgrade_id {
				cost = u.cost
				break
			}
		}

		if money >= cost {
			ui.button_set_disabled(row.button, false)
			ui.label_set_color(row.label, rl.WHITE)
		} else {
			ui.button_set_disabled(row.button, true)
			ui.label_set_color(row.label, rl.GRAY)
		}
	}
}
