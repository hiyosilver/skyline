package jobs

import "../types"
import "core:math/rand"

create_job :: proc(
	name: string,
	level, ticks_needed: int,
	income, illegitimate_income: f64,
	buyin_price: f64 = 0.0,
	illegitimate_buyin_price: f64 = 0.0,
	failure_chance: f32 = 0.0,
) -> types.Job {
	@(static) id: types.JobID = 1
	defer id += 1

	crew_member_slots := make([dynamic]types.CrewMemberSlot)

	return types.Job {
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

add_crew_slot :: proc(job: ^types.Job, type: types.CrewMemberSlotType, optional: bool) {
	append(
		&job.crew_member_slots,
		types.CrewMemberSlot{type = type, optional = optional, assigned_crew_member = 0},
	)
}

tick :: proc(job: ^types.Job) -> types.JobResult {
	if !job.is_active do return .Inactive

	if job.cached_failure_chance > 0.0 {
		if job.ticks_current < job.ticks_needed - 1 &&
		   rand.float32() <= job.cached_failure_chance {
			return .Failed
		}
	}

	job.ticks_current += 1
	if job.ticks_current >= job.ticks_needed {
		job.ticks_current -= job.ticks_needed
		return .Finished
	}

	return .Active
}

activate :: proc(job: ^types.Job) {
	job.is_ready = true
	job.is_active = false
	job.ticks_current = 0
}

deactivate :: proc(job: ^types.Job) {
	job.is_ready = false
	job.is_active = false
	job.ticks_current = 0
}

toggle_state :: proc(job: ^types.Job) -> bool {
	if !job.is_ready && !job.is_active {
		job.is_ready = true
		return true
	} else {
		deactivate(job)
		return false
	}
}
