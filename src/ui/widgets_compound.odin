package ui

import rl "vendor:raylib"
import "core:fmt"
import "core:math"
import "core:slice"
import "core:strings"
import "../crew"
import "../global"
import "../jobs"
import "../stocks"
import "../textures"

JobDisplay :: struct {
	root: ^Component,

	level_label: ^Component,
	name_label: ^Component,
	income_label: ^Component,
	ticks_label: ^Component,
	buyin_price_label: ^Component,
	start_button: ^Component,
	button_label: ^Component,

	progress_box: ^Component,
}

make_job_display :: proc(job: ^jobs.Job) -> JobDisplay {
	widget: JobDisplay = {}

	base_color, button_color: rl.Color

	widget.buyin_price_label = make_label("", global.font_small_italic, 18.0, rl.BLACK, .Center)
	buyin_pill := make_pill(rl.RAYWHITE, {}, widget.buyin_price_label)

	if _, ok := job.details.(jobs.BuyinJob); ok {
		base_color = rl.Color{192, 92, 92, 255}
		button_color = rl.RED
	} else {
		base_color = rl.GRAY
		button_color = rl.DARKGRAY
		buyin_pill.state = .Inactive
	}

	widget.button_label = make_label("", global.font, 24.0, rl.RAYWHITE)
	widget.start_button = make_simple_button(.OnRelease, button_color, {80.0, 0.0}, widget.button_label)

	widget.level_label = make_label("", global.font_small, 18.0, rl.RAYWHITE, .Left)
	widget.name_label = make_label("", global.font, 24.0, rl.RAYWHITE, .Left)
	widget.income_label = make_label("", global.font_small_italic, 18.0, rl.RAYWHITE, .Left)
	widget.ticks_label = make_label("", global.font_small_italic, 18.0, rl.RAYWHITE, .Left)

	total_width := f32(320.0 - 32.0)
	widget.progress_box = make_box(.Horizontal, .Start, .Fill, 1)

	if job.ticks_needed > 0 {
		total_gap_width := f32(job.ticks_needed - 1) * 1.0
		segment_width := (total_width - total_gap_width) / f32(job.ticks_needed)

		for _ in 0..<job.ticks_needed {
			bar := make_loading_bar(
				0, 1.0,
				rl.YELLOW, rl.DARKGRAY,
				{segment_width, 8.0},
			)

			box_add_child(widget.progress_box, bar)
		}
	}

	widget.root = make_panel(base_color, {320.0, 120.0},
		make_margin(16, 16, 16, 16,
			make_box(.Vertical, .SpaceBetween, .Fill, 4,
				make_box(.Horizontal, .Fill, .Fill, 16,
					make_box(.Vertical, .SpaceBetween, .Fill, 4,
						widget.level_label,
						widget.name_label,
						widget.income_label,
					),
					make_box(.Vertical, .Start, .End, 4,
						widget.start_button,
						buyin_pill,
					),
				),
				widget.ticks_label,
				widget.progress_box,
			),
		),
	)

	update_job_display(&widget, job, 0.0, 1.0)

	return widget
}

update_job_display :: proc(widget: ^JobDisplay, job: ^jobs.Job, tick_timer: f32, tick_speed: f32) {
	label_set_text(widget.level_label, fmt.tprintf("%s%s", strings.repeat("◆", job.level, context.temp_allocator), strings.repeat("◇", 10 - job.level, context.temp_allocator)))
	label_set_text(widget.name_label, job.name)
	if job.is_active {
		label_set_text(widget.name_label, fmt.tprintf("%s ▶", job.name))
	} else if job.is_ready {
		label_set_text(widget.name_label, fmt.tprintf("%s ▷", job.name))
	} else {
		label_set_text(widget.name_label, job.name)
	}

	if job.income > 0.0 {
		if job.illegitimate_income > 0.0 {
			label_set_text(widget.income_label, fmt.tprintf("%s $ + %s ₴", global.format_float_thousands(job.income, 2), global.format_float_thousands(job.illegitimate_income, 2)))
		} else {
			label_set_text(widget.income_label, fmt.tprintf("%s $", global.format_float_thousands(job.income, 2)))
		}
	} else {
		label_set_text(widget.income_label, fmt.tprintf("%s ₴", global.format_float_thousands(job.illegitimate_income, 2)))
	}

	if details, ok := job.details.(jobs.BuyinJob); ok {
		label_set_text(widget.ticks_label, fmt.tprintf("%d ticks (Failure chance: %s%% / tick)", job.ticks_needed, global.format_float_thousands(f64(details.failure_chance * 100.0), 2)))
		if details.buyin_price > 0.0 {
			if details.illegitimate_buyin_price > 0.0 {
				label_set_text(widget.buyin_price_label, fmt.tprintf("%s $ + %s ₴", global.format_float_thousands(details.buyin_price, 2), global.format_float_thousands(details.illegitimate_buyin_price, 2)))
			} else {
				label_set_text(widget.buyin_price_label, fmt.tprintf("%s $", global.format_float_thousands(details.buyin_price, 2)))
			}
		} else {
			label_set_text(widget.buyin_price_label, fmt.tprintf("%s ₴", global.format_float_thousands(details.illegitimate_buyin_price, 2)))
		}
	} else {
		label_set_text(widget.ticks_label, fmt.tprintf("%d ticks", job.ticks_needed))
	}

	label_set_text(widget.button_label, job.is_ready || job.is_active ? "Stop" : "Start")

	if box, ok := &widget.progress_box.variant.(BoxContainer); ok {
		for child, i in box.children {
			if bar, is_bar := &child.variant.(LoadingBar); is_bar {
				if !job.is_active {
					 bar.current = 0.0
				} else if i < job.ticks_current {
					bar.current = 1.0
					bar.max = 1.0
				} else if i == job.ticks_current {
					bar.current = tick_timer
					bar.max = tick_speed
				} else {
					bar.current = 0.0
				}
			}
		}
	}
}

CrewMemberDisplay :: struct {
	root:           ^Component,

	nickname_label: ^Component,
	salary_label:   ^Component,
	job_name_label: ^Component,
	income_label:   ^Component,
	ticks_label:    ^Component,
	progress_box:   ^Component,
}

make_crew_member_display :: proc(cm: ^crew.CrewMember) -> CrewMemberDisplay {
	widget: CrewMemberDisplay = {}

	base_color: rl.Color
	#partial switch details in cm.default_job.details {
	case jobs.BuyinJob:
		base_color = rl.Color{192, 92, 92, 255}
	case:
		base_color = rl.GRAY
	}

	widget.nickname_label = make_label("", global.font, 24.0, rl.RAYWHITE, .Left)

	widget.salary_label = make_label("", global.font_small, 18.0, rl.BLACK, .Right)

	widget.job_name_label = make_label("", global.font_small, 18.0, rl.RAYWHITE, .Left)
	widget.income_label   = make_label("", global.font_small_italic, 18.0, rl.RAYWHITE, .Left)
	widget.ticks_label    = make_label("", global.font_small_italic, 18.0, rl.RAYWHITE, .Left)

	usable_width := f32(320.0 - 32.0)

	widget.progress_box = make_box(.Horizontal, .Start, .Fill, 1)

	ticks_needed := cm.default_job.ticks_needed
	if ticks_needed > 0 {
		total_gaps := f32(ticks_needed - 1) * 1.0
		segment_width := (usable_width - total_gaps) / f32(ticks_needed)

		for _ in 0..<ticks_needed {
			bar := make_loading_bar(
				0.0, 1.0,
				rl.Color{92, 92, 192, 255},
				rl.DARKGRAY,
				{segment_width, 8.0},
			)
			box_add_child(widget.progress_box, bar)
		}
	}

	widget.root = make_panel(base_color, {320.0, 120.0},
		make_margin(16, 16, 16, 16,
			make_box(.Vertical, .SpaceBetween, .Fill, 4,
				make_box(.Horizontal, .SpaceBetween, .Center, 0,
					widget.nickname_label,
					make_pill(rl.RAYWHITE, {},
						widget.salary_label,
					),
				),
				make_box(.Vertical, .Start, .Fill, 2,
					widget.job_name_label,
					widget.income_label,
					widget.ticks_label,
				),
				widget.progress_box,
			),
		),
	)

	update_crew_member_display(&widget, cm, 0.0, 1.0)

	return widget
}

update_crew_member_display :: proc(widget: ^CrewMemberDisplay, cm: ^crew.CrewMember, tick_timer: f32, tick_speed: f32) {
	label_set_text(widget.nickname_label, fmt.tprintf("'%s'", cm.nickname))

	if cm.base_salary > 0.0 {
		if cm.base_salary_illegitimate > 0.0 {
			label_set_text(widget.salary_label, fmt.tprintf("%s $ + %s ₴", global.format_float_thousands(cm.base_salary, 2), global.format_float_thousands(cm.base_salary_illegitimate, 2)))
		} else {
			label_set_text(widget.salary_label, fmt.tprintf("%s $", global.format_float_thousands(cm.base_salary, 2)))
		}
	} else {
		label_set_text(widget.salary_label, fmt.tprintf("%s ₴", global.format_float_thousands(cm.base_salary_illegitimate, 2)))
	}

	job_name := cm.default_job.name
	if cm.default_job.is_active {
		label_set_text(widget.job_name_label, fmt.tprintf("%s ▶", job_name))
	} else if cm.default_job.is_ready {
		label_set_text(widget.job_name_label, fmt.tprintf("%s ▷", job_name))
	} else {
		label_set_text(widget.job_name_label, job_name)
	}

	job := &cm.default_job
	if job.income > 0.0 {
		if job.illegitimate_income > 0.0 {
			label_set_text(widget.income_label, fmt.tprintf("%s $ + %s ₴", global.format_float_thousands(job.income, 2), global.format_float_thousands(job.illegitimate_income, 2)))
		} else {
			label_set_text(widget.income_label, fmt.tprintf("%s $", global.format_float_thousands(job.income, 2)))
		}
	} else {
		label_set_text(widget.income_label, fmt.tprintf("%s ₴", global.format_float_thousands(job.illegitimate_income, 2)))
	}

	#partial switch details in job.details {
	case jobs.BuyinJob:
		 label_set_text(widget.ticks_label, fmt.tprintf("%d ticks (Fail: %s%%)", job.ticks_needed, global.format_float_thousands(f64(details.failure_chance * 100.0), 1)))
	case:
		 label_set_text(widget.ticks_label, fmt.tprintf("%d ticks", job.ticks_needed))
	}

	if box, ok := &widget.progress_box.variant.(BoxContainer); ok {
		for child, i in box.children {
			if bar, is_bar := &child.variant.(LoadingBar); is_bar {
				if !job.is_active {
					bar.current = 0.0
				} else if i < job.ticks_current {
					bar.current = 1.0
					bar.max = 1.0
				} else if i == job.ticks_current {
					bar.current = tick_timer
					bar.max = tick_speed
				} else {
					bar.current = 0.0
				}
			}
		}
	}
}

StockWindow :: struct {
	root: ^Component,

	selected_id: stocks.CompanyID,
	company_list: [dynamic]stocks.CompanyID,
	rating_labels: [dynamic]^Component,
	status_texture_panels: [dynamic]^Component,
	stock_price_labels: [dynamic]^Component,
	stock_price_graphs: [dynamic]^Component,
	stock_price_range_indicators: [dynamic]^Component,

	stock_list_box: ^Component,

	detail_root:    ^Component,
	name_label:     ^Component,
	description_label:     ^Component,
	rating_label:     ^Component,
	price_label:    ^Component,
	available_label:    ^Component,
	owned_label:    ^Component,
	profit_loss_pct_label:    ^Component,
	cost_basis_label:    ^Component,
	proceeds_label:    ^Component,
	profit_loss_label:    ^Component,
	buy_button:    ^Component,
	sell_button:    ^Component,
	buy_all_button:    ^Component,
	buy_all_amount_label:    ^Component,
	sell_all_button:    ^Component,
	sell_all_profit_label:    ^Component,

	DEBUG_earnings_per_share_label: ^Component,
	DEBUG_sentiment_multiplier_label: ^Component,
	DEBUG_volatility_label: ^Component,
	DEBUG_momentum_equilibrium_label: ^Component,
	DEBUG_momentum_label: ^Component,
	DEBUG_growth_rate_label: ^Component,
	DEBUG_credit_rating_label: ^Component,
	DEBUG_payout_ratio_label: ^Component,
}

make_stock_window :: proc(market: ^stocks.Market) -> StockWindow {
	widget: StockWindow = {}

	widget.company_list = make([dynamic]stocks.CompanyID)
	for id, _ in market.companies {
		append(&widget.company_list, id)
	}
	slice.sort(widget.company_list[:])

	widget.selected_id = -1

	base_color := rl.GRAY

	widget.stock_list_box = make_box(.Vertical, .Start, .Fill, 4)

	widget.rating_labels = make([dynamic]^Component)
	widget.status_texture_panels = make([dynamic]^Component)
	widget.stock_price_labels = make([dynamic]^Component)
	widget.stock_price_graphs = make([dynamic]^Component)
	widget.stock_price_range_indicators = make([dynamic]^Component)
	for id in widget.company_list {
		company := &market.companies[id]
		rating_label := make_label("-", global.font_small_italic, 18, rl.BLACK, .Right)
		status_texture_panel := make_texture_panel(textures.ui_textures[.Circle], {8.0, 8.0})
		status_texture_panel.state = .Hidden
		stock_price_label := make_label("-", global.font_small, 18, rl.BLACK, .Right)
		stock_price_graph := make_graph({90.0, 35.0})
		stock_price_range_indicator := make_range_indicator(0.0, 100.0, 50.0, {90.0, 6.0})
		graph_set_point_size(stock_price_graph, 1.0)
		append(&widget.rating_labels, rating_label)
		append(&widget.status_texture_panels, status_texture_panel)
		append(&widget.stock_price_labels, stock_price_label)
		append(&widget.stock_price_graphs, stock_price_graph)
		append(&widget.stock_price_range_indicators, stock_price_range_indicator)
		box_add_child(widget.stock_list_box,
			make_simple_button(.OnRelease, rl.DARKGRAY, {},
				make_box(.Horizontal, .SpaceBetween, .Center, 12,
					make_box(.Horizontal, .Start, .Center, 12,
						make_pill(rl.GRAY, {60.0, 0.0},
							make_label(fmt.tprintf("%s", company.ticker_symbol), global.font_small_italic, 18, rl.BLACK, .Center),
						),
						make_label(fmt.tprintf("%s", company.name), global.font, 24, rl.BLACK, .Left),
						rating_label,
					),
					make_box(.Horizontal, .Start, .Center, 8,
						status_texture_panel,
						stock_price_label,
						make_box(.Vertical, .Start, .Center, 2,
							stock_price_graph,
							stock_price_range_indicator,
						),
					),
				),
			),
		)
	}

	widget.name_label  = make_label("-", global.font, 24, rl.BLACK)
	widget.description_label  = make_label("-", global.font_small_italic, 18, rl.BLACK)
	widget.rating_label  = make_label("-", global.font_small_italic, 18, rl.BLACK)
	widget.price_label = make_label("-", global.font_small, 18, rl.BLACK)
	widget.available_label = make_label("-", global.font_small, 18, rl.BLACK)
	widget.owned_label = make_label("-", global.font_small, 18, rl.BLACK)
	widget.profit_loss_pct_label = make_label("-", global.font_small, 18, rl.BLACK)
	widget.cost_basis_label = make_label("-", global.font_small, 18, rl.BLACK)
	widget.proceeds_label = make_label("-", global.font_small, 18, rl.BLACK)
	widget.profit_loss_label = make_label("-", global.font_small, 18, rl.BLACK)

	widget.buy_button = make_simple_button(.OnRelease, rl.GRAY, {100.0, 0.0},
		make_label("Buy 1", global.font, 24, rl.BLACK),
	)
	widget.sell_button = make_simple_button(.OnRelease, rl.GRAY, {100.0, 0.0},
		make_label("Sell 1", global.font, 24, rl.BLACK),
	)
	widget.buy_all_amount_label = make_label("-", global.font_tiny, 14, rl.BLACK)
	widget.buy_all_button = make_simple_button(.OnRelease, rl.GRAY, {100.0, 0.0},
		make_label("Buy all", global.font, 24, rl.BLACK),
	)
	widget.sell_all_profit_label = make_label("-", global.font_tiny, 14, rl.BLACK)
	widget.sell_all_button = make_simple_button(.OnRelease, rl.GRAY, {100.0, 0.0},
		make_label("Sell all", global.font, 24, rl.BLACK),
	)

	widget.DEBUG_earnings_per_share_label = make_label("-", global.font_small, 18, rl.BLACK)
	widget.DEBUG_sentiment_multiplier_label = make_label("-", global.font_small, 18, rl.BLACK)
	widget.DEBUG_volatility_label = make_label("-", global.font_small, 18, rl.BLACK)
	widget.DEBUG_momentum_equilibrium_label = make_label("-", global.font_small, 18, rl.BLACK)
	widget.DEBUG_momentum_label = make_label("-", global.font_small, 18, rl.BLACK)
	widget.DEBUG_growth_rate_label = make_label("-", global.font_small, 18, rl.BLACK)
	widget.DEBUG_credit_rating_label = make_label("-", global.font_small, 18, rl.BLACK)
	widget.DEBUG_payout_ratio_label = make_label("-", global.font_small, 18, rl.BLACK)

	widget.detail_root = make_panel(rl.DARKGRAY, {0, 200},
		make_margin(8, 8, 8, 8,
			make_box(.Horizontal, .SpaceBetween, .Fill, 16,
				make_box(.Vertical, .Start, .Start, 10,
					make_box(.Vertical, .Center, .Start, 0,
						make_box(.Horizontal, .Start, .Start, 8,
							widget.name_label,
							widget.rating_label,
						),
						widget.description_label,
					),
					widget.price_label,
					widget.available_label,
					make_box(.Horizontal, .Start, .Fill, 8,
						widget.owned_label,
						widget.profit_loss_pct_label,
					),
					widget.cost_basis_label,
					make_box(.Horizontal, .Start, .Fill, 8,
						widget.proceeds_label,
						widget.profit_loss_label,
					),
					make_box(.Horizontal, .Start, .Fill, 8,
						widget.buy_button,
						widget.sell_button,
					),
					make_box(.Horizontal, .Start, .Fill, 8,
						widget.buy_all_button,
						widget.sell_all_button,
					),
				),
				make_box(.Vertical, .Start, .Start, 0,
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

	stock_panel := make_anchor(.Center,
		make_panel(base_color, {},
			make_margin(16, 16, 16, 16,
				make_box(.Vertical, .Start, .Fill, 10,
					make_label("Stock Market", global.font_large, 28, rl.WHITE),
					make_scroll_container({600.0, 400.0}, widget.stock_list_box),
					widget.detail_root,
				),
			),
		),
	)

	widget.root = stock_panel

	return widget
}

update_stock_window :: proc(window: ^StockWindow, market: ^stocks.Market, portfolio: ^stocks.StockPortfolio) {
	for id, i in window.company_list {
		company := &market.companies[id]
		stock_info := &portfolio.stocks[id]

		rating := stocks.score_to_rating(company.credit_rating)
		label, _, color := stocks.get_rating_data(rating)
		label_set_color(window.rating_labels[i], color)
		label_set_text(window.rating_labels[i], label)
		
		if stock_info.quantity_owned > 0 {
			window.status_texture_panels[i].state = .Active
			unrealized_profit_loss_pct := ((company.current_price / stock_info.average_cost) - 1.0) * 100.0
			if global.is_approx_zero(unrealized_profit_loss_pct) {
				texture_panel_set_tint_color(window.status_texture_panels[i], rl.WHITE)
			} else if unrealized_profit_loss_pct < 0.0 {
				texture_panel_set_tint_color(window.status_texture_panels[i], rl.RED)
			} else if unrealized_profit_loss_pct > 0.0 {
				texture_panel_set_tint_color(window.status_texture_panels[i], rl.GREEN)
			}

			if abs(unrealized_profit_loss_pct) >= 5.0 {
				window.status_texture_panels[i].min_size = {10.0, 10.0}
			} else {
				window.status_texture_panels[i].min_size = {8.0, 8.0}
			}
		} else {
			window.status_texture_panels[i].state = .Hidden
		}

		label_set_text(window.stock_price_labels[i], fmt.tprintf("$%.2f", company.current_price))

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

		graph_set_data(
			window.stock_price_graphs[i],
			&company.price_history,
			len(company.price_history),
			get_price_from_history,
			f32(min_val - range * 0.1),
			f32(max_val + range * 0.1),
		)

		range_indicator_set_data(window.stock_price_range_indicators[i], company.all_time_low, company.all_time_high, company.current_price)
	}

	if company, ok := &market.companies[window.selected_id]; ok {
		window.detail_root.state = .Active

		stock_info := &portfolio.stocks[window.selected_id]
		available_stocks := stocks.get_available_shares(company, stock_info)

		label_set_text(window.name_label, company.name)
		label_set_text(window.description_label, company.description)

		rating := stocks.score_to_rating(company.credit_rating)
		label, _, color := stocks.get_rating_data(rating)

		label_set_color(window.rating_label, color)
		label_set_text(window.rating_label, label)
		label_set_text(window.price_label, fmt.tprintf("$%.2f per share", company.current_price))
		label_set_text(window.available_label, fmt.tprintf("%s shares available", global.format_int_thousands(available_stocks)))
		if stock_info.quantity_owned > 0 {
			window.profit_loss_pct_label.state = .Active
			window.cost_basis_label.state = .Active
			window.proceeds_label.state = .Active
			window.profit_loss_label.state = .Active
			label_set_text(window.owned_label,
				fmt.tprintf(
					"You own %s shares @ %s",
					global.format_int_thousands(stock_info.quantity_owned),
					global.format_float_thousands(stock_info.average_cost, 2),
				),
			)
			unrealized_profit_loss_pct := ((company.current_price / stock_info.average_cost) - 1.0) * 100.0
			if global.is_approx_zero(unrealized_profit_loss_pct) {
				label_set_color(window.profit_loss_pct_label, rl.BLACK)
				label_set_text(window.profit_loss_pct_label, "[0.00 %]")
			} else if unrealized_profit_loss_pct < 0.0 {
				label_set_color(window.profit_loss_pct_label, rl.RED)
				label_set_text(window.profit_loss_pct_label, fmt.tprintf("[%s %%]", global.format_float_thousands(unrealized_profit_loss_pct, 2)))
			} else if unrealized_profit_loss_pct > 0.0 {
				label_set_color(window.profit_loss_pct_label, rl.GREEN)
				label_set_text(window.profit_loss_pct_label, fmt.tprintf("[+%s %%]", global.format_float_thousands(unrealized_profit_loss_pct, 2)))
			}

			cost_basis := f64(stock_info.quantity_owned) * stock_info.average_cost
			proceeds := f64(stock_info.quantity_owned) * company.current_price

			label_set_text(window.cost_basis_label, fmt.tprintf("Cost basis: $%s", global.format_float_thousands(cost_basis, 2)))
			label_set_text(window.proceeds_label, fmt.tprintf("Proceeds: $%s", global.format_float_thousands(proceeds, 2)))

			unrealized_profit_loss := proceeds - cost_basis
			if global.is_approx_zero(unrealized_profit_loss) {
				label_set_color(window.profit_loss_label, rl.BLACK)
				label_set_text(window.profit_loss_label, "[$0.00]")
			} else if unrealized_profit_loss < 0.0 {
				label_set_color(window.profit_loss_label, rl.RED)
				label_set_text(window.profit_loss_label, fmt.tprintf("[$%s]", global.format_float_thousands(unrealized_profit_loss, 2)))
			} else if unrealized_profit_loss > 0.0 {
				label_set_color(window.profit_loss_label, rl.GREEN)
				label_set_text(window.profit_loss_label, fmt.tprintf("[$+%s]", global.format_float_thousands(unrealized_profit_loss, 2)))
			}
		} else {
			label_set_text(window.owned_label, "You own no shares")
			window.profit_loss_pct_label.state = .Inactive
			window.cost_basis_label.state = .Inactive
			window.proceeds_label.state = .Inactive
			window.profit_loss_label.state = .Inactive
		}


		label_set_text(window.DEBUG_earnings_per_share_label, fmt.tprintf("DEBUG EPS: %f", company.earnings_per_share))
		label_set_text(window.DEBUG_sentiment_multiplier_label, fmt.tprintf("DEBUG Sentiment: %f", company.sentiment_multiplier))
		label_set_text(window.DEBUG_volatility_label, fmt.tprintf("DEBUG volatility: %f", company.volatility))
		label_set_text(window.DEBUG_momentum_equilibrium_label, fmt.tprintf("DEBUG momentum equi: %f", company.momentum_equilibrium))
		label_set_text(window.DEBUG_momentum_label, fmt.tprintf("DEBUG momentum: %f", company.momentum))
		label_set_text(window.DEBUG_growth_rate_label, fmt.tprintf("DEBUG growth rate: %f", company.growth_rate))
		label_set_text(window.DEBUG_credit_rating_label, fmt.tprintf("DEBUG credit rating: %d", company.credit_rating))
		label_set_text(window.DEBUG_payout_ratio_label, fmt.tprintf("DEBUG payout ratio: %f", company.payout_ratio))

	} else {
		window.detail_root.state = .Hidden
	}
}