package jobs

import "../types"
import "core:math/rand"

create_job :: proc(
	name: string,
	level, ticks_needed: int,
	income, illegitimate_income: f64,
	is_buyin_job: bool = false,
) -> types.Job {
	@(static) id: types.JobID = 1
	defer id += 1

	if is_buyin_job {
		crew_member_slots := make([dynamic]types.CrewMemberSlot)

		append(&crew_member_slots, types.CrewMemberSlot{.Brawn, 0})
		append(&crew_member_slots, types.CrewMemberSlot{.Savvy, 0})
		append(&crew_member_slots, types.CrewMemberSlot{.Tech, 0})
		append(&crew_member_slots, types.CrewMemberSlot{.Charisma, 0})

		return types.Job {
			id = id,
			name = name,
			level = level,
			ticks_needed = ticks_needed,
			base_income = income,
			cached_income = income,
			base_illegitimate_income = illegitimate_income,
			cached_illegitimate_income = illegitimate_income,
			details = types.BuyinJob {
				buyin_price = 10.0,
				illegitimate_buyin_price = 10.0,
				base_failure_chance = 0.02,
				crew_member_slots = crew_member_slots,
			},
		}
	} else {
		return types.Job {
			id = id,
			name = name,
			level = level,
			ticks_needed = ticks_needed,
			base_income = income,
			cached_income = income,
			base_illegitimate_income = illegitimate_income,
			cached_illegitimate_income = illegitimate_income,
			details = types.StandardJob{},
		}
	}
}

tick :: proc(
	job: ^types.Job,
	crew_lookup: map[types.CrewMemberID]^types.CrewMember,
) -> types.JobResult {
	if !job.is_active do return .Inactive

	#partial switch &d in job.details {
	case types.BuyinJob:
		if job.ticks_current < job.ticks_needed - 1 && rand.float32() <= d.cached_failure_chance {
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
