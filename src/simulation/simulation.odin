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
	buildings_list:            [dynamic]types.Building,
}

init :: proc() -> SimulationState {
	simulation_state: SimulationState

	simulation_state.tick_speed = 1.0
	simulation_state.current_tick = 1
	simulation_state.current_period = 1
	simulation_state.current_quarter = 1
	simulation_state.current_year = 1
	simulation_state.money = 100.0
	simulation_state.illegitimate_money = 25.0
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

	crew_lookup := generate_crew_lookup(simulation_state)

	#reverse for &job in simulation_state.job_entries {
		job_result := jobs.tick(&job, crew_lookup)
		if job.is_ready {
			job.is_active = true
		}
		if job_result == .Finished {
			simulation_state.money += job.cached_income
			simulation_state.period_income += job.cached_income
			simulation_state.illegitimate_money += job.cached_illegitimate_income

			tick_stats.income += job.cached_income
			tick_stats.illegitimate_income += job.cached_illegitimate_income

			#partial switch &d in job.details {
			case types.BuyinJob:
				jobs.deactivate(&job)
				remove_job(simulation_state, job.id)
			}
		} else if job_result == .Failed {
			jobs.deactivate(&job)
			remove_job(simulation_state, job.id)
		}
	}

	for &crew_member in simulation_state.crew_roster {
		job_result := jobs.tick(&crew_member.default_job, crew_lookup)
		if crew_member.default_job.is_ready {
			crew_member.default_job.is_active = true
		}
		if job_result == .Finished {
			simulation_state.money += crew_member.default_job.cached_income
			simulation_state.period_income += crew_member.default_job.cached_income
			tick_stats.income += crew_member.default_job.cached_income
			simulation_state.illegitimate_money +=
				crew_member.default_job.cached_illegitimate_income
			tick_stats.illegitimate_income += crew_member.default_job.cached_illegitimate_income
		} else if job_result == .Failed {
			jobs.deactivate(&crew_member.default_job)
		}
	}

	commercial_revenue: f64
	for &building in simulation_state.buildings_list {
		if !building.owned do continue

		commercial_revenue += building.base_tick_income * building.effect_stats.income_multiplier

		laundering_flow := min(
			simulation_state.illegitimate_money,
			building.base_laundering_amount * building.effect_stats.laundering_amount_multiplier,
		)
		if laundering_flow > 0.0 {
			simulation_state.illegitimate_money -= laundering_flow
			tick_stats.illegitimate_income -= laundering_flow

			commercial_revenue +=
				laundering_flow *
				(building.base_laundering_efficiency +
						building.effect_stats.laundering_efficiency_bonus_flat)
		}
	}

	simulation_state.money += commercial_revenue
	simulation_state.period_income += commercial_revenue
	tick_stats.income += commercial_revenue

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

generate_job_lookup :: proc(simulation_state: ^SimulationState) -> map[types.JobID]^types.Job {
	job_lookup := make(map[types.JobID]^types.Job, context.temp_allocator)

	for &job in simulation_state.job_entries {
		job_lookup[job.id] = &job
	}

	return job_lookup
}

generate_crew_lookup :: proc(
	simulation_state: ^SimulationState,
) -> map[types.CrewMemberID]^types.CrewMember {
	crew_lookup := make(map[types.CrewMemberID]^types.CrewMember, context.temp_allocator)

	for &crew_member in simulation_state.crew_roster {
		crew_lookup[crew_member.id] = &crew_member
	}

	return crew_lookup
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

remove_job :: proc(simulation_state: ^SimulationState, job_id: types.JobID) {
	#reverse for &job, i in simulation_state.job_entries {
		if job.id != job_id do continue

		#partial switch &details in job.details {
		case types.BuyinJob:
			for slot_index in 0 ..< len(details.crew_member_slots) {
				clear_crew(simulation_state, job.id, slot_index)
			}
		}

		ordered_remove(&simulation_state.job_entries, i)
	}
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

get_job_by_id :: proc(simulation_state: ^SimulationState, id: types.JobID) -> ^types.Job {
	target_job: ^types.Job

	for &job in simulation_state.job_entries {
		if job.id == id {
			target_job = &job
			break
		}
	}

	return target_job
}

get_crew_member_by_id :: proc(
	simulation_state: ^SimulationState,
	id: types.CrewMemberID,
) -> ^types.CrewMember {
	target_crew_member: ^types.CrewMember

	for &crew_member in simulation_state.crew_roster {
		if crew_member.id == id {
			target_crew_member = &crew_member
			break
		}
	}

	return target_crew_member
}

try_assign_crew :: proc(
	simulation_state: ^SimulationState,
	job_id: types.JobID,
	slot_idx: int,
	crew_id: types.CrewMemberID,
) -> bool {
	target_job := get_job_by_id(simulation_state, job_id)
	if target_job == nil do return false

	crew_member := get_crew_member_by_id(simulation_state, crew_id)
	if crew_member == nil || crew_member.assigned_to_job_id != 0 do return false

	if details, ok := &target_job.details.(types.BuyinJob); ok {
		if slot_idx < len(details.crew_member_slots) {
			details.crew_member_slots[slot_idx].assigned_crew_member = crew_id
			crew_member.assigned_to_job_id = target_job.id

			jobs.deactivate(&crew_member.default_job)

			calculate_job_values(simulation_state, target_job)

			return true
		}
	}
	return false
}

calculate_job_values :: proc(simulation_state: ^SimulationState, job: ^types.Job) {
	final_income := job.base_income
	final_illegitimate_income := job.base_illegitimate_income

	details, is_buyin := &job.details.(types.BuyinJob)

	if !is_buyin do return

	final_failure_chance := details.base_failure_chance

	for slot in details.crew_member_slots {
		if slot.assigned_crew_member == 0 do continue

		crew_member := get_crew_member_by_id(simulation_state, slot.assigned_crew_member)

		switch slot.type {
		case .Brawn:
			final_failure_chance -= f32(crew_member.brawn) * 0.005
		case .Savvy:
			final_income *= 1.0 + f64(crew_member.savvy) * 0.1
		case .Tech:
		//TODO: heat!
		case .Charisma:
			final_illegitimate_income *= 1.0 + f64(crew_member.charisma) * 0.1
		}
	}

	job.cached_income = final_income
	job.cached_illegitimate_income = final_illegitimate_income
	details.cached_failure_chance = final_failure_chance
}

clear_crew :: proc(simulation_state: ^SimulationState, job_id: types.JobID, slot_idx: int) {
	target_job := get_job_by_id(simulation_state, job_id)
	if target_job == nil do return

	if details, ok := &target_job.details.(types.BuyinJob); ok {
		assigned_id := details.crew_member_slots[slot_idx].assigned_crew_member
		crew_member := get_crew_member_by_id(simulation_state, assigned_id)
		if crew_member == nil do return

		if slot_idx < len(details.crew_member_slots) {
			details.crew_member_slots[slot_idx].assigned_crew_member = 0
			crew_member.assigned_to_job_id = 0

			jobs.activate(&crew_member.default_job)
		}
	}

	calculate_job_values(simulation_state, target_job)
}

// Buildings

get_building_by_id :: proc(
	simulation_state: ^SimulationState,
	id: types.BuildingID,
) -> ^types.Building {
	target_building: ^types.Building

	for &building in simulation_state.buildings_list {
		if building.id == id {
			target_building = &building
			break
		}
	}

	return target_building
}

purchase_building :: proc(state: ^SimulationState, building: ^types.Building) {
	if state.money < building.purchase_price.money ||
	   state.illegitimate_money < building.purchase_price.illegitimate_money {
		return
	}

	state.money -= building.purchase_price.money
	state.illegitimate_money -= building.purchase_price.illegitimate_money
	building.owned = true
}

purchase_building_alt_price :: proc(state: ^SimulationState, building: ^types.Building) {
	if alt_purchase_price, ok := building.alt_purchase_price.(types.PurchasePrice);
	   ok &&
	   state.money >= alt_purchase_price.money &&
	   state.illegitimate_money >= alt_purchase_price.illegitimate_money {
		state.money -= alt_purchase_price.money
		state.illegitimate_money -= alt_purchase_price.illegitimate_money
		building.owned = true
	}
}

buy_upgrade :: proc(
	state: ^SimulationState,
	building_id: types.BuildingID,
	upgrade_id: types.UpgradeID,
) {
	building := get_building_by_id(state, building_id)

	for upgrade, i in building.upgrades {
		if upgrade.id != upgrade_id do continue

		switch effect in upgrade.effect {
		case types.IncomeMultiplier:
			building.effect_stats.income_multiplier += effect.multiplier
		case types.LaunderingAmountMultiplier:
			building.effect_stats.laundering_amount_multiplier += effect.multiplier
		case types.LaunderingEfficiencyBonusFlat:
			building.effect_stats.laundering_efficiency_bonus_flat += effect.bonus
		}

		ordered_remove(&building.upgrades, i)

		break
	}
}

// Stocks

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
