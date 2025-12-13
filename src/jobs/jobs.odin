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
			income = income,
			illegitimate_income = illegitimate_income,
			details = types.BuyinJob {
				buyin_price = 10.0,
				illegitimate_buyin_price = 10.0,
				failure_chance = 0.02,
				crew_member_slots = crew_member_slots,
			},
		}
	} else {
		return types.Job {
			id = id,
			name = name,
			level = level,
			ticks_needed = ticks_needed,
			income = income,
			illegitimate_income = illegitimate_income,
			details = types.StandardJob{},
		}
	}
}

tick :: proc(
	job: ^types.Job,
	crew_lookup: map[types.CrewMemberID]^types.CrewMember,
	final_failure_chance: f32,
) -> types.JobResult {
	if !job.is_active do return .Inactive

	#partial switch &d in job.details {
	case types.BuyinJob:
		if job.ticks_current < job.ticks_needed - 1 && rand.float32() <= final_failure_chance {
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

calculate_job_values :: proc(
	job: ^types.Job,
	crew_lookup: map[types.CrewMemberID]^types.CrewMember,
) -> (
	final_income: f64,
	final_illegitimate_income: f64,
	final_failure_chance: f32,
) {
	final_income = job.income
	final_illegitimate_income = job.illegitimate_income

	details, is_buyin := &job.details.(types.BuyinJob)
	if is_buyin {
		final_failure_chance = details.failure_chance

		for slot in details.crew_member_slots {
			if slot.assigned_crew_member == 0 do continue

			crew_member, ok := crew_lookup[slot.assigned_crew_member]

			if !ok do break

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
	}

	return
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
