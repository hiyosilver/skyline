package simulation

import "../global"
import "../jobs"
import "../stocks"
import "../types"
import "core:fmt"

ChangeOnTick :: enum {
	Maintained,
	Increased,
	Decreased,
}

TickStatistics :: struct {
	current_money:              f64,
	current_illegitimate_money: f64,
	income:                     f64,
	illegitimate_income:        f64,
	salaries:                   f64,
	illegitimate_salaries:      f64,
	taxes:                      f64,
	tax_debt:                   f64,
}

SimulationState :: struct {
	//Simulation
	paused:                    bool,
	tick_speed:                f32,
	tick_timer:                f32,
	current_tick:              int,
	current_period:            int,
	current_quarter:           int,
	current_year:              int,

	//Game data
	money:                     f64,
	period_income:             f64,
	money_change:              ChangeOnTick,
	illegitimate_money:        f64,
	illegitimate_money_change: ChangeOnTick,
	base_tax_rate:             f64,
	tax_debt:                  f64,
	tax_debt_interest_rate:    f64,
	tick_stats_buffer:         [dynamic]TickStatistics,
	tick_stats_buffer_size:    int,
	market:                    stocks.Market,
	stock_portfolio:           stocks.StockPortfolio,
	job_entries:               [dynamic]types.Job,
	crew_roster:               [dynamic]types.CrewMember,
}

init :: proc() -> SimulationState {
	simulation_state: SimulationState

	simulation_state.tick_speed = 1.0
	simulation_state.current_tick = 1
	simulation_state.current_period = 1
	simulation_state.current_quarter = 1
	simulation_state.current_year = 1
	simulation_state.money = 100.0
	simulation_state.base_tax_rate = 0.15
	simulation_state.tax_debt_interest_rate = 0.005
	simulation_state.tick_stats_buffer = make([dynamic]TickStatistics)
	simulation_state.tick_stats_buffer_size = 30
	simulation_state.market = stocks.create_market()
	for _ in 0 ..< 30 {
		stocks.update_market_tick(&simulation_state.market)
	}
	simulation_state.stock_portfolio = stocks.create_stock_portfolio(&simulation_state.market)

	return simulation_state
}

tick :: proc(simulation_state: ^SimulationState) {
	tick_stats: TickStatistics

	prev_money := simulation_state.money
	prev_illegitimate_money := simulation_state.illegitimate_money

	#reverse for &job, i in simulation_state.job_entries {
		job_result := jobs.tick(&job)
		if job.is_ready {
			job.is_active = true
		}
		if job_result == .Finished {
			simulation_state.money += job.income
			simulation_state.period_income += job.income
			simulation_state.illegitimate_money += job.illegitimate_income

			tick_stats.income += job.income
			tick_stats.illegitimate_income += job.illegitimate_income

			#partial switch &d in job.details {
			case types.BuyinJob:
				jobs.deactivate(&job)
				remove_job(simulation_state, i)
			}
		} else if job_result == .Failed {
			jobs.deactivate(&job)
			remove_job(simulation_state, i)
		}
	}

	for &crew_member in simulation_state.crew_roster {
		job_result := jobs.tick(&crew_member.default_job)
		if crew_member.default_job.is_ready {
			crew_member.default_job.is_active = true
		}
		if job_result == .Finished {
			simulation_state.money += crew_member.default_job.income
			simulation_state.period_income += crew_member.default_job.income
			tick_stats.income += crew_member.default_job.income
			simulation_state.illegitimate_money += crew_member.default_job.illegitimate_income
			tick_stats.illegitimate_income += crew_member.default_job.illegitimate_income
		} else if job_result == .Failed {
			jobs.deactivate(&crew_member.default_job)
		}
	}

	simulation_state.current_tick += 1
	stocks.update_market_tick(&simulation_state.market)
	if simulation_state.current_tick > global.TICKS_PER_PERIOD {
		simulation_state.current_tick = 1

		fmt.println("Update market period!")
		calculate_period_end(simulation_state, &tick_stats)

		simulation_state.current_period += 1

		if (simulation_state.current_period - 1) % global.PERIODS_PER_QUARTER == 0 {
			simulation_state.current_period = 1

			fmt.println("Update market quarter!")
			stocks.update_market_quarter(&simulation_state.market)
			simulation_state.current_quarter += 1
		}
		if simulation_state.current_quarter > global.QUARTERS_PER_YEAR {
			simulation_state.current_quarter = 1
			fmt.println("Update market year!")
			stocks.update_market_year(&simulation_state.market)
			simulation_state.current_year += 1
		}
	}

	switch {
	case simulation_state.money == prev_money:
		simulation_state.money_change = .Maintained
	case simulation_state.money < prev_money:
		simulation_state.money_change = .Decreased
	case simulation_state.money > prev_money:
		simulation_state.money_change = .Increased
	}

	switch {
	case simulation_state.illegitimate_money == prev_illegitimate_money:
		simulation_state.illegitimate_money_change = .Maintained
	case simulation_state.illegitimate_money < prev_illegitimate_money:
		simulation_state.illegitimate_money_change = .Decreased
	case simulation_state.illegitimate_money > prev_illegitimate_money:
		simulation_state.illegitimate_money_change = .Increased
	}

	tick_stats.current_money = simulation_state.money
	tick_stats.current_illegitimate_money = simulation_state.illegitimate_money

	append(&simulation_state.tick_stats_buffer, tick_stats)
	if len(simulation_state.tick_stats_buffer) > simulation_state.tick_stats_buffer_size {
		ordered_remove(&simulation_state.tick_stats_buffer, 0)
	}
}

calculate_period_end :: proc(simulation_state: ^SimulationState, tick_stats: ^TickStatistics) {
	//Calculate and pay salaries
	salaries, salaries_illegitimate: f64
	#reverse for &crew_member in simulation_state.crew_roster {
		out_of_money := false
		if simulation_state.money >= crew_member.base_salary {
			simulation_state.money -= crew_member.base_salary
			salaries += crew_member.base_salary
		} else {
			simulation_state.money = 0.0
			out_of_money = true
		}

		if simulation_state.illegitimate_money >= crew_member.base_salary_illegitimate {
			simulation_state.illegitimate_money -= crew_member.base_salary_illegitimate
			salaries_illegitimate += crew_member.base_salary_illegitimate
		} else {
			simulation_state.illegitimate_money = 0.0
			out_of_money = true
		}

		if out_of_money do remove_crew_member(simulation_state, crew_member.id)
	}

	tick_stats.salaries = salaries
	tick_stats.illegitimate_salaries = salaries_illegitimate

	//Calculate tax debt interest
	tax_debt_interest := simulation_state.tax_debt * simulation_state.tax_debt_interest_rate

	//Accumulate tax debt
	simulation_state.tax_debt += tax_debt_interest

	//Try to pay tax debt
	if simulation_state.tax_debt > 0.0 {
		if simulation_state.money >= simulation_state.tax_debt {
			simulation_state.money -= simulation_state.tax_debt
			simulation_state.tax_debt = 0.0
		} else {
			simulation_state.tax_debt -= simulation_state.money
			simulation_state.money = 0.0
		}
	}

	//Calculate tax
	tax := simulation_state.period_income * simulation_state.base_tax_rate
	tick_stats.taxes = tax

	//Try to pay tax
	if tax > 0.0 {
		if simulation_state.money >= tax {
			simulation_state.money -= tax
		} else {
			simulation_state.tax_debt += tax - simulation_state.money
			simulation_state.money = 0
		}
	}

	tick_stats.tax_debt = simulation_state.tax_debt
	simulation_state.period_income = 0.0

	stocks.update_market_period(&simulation_state.market)
}

remove_crew_member :: proc(
	simulation_state: ^SimulationState,
	crew_member_id: types.CrewMemberID,
) {
	#reverse for crew_member, i in simulation_state.crew_roster {
		if crew_member.id != crew_member_id do continue

		ordered_remove(&simulation_state.crew_roster, i)
		break
	}
}

remove_job :: proc(simulation_state: ^SimulationState, entry_index: int) {
	ordered_remove(&simulation_state.job_entries, entry_index)
}

interact_toggle_job :: proc(simulation_state: ^SimulationState, job_index: int) {
	if job_index < 0 || job_index >= len(simulation_state.job_entries) do return

	job := &simulation_state.job_entries[job_index]

	if !job.is_active {
		#partial switch d in job.details {
		case types.BuyinJob:
			if simulation_state.money < d.buyin_price ||
			   simulation_state.illegitimate_money < d.illegitimate_buyin_price {
				return
			}
			simulation_state.money -= d.buyin_price
			simulation_state.illegitimate_money -= d.illegitimate_buyin_price
		}
	}

	is_now_active := jobs.toggle_state(job)

	if is_now_active {
		for &other_entry, j in simulation_state.job_entries {
			if job_index == j do continue
			jobs.deactivate(&other_entry)
		}
	}
}

try_assign_crew :: proc(
	simulation_state: ^SimulationState,
	job_idx, slot_idx: int,
	crew_id: types.CrewMemberID,
) -> bool {
	if job_idx >= len(simulation_state.job_entries) do return false
	target_job := &simulation_state.job_entries[job_idx]

	if details, ok := &target_job.details.(types.BuyinJob); ok {
		if slot_idx < len(details.crew_member_slots) {

			details.crew_member_slots[slot_idx].assigned_crew_member = crew_id

			fmt.printf("Assigned ID %d to Job Slot %d\n", crew_id, slot_idx)

			return true
		}
	}
	return false
}

buy_stock :: proc(state: ^SimulationState, company_id: types.CompanyID, amount: int) {
	stocks.execute_buy_order(
		&state.market,
		&state.stock_portfolio,
		&state.money,
		company_id,
		amount,
	)
}

sell_stock :: proc(state: ^SimulationState, company_id: types.CompanyID, amount: int) {
	stocks.execute_sell_order(
		&state.market,
		&state.stock_portfolio,
		&state.money,
		&state.period_income,
		company_id,
		amount,
	)
}
