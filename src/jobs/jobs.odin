package jobs

//import rl "vendor:raylib"
import "../types"
import "core:math/rand"

create_buyin_job :: proc() -> types.Job {
	crew_member_slots := make([dynamic]types.CrewMemberSlot)

	append(&crew_member_slots, types.CrewMemberSlot{.Brawn, 0})
	append(&crew_member_slots, types.CrewMemberSlot{.Savvy, 0})

	return types.Job {
		name = "Risky Job",
		level = 5,
		ticks_needed = 10,
		illegitimate_income = 145.0,
		details = types.BuyinJob {
			buyin_price = 10.0,
			illegitimate_buyin_price = 10.0,
			failure_chance = 0.02,
			crew_member_slots = crew_member_slots,
		},
	}
}

tick :: proc(job: ^types.Job) -> types.JobResult {
	if !job.is_active do return .Inactive

	switch &d in job.details {
	case types.StandardJob:
	case types.BuyinJob:
		if job.ticks_current < job.ticks_needed - 1 && rand.float32() <= d.failure_chance {
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
