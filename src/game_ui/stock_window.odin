package game_ui

import "../global"
import "../stocks"
import "../textures"
import "../types"
import "../ui"
import "core:fmt"
import "core:math"
import "core:slice"
import rl "vendor:raylib"

StockWindow :: struct {
	root:                             ^ui.Component,
	selected_id:                      types.CompanyID,
	company_list:                     [dynamic]types.CompanyID,
	rating_labels:                    [dynamic]^ui.Component,
	status_texture_panels:            [dynamic]^ui.Component,
	stock_price_labels:               [dynamic]^ui.Component,
	stock_price_graphs:               [dynamic]^ui.Component,
	stock_price_range_indicators:     [dynamic]^ui.Component,
	stock_list_box:                   ^ui.Component,
	detail_root:                      ^ui.Component,
	name_label:                       ^ui.Component,
	description_label:                ^ui.Component,
	rating_label:                     ^ui.Component,
	price_label:                      ^ui.Component,
	available_label:                  ^ui.Component,
	owned_label:                      ^ui.Component,
	profit_loss_pct_label:            ^ui.Component,
	cost_basis_label:                 ^ui.Component,
	proceeds_label:                   ^ui.Component,
	profit_loss_label:                ^ui.Component,
	buy_button:                       ^ui.Component,
	sell_button:                      ^ui.Component,
	buy_all_button:                   ^ui.Component,
	buy_all_amount_label:             ^ui.Component,
	sell_all_button:                  ^ui.Component,
	DEBUG_earnings_per_share_label:   ^ui.Component,
	DEBUG_sentiment_multiplier_label: ^ui.Component,
	DEBUG_volatility_label:           ^ui.Component,
	DEBUG_momentum_equilibrium_label: ^ui.Component,
	DEBUG_momentum_label:             ^ui.Component,
	DEBUG_growth_rate_label:          ^ui.Component,
	DEBUG_credit_rating_label:        ^ui.Component,
	DEBUG_payout_ratio_label:         ^ui.Component,
}

destroy_stock_window :: proc(stock_window: ^StockWindow) {
	delete(stock_window.company_list)
	delete(stock_window.rating_labels)
	delete(stock_window.status_texture_panels)
	delete(stock_window.stock_price_labels)
	delete(stock_window.stock_price_graphs)
	delete(stock_window.stock_price_range_indicators)
}

make_stock_window :: proc(market: ^stocks.Market) -> StockWindow {
	widget: StockWindow = {}

	widget.company_list = make([dynamic]types.CompanyID)
	for id, _ in market.companies {
		append(&widget.company_list, id)
	}
	slice.sort(widget.company_list[:])

	widget.selected_id = -1

	widget.stock_list_box = ui.make_box(.Vertical, .Start, .Fill, 4)

	widget.rating_labels = make([dynamic]^ui.Component)
	widget.status_texture_panels = make([dynamic]^ui.Component)
	widget.stock_price_labels = make([dynamic]^ui.Component)
	widget.stock_price_graphs = make([dynamic]^ui.Component)
	widget.stock_price_range_indicators = make([dynamic]^ui.Component)
	for id in widget.company_list {
		company := &market.companies[id]
		rating_label := ui.make_label("-", global.font_small_italic, 18, rl.BLACK, .Right)
		status_texture_panel := ui.make_texture_panel(textures.ui_textures[.Circle], {8.0, 8.0})
		status_texture_panel.state = .Hidden
		stock_price_label := ui.make_label("-", global.font_small, 18, rl.BLACK, .Right)
		stock_price_graph := ui.make_graph({90.0, 35.0})
		stock_price_range_indicator := ui.make_range_indicator(0.0, 100.0, 50.0, {90.0, 6.0})
		ui.graph_set_point_size(stock_price_graph, 1.0)
		append(&widget.rating_labels, rating_label)
		append(&widget.status_texture_panels, status_texture_panel)
		append(&widget.stock_price_labels, stock_price_label)
		append(&widget.stock_price_graphs, stock_price_graph)
		append(&widget.stock_price_range_indicators, stock_price_range_indicator)
		ui.box_add_child(
			widget.stock_list_box,
			ui.make_simple_button(
				.OnRelease,
				rl.GRAY,
				rl.DARKGRAY,
				{},
				ui.make_box(
					.Horizontal,
					.SpaceBetween,
					.Center,
					12,
					ui.make_box(
						.Horizontal,
						.Start,
						.Center,
						12,
						ui.make_pill(
							rl.GRAY,
							{60.0, 0.0},
							ui.make_label(
								fmt.tprintf("%s", company.ticker_symbol),
								global.font_small_italic,
								18,
								rl.BLACK,
								.Center,
							),
						),
						ui.make_label(
							fmt.tprintf("%s", company.name),
							global.font,
							24,
							rl.BLACK,
							.Left,
						),
						rating_label,
					),
					ui.make_box(
						.Horizontal,
						.Start,
						.Center,
						8,
						status_texture_panel,
						stock_price_label,
						ui.make_box(
							.Vertical,
							.Start,
							.Center,
							2,
							stock_price_graph,
							stock_price_range_indicator,
						),
					),
				),
			),
		)
	}

	widget.name_label = ui.make_label("-", global.font, 24, rl.BLACK)
	widget.description_label = ui.make_label("-", global.font_small_italic, 18, rl.BLACK)
	widget.rating_label = ui.make_label("-", global.font_small_italic, 18, rl.BLACK)
	widget.price_label = ui.make_label("-", global.font_small, 18, rl.BLACK)
	widget.available_label = ui.make_label("-", global.font_small, 18, rl.BLACK)
	widget.owned_label = ui.make_label("-", global.font_small, 18, rl.BLACK)
	widget.profit_loss_pct_label = ui.make_label("-", global.font_small, 18, rl.BLACK)
	widget.cost_basis_label = ui.make_label("-", global.font_small, 18, rl.BLACK)
	widget.proceeds_label = ui.make_label("-", global.font_small, 18, rl.BLACK)
	widget.profit_loss_label = ui.make_label("-", global.font_small, 18, rl.BLACK)

	widget.buy_button = ui.make_simple_button(
		.OnRelease,
		rl.GRAY,
		rl.DARKGRAY,
		{100.0, 0.0},
		ui.make_label("Buy 1", global.font, 24, rl.BLACK),
	)
	widget.sell_button = ui.make_simple_button(
		.OnRelease,
		rl.GRAY,
		rl.DARKGRAY,
		{100.0, 0.0},
		ui.make_label("Sell 1", global.font, 24, rl.BLACK),
	)
	widget.buy_all_amount_label = ui.make_label("-", global.font_tiny, 14, rl.BLACK)
	widget.buy_all_button = ui.make_simple_button(
		.OnRelease,
		rl.GRAY,
		rl.DARKGRAY,
		{100.0, 0.0},
		ui.make_box(
			.Vertical,
			.Center,
			.Center,
			2,
			ui.make_label("Buy all", global.font, 24, rl.BLACK),
			widget.buy_all_amount_label,
		),
	)
	widget.sell_all_button = ui.make_simple_button(
		.OnRelease,
		rl.GRAY,
		rl.DARKGRAY,
		{100.0, 0.0},
		ui.make_label("Sell all", global.font, 24, rl.BLACK),
	)

	widget.DEBUG_earnings_per_share_label = ui.make_label("-", global.font_small, 18, rl.BLACK)
	widget.DEBUG_sentiment_multiplier_label = ui.make_label("-", global.font_small, 18, rl.BLACK)
	widget.DEBUG_volatility_label = ui.make_label("-", global.font_small, 18, rl.BLACK)
	widget.DEBUG_momentum_equilibrium_label = ui.make_label("-", global.font_small, 18, rl.BLACK)
	widget.DEBUG_momentum_label = ui.make_label("-", global.font_small, 18, rl.BLACK)
	widget.DEBUG_growth_rate_label = ui.make_label("-", global.font_small, 18, rl.BLACK)
	widget.DEBUG_credit_rating_label = ui.make_label("-", global.font_small, 18, rl.BLACK)
	widget.DEBUG_payout_ratio_label = ui.make_label("-", global.font_small, 18, rl.BLACK)

	widget.detail_root = ui.make_panel(
		rl.DARKGRAY,
		{0, 200},
		ui.make_margin(
			8,
			8,
			8,
			8,
			ui.make_box(
				.Horizontal,
				.SpaceBetween,
				.Fill,
				16,
				ui.make_box(
					.Vertical,
					.Start,
					.Start,
					10,
					ui.make_box(
						.Vertical,
						.Center,
						.Start,
						0,
						ui.make_box(
							.Horizontal,
							.Start,
							.Start,
							8,
							widget.name_label,
							widget.rating_label,
						),
						widget.description_label,
					),
					widget.price_label,
					widget.available_label,
					ui.make_box(
						.Horizontal,
						.Start,
						.Fill,
						8,
						widget.owned_label,
						widget.profit_loss_pct_label,
					),
					widget.cost_basis_label,
					ui.make_box(
						.Horizontal,
						.Start,
						.Fill,
						8,
						widget.proceeds_label,
						widget.profit_loss_label,
					),
					ui.make_box(
						.Horizontal,
						.Start,
						.Fill,
						8,
						widget.buy_button,
						widget.sell_button,
					),
					ui.make_box(
						.Horizontal,
						.Start,
						.Fill,
						8,
						widget.buy_all_button,
						widget.sell_all_button,
					),
				),
				ui.make_box(
					.Vertical,
					.Start,
					.Start,
					0,
					widget.DEBUG_earnings_per_share_label,
					widget.DEBUG_sentiment_multiplier_label,
					widget.DEBUG_volatility_label,
					widget.DEBUG_momentum_equilibrium_label,
					widget.DEBUG_momentum_label,
					widget.DEBUG_growth_rate_label,
					widget.DEBUG_credit_rating_label,
					widget.DEBUG_payout_ratio_label,
				),
			),
		),
	)

	widget.root = ui.make_anchor(
		.Center,
		ui.make_n_patch_texture_panel(
			textures.ui_textures[.Panel],
			{},
			6,
			6,
			6,
			6,
			rl.Color{64, 48, 92, 255},
			ui.make_margin(
				16,
				16,
				16,
				16,
				ui.make_box(
					.Vertical,
					.Start,
					.Fill,
					10,
					ui.make_label("Stock Market", global.font_large, 28, rl.WHITE),
					ui.make_scroll_container(
						{600.0, global.WINDOW_HEIGHT * 0.5},
						widget.stock_list_box,
					),
					widget.detail_root,
				),
			),
		),
	)

	return widget
}

update_stock_window :: proc(
	window: ^StockWindow,
	market: ^stocks.Market,
	portfolio: ^stocks.StockPortfolio,
	money: f64,
) {
	for id, i in window.company_list {
		company := &market.companies[id]
		stock_info := &portfolio.stocks[id]

		rating := stocks.score_to_rating(company.credit_rating)
		label, _, color := stocks.get_rating_data(rating)
		ui.label_set_color(window.rating_labels[i], color)
		ui.label_set_text(window.rating_labels[i], label)

		if stock_info.quantity_owned > 0 {
			window.status_texture_panels[i].state = .Active
			unrealized_profit_loss_pct :=
				((company.current_price / stock_info.average_cost) - 1.0) * 100.0
			if global.is_approx_zero(unrealized_profit_loss_pct) {
				ui.texture_panel_set_tint_color(window.status_texture_panels[i], rl.WHITE)
			} else if unrealized_profit_loss_pct < 0.0 {
				ui.texture_panel_set_tint_color(window.status_texture_panels[i], rl.RED)
			} else if unrealized_profit_loss_pct > 0.0 {
				ui.texture_panel_set_tint_color(window.status_texture_panels[i], rl.GREEN)
			}

			if abs(unrealized_profit_loss_pct) >= 5.0 {
				window.status_texture_panels[i].min_size = {10.0, 10.0}
			} else {
				window.status_texture_panels[i].min_size = {8.0, 8.0}
			}
		} else {
			window.status_texture_panels[i].state = .Hidden
		}

		ui.label_set_text(
			window.stock_price_labels[i],
			fmt.tprintf("$%.2f", company.current_price),
		)

		min_val, max_val := math.F64_MAX, math.F64_MIN
		for &price in company.price_history {
			min_val = min(min_val, price)
			max_val = max(max_val, price)
		}

		range := max_val - min_val

		min_visual_range := company.current_price * 0.02
		if range < min_visual_range {
			center := (max_val + min_val) * 0.5
			min_val = center - (min_visual_range * 0.5)
			max_val = center + (min_visual_range * 0.5)
			range = max_val - min_val
		}

		get_price_from_history :: proc(data: rawptr, index: int) -> f32 {
			stats_arr := cast(^[dynamic]f64)data

			if index >= len(stats_arr) do return 0

			return f32(stats_arr[index])
		}

		ui.graph_set_data(
			window.stock_price_graphs[i],
			&company.price_history,
			len(company.price_history),
			get_price_from_history,
			f32(min_val - range * 0.1),
			f32(max_val + range * 0.1),
		)

		ui.range_indicator_set_data(
			window.stock_price_range_indicators[i],
			company.all_time_low,
			company.all_time_high,
			company.current_price,
		)
	}

	if company, ok := &market.companies[window.selected_id]; ok {
		window.detail_root.state = .Active

		stock_info := &portfolio.stocks[window.selected_id]
		available_stocks := stocks.get_available_shares(company, stock_info)

		ui.label_set_text(window.name_label, company.name)
		ui.label_set_text(window.description_label, company.description)

		rating := stocks.score_to_rating(company.credit_rating)
		label, _, color := stocks.get_rating_data(rating)

		ui.label_set_color(window.rating_label, color)
		ui.label_set_text(window.rating_label, label)
		ui.label_set_text(
			window.price_label,
			fmt.tprintf("$%.2f per share", company.current_price),
		)
		ui.label_set_text(
			window.available_label,
			fmt.tprintf("%s shares available", global.format_int_thousands(available_stocks)),
		)
		if stock_info.quantity_owned > 0 {
			window.profit_loss_pct_label.state = .Active
			window.cost_basis_label.state = .Active
			window.proceeds_label.state = .Active
			window.profit_loss_label.state = .Active
			ui.label_set_text(
				window.owned_label,
				fmt.tprintf(
					"You own %s shares @ %s",
					global.format_int_thousands(stock_info.quantity_owned),
					global.format_float_thousands(stock_info.average_cost, 2),
				),
			)
			unrealized_profit_loss_pct :=
				((company.current_price / stock_info.average_cost) - 1.0) * 100.0
			if global.is_approx_zero(unrealized_profit_loss_pct) {
				ui.label_set_color(window.profit_loss_pct_label, rl.BLACK)
				ui.label_set_text(window.profit_loss_pct_label, "[0.00 %]")
			} else if unrealized_profit_loss_pct < 0.0 {
				ui.label_set_color(window.profit_loss_pct_label, rl.RED)
				ui.label_set_text(
					window.profit_loss_pct_label,
					fmt.tprintf(
						"[%s %%]",
						global.format_float_thousands(unrealized_profit_loss_pct, 2),
					),
				)
			} else if unrealized_profit_loss_pct > 0.0 {
				ui.label_set_color(window.profit_loss_pct_label, rl.GREEN)
				ui.label_set_text(
					window.profit_loss_pct_label,
					fmt.tprintf(
						"[+%s %%]",
						global.format_float_thousands(unrealized_profit_loss_pct, 2),
					),
				)
			}

			cost_basis := f64(stock_info.quantity_owned) * stock_info.average_cost
			proceeds := f64(stock_info.quantity_owned) * company.current_price

			ui.label_set_text(
				window.cost_basis_label,
				fmt.tprintf("Cost basis: $%s", global.format_float_thousands(cost_basis, 2)),
			)
			ui.label_set_text(
				window.proceeds_label,
				fmt.tprintf("Proceeds: $%s", global.format_float_thousands(proceeds, 2)),
			)

			unrealized_profit_loss := proceeds - cost_basis
			if global.is_approx_zero(unrealized_profit_loss) {
				ui.label_set_color(window.profit_loss_label, rl.BLACK)
				ui.label_set_text(window.profit_loss_label, "[$0.00]")
			} else if unrealized_profit_loss < 0.0 {
				ui.label_set_color(window.profit_loss_label, rl.RED)
				ui.label_set_text(
					window.profit_loss_label,
					fmt.tprintf("[$%s]", global.format_float_thousands(unrealized_profit_loss, 2)),
				)
			} else if unrealized_profit_loss > 0.0 {
				ui.label_set_color(window.profit_loss_label, rl.GREEN)
				ui.label_set_text(
					window.profit_loss_label,
					fmt.tprintf(
						"[$+%s]",
						global.format_float_thousands(unrealized_profit_loss, 2),
					),
				)
			}
		} else {
			ui.label_set_text(window.owned_label, "You own no shares")
			window.profit_loss_pct_label.state = .Inactive
			window.cost_basis_label.state = .Inactive
			window.proceeds_label.state = .Inactive
			window.profit_loss_label.state = .Inactive
		}

		ui.label_set_text(
			window.buy_all_amount_label,
			fmt.tprintf("%d", int(money / company.current_price)),
		)

		ui.label_set_text(
			window.DEBUG_earnings_per_share_label,
			fmt.tprintf("DEBUG EPS: %f", company.earnings_per_share),
		)
		ui.label_set_text(
			window.DEBUG_sentiment_multiplier_label,
			fmt.tprintf("DEBUG Sentiment: %f", company.sentiment_multiplier),
		)
		ui.label_set_text(
			window.DEBUG_volatility_label,
			fmt.tprintf("DEBUG volatility: %f", company.volatility),
		)
		ui.label_set_text(
			window.DEBUG_momentum_equilibrium_label,
			fmt.tprintf("DEBUG momentum equi: %f", company.momentum_equilibrium),
		)
		ui.label_set_text(
			window.DEBUG_momentum_label,
			fmt.tprintf("DEBUG momentum: %f", company.momentum),
		)
		ui.label_set_text(
			window.DEBUG_growth_rate_label,
			fmt.tprintf("DEBUG growth rate: %f", company.growth_rate),
		)
		ui.label_set_text(
			window.DEBUG_credit_rating_label,
			fmt.tprintf("DEBUG credit rating: %d", company.credit_rating),
		)
		ui.label_set_text(
			window.DEBUG_payout_ratio_label,
			fmt.tprintf("DEBUG payout ratio: %f", company.payout_ratio),
		)

	} else {
		window.detail_root.state = .Hidden
	}
}
