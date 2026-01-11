package heists

import "../types"

create_job :: proc(
	name: string,
	level, ticks_needed: int,
	income, illegitimate_income: f64,
	buyin_price: f64 = 0.0,
	illegitimate_buyin_price: f64 = 0.0,
	failure_chance: f32 = 0.0,
) -> types.Heist {
	@(static) id: types.HeistID = 1
	defer id += 1

	crew_member_slots := make([dynamic]types.CrewMemberSlot)

	return types.Heist {
		id = id,
		name = name,
		level = level,
		ticks_needed = ticks_needed,
		base_income = income,
		cached_income = income,
		base_illegitimate_income = illegitimate_income,
		cached_illegitimate_income = illegitimate_income,
		buyin_price = buyin_price,
		illegitimate_buyin_price = illegitimate_buyin_price,
		base_failure_chance = failure_chance,
		crew_member_slots = crew_member_slots,
	}
}

add_crew_slot :: proc(
	job: ^types.Job,
	type: types.CrewMemberSlotType,
	effects: [dynamic]types.CrewMemberSlotEffect,
	optional: bool,
) {
	append(
		&job.crew_member_slots,
		types.CrewMemberSlot {
			type = type,
			effects = effects,
			optional = optional,
			assigned_crew_member = 0,
		},
	)
}
